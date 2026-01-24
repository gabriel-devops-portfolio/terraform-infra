############################################
# Athena Views and Named Queries Configuration
# Purpose: Deploy Athena views for Security Lake analysis
############################################

locals {
  region              = var.region
  security_account_id = var.security_account_id
  workload_account_id = var.workload_account_id

  common_tags = {
    Environment = "security"
    ManagedBy   = "terraform"
    Project     = "security-lake-analytics"
  }
}

############################################
# Data Sources
############################################
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Reference to Security Lake Glue database name
locals {
  security_lake_database_name = "amazon_security_lake_glue_db_${replace(var.region, "-", "_")}"
  athena_workgroup_name       = "security-lake-queries"
}

# Reference to Athena results bucket from cross-account-roles
data "aws_s3_bucket" "athena_results" {
  bucket = "org-athena-query-results-${var.security_account_id}"
}

############################################
# Athena Named Query: VPC Traffic Anomalies (OCSF Format)
############################################
resource "aws_athena_named_query" "vpc_traffic_anomalies" {
  name        = "vpc-traffic-anomalies-ocsf"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Detect anomalous VPC traffic patterns using OCSF format (rejected connections and unusual ports)"

  query = <<-EOF
    -- Query Security Lake VPC Flow Logs in OCSF format (class_uid = 4001)
    SELECT
      from_unixtime(time/1000) AS timestamp,
      src_endpoint.ip AS source_ip,
      src_endpoint.port AS source_port,
      dst_endpoint.ip AS destination_ip,
      dst_endpoint.port AS destination_port,
      connection_info.protocol_name AS protocol,
      disposition AS action,
      traffic.packets AS packets,
      traffic.bytes AS bytes,
      cloud.account.uid AS account_id,
      cloud.region AS region,
      CASE
        WHEN disposition = 'Blocked' THEN 'Rejected Connection'
        WHEN dst_endpoint.port NOT IN (80,443,22,3306,5432) THEN 'Unusual Port'
        ELSE 'Normal'
      END AS anomaly_type
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_vpc_flow_2_0
    WHERE class_uid = 4001
      AND (disposition = 'Blocked' OR dst_endpoint.port NOT IN (80,443,22,3306,5432))
    ORDER BY time DESC
    LIMIT 1000;
  EOF
}

############################################
# Athena View: VPC Traffic Anomalies (OCSF Format)
############################################
resource "aws_athena_named_query" "create_vpc_traffic_anomalies_view" {
  name        = "create-view-vpc-traffic-anomalies-ocsf"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Creates a reusable view for VPC traffic anomalies using OCSF schema"

  query = <<-EOF
    CREATE OR REPLACE VIEW security_vpc_traffic_anomalies_ocsf AS
    SELECT
      from_unixtime(time/1000) AS timestamp,
      src_endpoint.ip AS source_ip,
      src_endpoint.port AS source_port,
      dst_endpoint.ip AS destination_ip,
      dst_endpoint.port AS destination_port,
      connection_info.protocol_name AS protocol,
      disposition AS action,
      traffic.packets AS packets,
      traffic.bytes AS bytes,
      cloud.account.uid AS account_id,
      cloud.region AS region,
      severity AS severity
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_vpc_flow_2_0
    WHERE class_uid = 4001
      AND (disposition = 'Blocked' OR dst_endpoint.port NOT IN (80,443,22,3306,5432));
  EOF
}

############################################
# Athena Named Query: Terraform State Access
############################################
resource "aws_athena_named_query" "terraform_state_access" {
  name        = "terraform-state-access"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Query all access to Terraform state files"

  query = <<-EOF
    -- Query Security Lake CloudTrail in OCSF format (class_uid = 3005)
    SELECT
      from_unixtime(time/1000) AS timestamp,
      api.operation AS operation,
      api.request.bucket AS bucket_name,
      api.request.key AS object_key,
      actor.user.uid AS principal,
      actor.user.type AS identity_type,
      src_endpoint.ip AS source_ip,
      http_request.user_agent AS user_agent,
      cloud.account.uid AS account_id,
      cloud.region AS region,
      cloud.provider AS provider,
      severity AS severity
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_cloud_trail_mgmt_2_0
    WHERE class_uid = 3005
      AND (api.request.key LIKE '%terraform.tfstate%'
       OR api.request.bucket LIKE '%terraform-state%')
    ORDER BY time DESC
    LIMIT 1000;
  EOF
}

############################################
# Athena View: Terraform State Access
############################################
resource "aws_athena_named_query" "create_terraform_state_view" {
  name        = "create-view-terraform-state-access"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Creates a reusable view for Terraform state access monitoring"

  query = <<-EOF
    CREATE OR REPLACE VIEW security_terraform_state_access AS
    SELECT
      from_unixtime(time/1000) AS timestamp,
      api.operation AS operation,
      actor.user.uid AS principal,
      src_endpoint.ip AS source_ip,
      cloud.account.uid AS account_id,
      cloud.region AS region
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_cloud_trail_mgmt_2_0
    WHERE class_uid = 3005
      AND api.request.key LIKE '%terraform.tfstate%';
  EOF
}

############################################
# Athena Named Query: Privileged Activity
############################################
resource "aws_athena_named_query" "privileged_activity" {
  name        = "privileged-activity-monitoring"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Monitor root account and privileged role activity"

  query = <<-EOF
    -- Query Security Lake CloudTrail for privileged activity (OCSF class_uid = 3005)
    SELECT
      from_unixtime(time/1000) AS timestamp,
      api.operation AS operation,
      actor.user.type AS identity_type,
      actor.user.uid AS principal,
      src_endpoint.ip AS source_ip,
      src_endpoint.location.city AS city,
      src_endpoint.location.country AS country,
      http_request.user_agent AS user_agent,
      cloud.account.uid AS account_id,
      cloud.region AS region,
      severity AS severity
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_cloud_trail_mgmt_2_0
    WHERE class_uid = 3005
      AND actor.user.type IN ('Root','AssumedRole')
    ORDER BY time DESC
    LIMIT 1000;
  EOF
}

############################################
# Athena View: Privileged Activity
############################################
resource "aws_athena_named_query" "create_privileged_activity_view" {
  name        = "create-view-privileged-activity"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Creates a reusable view for privileged activity monitoring"

  query = <<-EOF
    CREATE OR REPLACE VIEW security_privileged_activity AS
    SELECT
      from_unixtime(time/1000) AS timestamp,
      api.operation AS operation,
      actor.user.type AS identity_type,
      actor.user.uid AS principal,
      src_endpoint.ip AS source_ip,
      cloud.account.uid AS account_id,
      cloud.region AS region,
      severity AS severity
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_cloud_trail_mgmt_2_0
    WHERE class_uid = 3005
      AND actor.user.type IN ('Root','AssumedRole');
  EOF
}

############################################
# Athena Named Query: GuardDuty Findings
############################################
resource "aws_athena_named_query" "guardduty_findings" {
  name        = "guardduty-high-severity-findings"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Query high and critical severity GuardDuty findings"

  query = <<-EOF
    -- Query Security Lake Security Hub Findings in OCSF format (class_uid = 2001)
    SELECT
      from_unixtime(time/1000) AS timestamp,
      severity AS severity,
      severity_id AS severity_id,
      finding_info.title AS finding_title,
      finding_info.types AS finding_types,
      activity_name AS activity,
      resources[1].type AS resource_type,
      resources[1].uid AS resource_uid,
      resources[1].cloud_partition AS cloud_partition,
      cloud.account.uid AS account_id,
      cloud.region AS region,
      cloud.provider AS provider
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_sh_findings_1_0
    WHERE class_uid = 2001
      AND severity_id >= 7
    ORDER BY time DESC
    LIMIT 1000;
  EOF
}

############################################
# Athena View: Security Hub Findings (OCSF)
############################################
resource "aws_athena_named_query" "create_guardduty_view" {
  name        = "create-view-security-hub-findings-ocsf"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Creates a reusable view for Security Hub findings using OCSF schema"

  query = <<-EOF
    CREATE OR REPLACE VIEW security_hub_findings_ocsf AS
    SELECT
      from_unixtime(time/1000) AS timestamp,
      severity AS severity,
      finding_info.title AS finding_type,
      activity_name AS activity,
      resources[1].type AS resource_type,
      resources[1].uid AS resource_uid,
      cloud.account.uid AS account_id,
      cloud.region AS region
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_sh_findings_1_0
    WHERE class_uid = 2001;
  EOF
}

############################################
# Athena Named Query: Failed Authentication Attempts
############################################
resource "aws_athena_named_query" "failed_auth_attempts" {
  name        = "failed-authentication-attempts"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Detect failed authentication and authorization attempts"

  query = <<-EOF
    -- Query Security Lake CloudTrail for failed auth attempts (OCSF class_uid = 3005)
    SELECT
      from_unixtime(time/1000) AS timestamp,
      api.operation AS operation,
      api.response.error AS error_code,
      api.response.message AS error_message,
      actor.user.uid AS principal,
      src_endpoint.ip AS source_ip,
      cloud.account.uid AS account_id,
      cloud.region AS region,
      COUNT(*) OVER (
        PARTITION BY src_endpoint.ip, actor.user.uid
        ORDER BY time
        ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
      ) AS attempts_in_window
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_cloud_trail_mgmt_2_0
    WHERE class_uid = 3005
      AND api.response.error IN ('AccessDenied', 'UnauthorizedOperation', 'InvalidClientTokenId', 'SignatureDoesNotMatch')
    ORDER BY time DESC
    LIMIT 1000;
  EOF
}

############################################
# Athena Named Query: S3 Public Access Changes
############################################
resource "aws_athena_named_query" "s3_public_access_changes" {
  name        = "s3-public-access-changes"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Detect changes to S3 bucket public access settings"

  query = <<-EOF
    -- Query Security Lake CloudTrail for S3 public access changes (OCSF class_uid = 3005)
    SELECT
      from_unixtime(time/1000) AS timestamp,
      api.operation AS operation,
      api.request.bucket AS bucket_name,
      actor.user.uid AS principal,
      src_endpoint.ip AS source_ip,
      cloud.account.uid AS account_id,
      cloud.region AS region
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_cloud_trail_mgmt_2_0
    WHERE class_uid = 3005
      AND api.operation IN (
        'PutBucketAcl',
        'PutBucketPolicy',
        'PutBucketPublicAccessBlock',
        'DeleteBucketPublicAccessBlock'
      )
    ORDER BY time DESC
    LIMIT 500;
  EOF
}

############################################
# Athena Named Query: Security Group Changes
############################################
resource "aws_athena_named_query" "security_group_changes" {
  name        = "security-group-changes"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Monitor security group rule modifications"

  query = <<-EOF
    -- Query Security Lake CloudTrail for security group changes (OCSF class_uid = 3005)
    SELECT
      from_unixtime(time/1000) AS timestamp,
      api.operation AS operation,
      actor.user.uid AS principal,
      src_endpoint.ip AS source_ip,
      cloud.account.uid AS account_id,
      cloud.region AS region
    FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_cloud_trail_mgmt_2_0
    WHERE class_uid = 3005
      AND api.operation IN (
        'AuthorizeSecurityGroupIngress',
        'AuthorizeSecurityGroupEgress',
        'RevokeSecurityGroupIngress',
        'RevokeSecurityGroupEgress',
        'ModifySecurityGroupRules'
      )
    ORDER BY time DESC
    LIMIT 500;
  EOF
}

############################################
# MULTI-SOURCE CORRELATION QUERIES (OCSF)
############################################

############################################
# Athena Named Query: Correlated Security Events
# Correlate blocked network traffic with failed API calls from same IP
############################################
resource "aws_athena_named_query" "correlated_security_events" {
  name        = "multi-source-correlated-security-events"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Correlate blocked VPC traffic with failed API calls from the same source IP (Multi-Source OCSF)"

  query = <<-EOF
    -- Correlate Network Activity (4001) with API Activity (3005) by source IP
    WITH blocked_network AS (
      SELECT
        from_unixtime(time/1000) AS timestamp,
        src_endpoint.ip AS source_ip,
        dst_endpoint.ip AS dest_ip,
        dst_endpoint.port AS dest_port,
        'Network' AS event_type,
        'VPC Flow Blocked' AS event_detail
      FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_vpc_flow_2_0
      WHERE class_uid = 4001
        AND disposition = 'Blocked'
        AND time > (to_unixtime(current_timestamp) - 3600) * 1000  -- Last hour
    ),
    failed_api AS (
      SELECT
        from_unixtime(time/1000) AS timestamp,
        src_endpoint.ip AS source_ip,
        api.operation AS operation,
        'API' AS event_type,
        api.response.error AS event_detail
      FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_cloud_trail_mgmt_2_0
      WHERE class_uid = 3005
        AND api.response.error IS NOT NULL
        AND time > (to_unixtime(current_timestamp) - 3600) * 1000  -- Last hour
    )
    SELECT
      COALESCE(n.source_ip, a.source_ip) AS suspicious_ip,
      n.timestamp AS network_event_time,
      n.dest_ip AS blocked_destination,
      n.dest_port AS blocked_port,
      a.timestamp AS api_event_time,
      a.operation AS failed_operation,
      a.event_detail AS error_code,
      'Correlated Suspicious Activity' AS alert_type
    FROM blocked_network n
    FULL OUTER JOIN failed_api a
      ON n.source_ip = a.source_ip
    WHERE n.source_ip IS NOT NULL AND a.source_ip IS NOT NULL
    ORDER BY n.timestamp DESC, a.timestamp DESC
    LIMIT 100;
  EOF
}

############################################
# Athena Named Query: Cross-Source Threat Intelligence
# Find IPs with multiple suspicious indicators across all sources
############################################
resource "aws_athena_named_query" "cross_source_threat_intel" {
  name        = "multi-source-threat-intelligence"
  workgroup   = local.athena_workgroup_name
  database    = local.security_lake_database_name
  description = "Aggregate suspicious activity indicators across VPC Flow, CloudTrail, and Security Hub (Multi-Source OCSF)"

  query = <<-EOF
    -- Aggregate threat indicators from multiple OCSF sources
    WITH vpc_blocked AS (
      SELECT
        src_endpoint.ip AS ip,
        COUNT(*) AS blocked_connections
      FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_vpc_flow_2_0
      WHERE class_uid = 4001
        AND disposition = 'Blocked'
        AND time > (to_unixtime(current_timestamp) - 86400) * 1000  -- Last 24 hours
      GROUP BY src_endpoint.ip
      HAVING COUNT(*) > 10
    ),
    api_failures AS (
      SELECT
        src_endpoint.ip AS ip,
        COUNT(*) AS failed_api_calls
      FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_cloud_trail_mgmt_2_0
      WHERE class_uid = 3005
        AND api.response.error IS NOT NULL
        AND time > (to_unixtime(current_timestamp) - 86400) * 1000  -- Last 24 hours
      GROUP BY src_endpoint.ip
      HAVING COUNT(*) > 5
    ),
    security_findings AS (
      SELECT
        resources[1].uid AS ip,
        COUNT(*) AS security_alerts
      FROM amazon_security_lake_glue_db_${replace(var.region, "-", "_")}.amazon_security_lake_table_${replace(var.region, "-", "_")}_sh_findings_1_0
      WHERE class_uid = 2001
        AND severity_id >= 5
        AND time > (to_unixtime(current_timestamp) - 86400) * 1000  -- Last 24 hours
      GROUP BY resources[1].uid
    )
    SELECT
      COALESCE(v.ip, a.ip, s.ip) AS suspicious_ip,
      COALESCE(v.blocked_connections, 0) AS blocked_network_count,
      COALESCE(a.failed_api_calls, 0) AS failed_api_count,
      COALESCE(s.security_alerts, 0) AS security_alert_count,
      (COALESCE(v.blocked_connections, 0) +
       COALESCE(a.failed_api_calls, 0) +
       COALESCE(s.security_alerts, 0)) AS total_threat_score
    FROM vpc_blocked v
    FULL OUTER JOIN api_failures a ON v.ip = a.ip
    FULL OUTER JOIN security_findings s ON COALESCE(v.ip, a.ip) = s.ip
    WHERE (v.ip IS NOT NULL OR a.ip IS NOT NULL OR s.ip IS NOT NULL)
    ORDER BY total_threat_score DESC
    LIMIT 50;
  EOF
}
