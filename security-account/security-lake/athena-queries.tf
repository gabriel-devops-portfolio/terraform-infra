############################################
# Athena Named Queries for Security Lake
# Purpose: Pre-built queries for security analytics and threat hunting
############################################

############################################
# CloudTrail Security Queries
############################################

# High-risk API calls
resource "aws_athena_named_query" "high_risk_api_calls" {
  name        = "HighRiskAPICalls"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Detect high-risk API calls that could indicate compromise"

  query = <<-EOT
    SELECT
      time,
      src_endpoint.ip as source_ip,
      actor.user.name as user_name,
      api.operation as api_operation,
      api.service.name as service_name,
      cloud.region,
      severity,
      raw_data
    FROM "${aws_glue_catalog_database.security_lake.name}"."cloudtrail_mgmt_2_0"
    WHERE
      api.operation IN (
        'CreateUser', 'DeleteUser', 'AttachUserPolicy', 'DetachUserPolicy',
        'CreateRole', 'DeleteRole', 'AttachRolePolicy', 'DetachRolePolicy',
        'CreateAccessKey', 'DeleteAccessKey', 'UpdateAccessKey',
        'CreateLoginProfile', 'DeleteLoginProfile', 'UpdateLoginProfile',
        'PutBucketPolicy', 'DeleteBucketPolicy', 'PutBucketAcl',
        'ModifyDBInstance', 'DeleteDBInstance', 'CreateDBInstance',
        'AuthorizeSecurityGroupIngress', 'RevokeSecurityGroupIngress',
        'RunInstances', 'TerminateInstances', 'StopInstances'
      )
      AND time >= current_timestamp - interval '24' hour
    ORDER BY time DESC
    LIMIT 1000;
  EOT
}

# Failed authentication attempts
resource "aws_athena_named_query" "failed_authentication" {
  name        = "FailedAuthentication"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Detect faiuthentication attempts and potential brute force attacks"

  query = <<-EOT
    SELECT
      time,
      src_endpoint.ip as source_ip,
      actor.user.name as user_name,
      api.operation as api_operation,
      http_request.user_agent as user_agent,
      cloud.region,
      COUNT(*) as attempt_count
    FROM "${aws_glue_catalog_database.security_lake.name}"."cloudtrail_mgmt_2_0"
    WHERE
      api.response.error LIKE '%Authentication%'
      OR api.response.error LIKE '%Unauthorized%'
      OR api.response.error LIKE '%AccessDenied%'
      AND time >= current_timestamp - interval '1' hour
    GROUP BY
      time, src_endpoint.ip, actor.user.name, api.operation,
      http_request.user_agent, cloud.region
    HAVING COUNT(*) >= 5
    ORDER BY attempt_count DESC, time DESC
    LIMIT 500;
  EOT
}

# Root account usage
resource "aws_athena_named_query" "root_account_usage" {
  name        = "RootAccountUsage"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Monitor root account usage which should be rare"

  query = <<-EOT
    SELECT
      time,
      src_endpoint.ip as source_ip,
      actor.user.name as user_name,
      actor.user.type as user_type,
      api.operation as api_operation,
      api.service.name as service_name,
      cloud.region,
      raw_data
    FROM "${aws_glue_catalog_database.security_lake.name}"."cloudtrail_mgmt_2_0"
    WHERE
      (actor.user.type = 'Root' OR actor.user.name = 'root')
      AND time >= current_timestamp - interval '7' day
    ORDER BY time DESC
    LIMIT 100;
  EOT
}

############################################
# VPC Flow Logs Security Queries
############################################

# Suspicious network traffic
resource "aws_athena_named_query" "suspicious_network_traffic" {
  name        = "SuspiciousNetworkTraffic"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Detect suspicious network traffic patterns"

  query = <<-EOT
    SELECT
      time,
      src_endpoint.ip as source_ip,
      src_endpoint.port as source_port,
      dst_endpoint.ip as destination_ip,
      dst_endpoint.port as destination_port,
      connection_info.protocol_name as protocol,
      traffic.bytes as bytes_transferred,
      traffic.packets as packet_count,
      disposition as action
    FROM "${aws_glue_catalog_database.security_lake.name}"."vpc_flow_2_0"
    WHERE
      (
        dst_endpoint.port IN (22, 3389, 1433, 3306, 5432, 6379, 27017) -- Common attack targets
        OR traffic.bytes > 100000000 -- Large data transfers
        OR (disposition = 'REJECT' AND traffic.packets > 100) -- Many rejected packets
      )
      AND time >= current_timestamp - interval '1' hour
    ORDER BY traffic.bytes DESC, time DESC
    LIMIT 1000;
  EOT
}

# Data exfiltration detection
resource "aws_athena_named_query" "data_exfiltration" {
  name        = "DataExfiltration"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Detect potential data exfiltration based on traffic volume"

  query = <<-EOT
    SELECT
      src_endpoint.ip as source_ip,
      dst_endpoint.ip as destination_ip,
      SUM(traffic.bytes) as total_bytes,
      COUNT(*) as connection_count,
      MIN(time) as first_seen,
      MAX(time) as last_seen
    FROM "${aws_glue_catalog_database.security_lake.name}"."vpc_flow_2_0"
    WHERE
      time >= current_timestamp - interval '1' hour
      AND disposition = 'ACCEPT'
    GROUP BY src_endpoint.ip, dst_endpoint.ip
    HAVING SUM(traffic.bytes) > 1000000000 -- 1GB threshold
    ORDER BY total_bytes DESC
    LIMIT 100;
  EOT
}

############################################
# WAF Security Queries
############################################

# WAF blocked requests
resource "aws_athena_named_query" "waf_blocked_requests" {
  name        = "WAFBlockedRequests"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Analyze WAF blocked requests and attack patterns"

  query = <<-EOT
    SELECT
      time,
      src_endpoint.ip as attacker_ip,
      http_request.url.hostname as target_host,
      http_request.url.path as request_path,
      http_request.method as http_method,
      http_request.user_agent as user_agent,
      finding_info.title as rule_triggered,
      COUNT(*) as block_count
    FROM "${aws_glue_catalog_database.security_lake.name}"."waf_1_0"
    WHERE
      disposition = 'BLOCK'
      AND time >= current_timestamp - interval '24' hour
    GROUP BY
      time, src_endpoint.ip, http_request.url.hostname,
      http_request.url.path, http_request.method,
      http_request.user_agent, finding_info.title
    ORDER BY block_count DESC, time DESC
    LIMIT 500;
  EOT
}

############################################
# Lambda Security Queries
############################################

# Lambda execution anomalies
resource "aws_athena_named_query" "lambda_anomalies" {
  name        = "LambdaAnomalies"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Detect Lambda execution anomalies and potential security issues"

  query = <<-EOT
    SELECT
      time,
      cloud.region,
      resources[1].name as function_name,
      actor.user.name as invoker,
      api.operation as operation,
      api.response.error as error_message,
      severity,
      COUNT(*) as occurrence_count
    FROM "${aws_glue_catalog_database.security_lake.name}"."lambda_execution_1_0"
    WHERE
      (
        severity IN ('High', 'Critical')
        OR api.response.error IS NOT NULL
        OR duration_time > 300000 -- Functions running longer than 5 minutes
      )
      AND time >= current_timestamp - interval '24' hour
    GROUP BY
      time, cloud.region, resources[1].name, actor.user.name,
      api.operation, api.response.error, severity
    ORDER BY occurrence_count DESC, time DESC
    LIMIT 200;
  EOT
}

############################################
# Security Hub Findings Queries
############################################

# Critical security findings
resource "aws_athena_named_query" "critical_security_findings" {
  name        = "CriticalSecurityFindings"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Show critical and high severity security findings"

  query = <<-EOT
    SELECT
      time,
      finding_info.title as finding_title,
      finding_info.desc as description,
      severity as severity_level,
      compliance.status as compliance_status,
      resources[1].name as affected_resource,
      cloud.region,
      remediation.desc as remediation_guidance
    FROM "${aws_glue_catalog_database.security_lake.name}"."sh_findings_1_0"
    WHERE
      severity IN ('Critical', 'High')
      AND compliance.status = 'FAILED'
      AND time >= current_timestamp - interval '7' day
    ORDER BY
      CASE severity
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        ELSE 3
      END,
      time DESC
    LIMIT 500;
  EOT
}

############################################
# Route 53 DNS Security Queries
############################################

# Suspicious DNS queries
resource "aws_athena_named_query" "suspicious_dns_queries" {
  name        = "SuspiciousDNSQueries"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Detect suspicious DNS queries that might indicate malware or data exfiltration"

  query = <<-EOT
    SELECT
      time,
      src_endpoint.ip as client_ip,
      query.hostname as queried_domain,
      query.type as query_type,
      answers[1].rdata as resolved_ip,
      rcode as response_code,
      COUNT(*) as query_count
    FROM "${aws_glue_catalog_database.security_lake.name}"."route53_1_0"
    WHERE
      (
        query.hostname LIKE '%.tk' -- Suspicious TLD
        OR query.hostname LIKE '%.ml' -- Suspicious TLD
        OR query.hostname LIKE '%.ga' -- Suspicious TLD
        OR query.hostname LIKE '%.cf' -- Suspicious TLD
        OR LENGTH(query.hostname) > 50 -- Unusually long domains
        OR query.hostname RLIKE '[0-9]{8,}' -- Domains with many numbers
      )
      AND time >= current_timestamp - interval '24' hour
    GROUP BY
      time, src_endpoint.ip, query.hostname, query.type,
      answers[1].rdata, rcode
    HAVING COUNT(*) >= 10 -- Multiple queries to same suspicious domain
    ORDER BY query_count DESC, time DESC
    LIMIT 300;
  EOT
}

############################################
# Cross-Service Correlation Queries
############################################

# Security incident correlation
resource "aws_athena_named_query" "security_incident_correlation" {
  name        = "SecurityIncidentCorrelation"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Correlate security events across multiple data sources"

  query = <<-EOT
    WITH suspicious_ips AS (
      SELECT DISTINCT src_endpoint.ip as ip
      FROM "${aws_glue_catalog_database.security_lake.name}"."vpc_flow_2_0"
      WHERE disposition = 'REJECT'
        AND time >= current_timestamp - interval '1' hour
      GROUP BY src_endpoint.ip
      HAVING COUNT(*) > 100
    ),
    failed_logins AS (
      SELECT DISTINCT src_endpoint.ip as ip
      FROM "${aws_glue_catalog_database.security_lake.name}"."cloudtrail_mgmt_2_0"
      WHERE api.response.error LIKE '%Authentication%'
        AND time >= current_timestamp - interval '1' hour
    )
    SELECT
      s.ip as suspicious_ip,
      'Multiple rejected connections and failed authentication' as threat_indicator,
      current_timestamp as analysis_time
    FROM suspicious_ips s
    INNER JOIN failed_logins f ON s.ip = f.ip;
  EOT
}

############################################
# Compliance and Audit Queries
############################################

# Compliance dashboard query
resource "aws_athena_named_query" "compliance_dashboard" {
  name        = "ComplianceDashboard"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Generate compliance dashboard data"

  query = <<-EOT
    SELECT
      DATE(time) as date,
      compliance.standard as compliance_framework,
      compliance.status as status,
      COUNT(*) as finding_count,
      COUNT(CASE WHEN severity = 'Critical' THEN 1 END) as critical_count,
      COUNT(CASE WHEN severity = 'High' THEN 1 END) as high_count,
      COUNT(CASE WHEN severity = 'Medium' THEN 1 END) as medium_count,
      COUNT(CASE WHEN severity = 'Low' THEN 1 END) as low_count
    FROM "${aws_glue_catalog_database.security_lake.name}"."sh_findings_1_0"
    WHERE time >= current_timestamp - interval '30' day
    GROUP BY
      DATE(time), compliance.standard, compliance.status
    ORDER BY date DESC, compliance_framework, status;
  EOT
}

############################################
# Performance and Cost Optimization
############################################

# Data volume analysis
resource "aws_athena_named_query" "data_volume_analysis" {
  name        = "DataVolumeAnalysis"
  workgroup   = aws_athena_workgroup.security_lake.name
  database    = aws_glue_catalog_database.security_lake.name
  description = "Analyze data volume trends for cost optimization"

  query = <<-EOT
    SELECT
      DATE(time) as date,
      'CloudTrail' as source_type,
      COUNT(*) as record_count,
      APPROX_DISTINCT(src_endpoint.ip) as unique_sources
    FROM "${aws_glue_catalog_database.security_lake.name}"."cloudtrail_mgmt_2_0"
    WHERE time >= current_timestamp - interval '7' day
    GROUP BY DATE(time)

    UNION ALL

    SELECT
      DATE(time) as date,
      'VPC Flow' as source_type,
      COUNT(*) as record_count,
      APPROX_DISTINCT(src_endpoint.ip) as unique_sources
    FROM "${aws_glue_catalog_database.security_lake.name}"."vpc_flow_2_0"
    WHERE time >= current_timestamp - interval '7' day
    GROUP BY DATE(time)

    ORDER BY date DESC, source_type;
  EOT
}
