############################################
# Network Firewall – Egress Inspection
############################################

############################################
# Stateful Rule Group – Controlled Allowlist
############################################
resource "aws_networkfirewall_rule_group" "egress_allowlist" {
  name     = "${var.env}-egress-allowlist"
  capacity = 200
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]

        targets = [
          # AWS core services (ECR, STS, S3, etc)
          ".amazonaws.com",

          # GitOps
          ".github.com",
          ".githubusercontent.com",

          # Observability (Elastic / EFK)
          ".docker.elastic.co",
          ".ghcr.io"
        ]
      }
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = {
    Environment = var.env
    Purpose     = "egress-allowlist"
  }
}

############################################
# Firewall Policy – STRICT, FAIL-CLOSE
############################################
resource "aws_networkfirewall_firewall_policy" "egress" {
  name = "${var.env}-firewall-policy"

  firewall_policy {
    # Stateless → send to stateful engine
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:drop"]

    # Stateful default = DROP (fail-close)
    stateful_default_actions = ["aws:drop_strict"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.egress_allowlist.arn
    }
  }

  tags = {
    Environment = var.env
    Purpose     = "egress-firewall-policy"
  }
}

############################################
# Network Firewall (AZ-aware)
############################################
resource "aws_networkfirewall_firewall" "egress" {
  name                = "${var.env}-egress-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.egress.arn
  vpc_id              = module.egress_vpc.vpc_id

  dynamic "subnet_mapping" {
    for_each = var.firewall_subnets
    content {
      subnet_id = subnet_mapping.value
    }
  }

  delete_protection                 = true
  firewall_policy_change_protection = true
  subnet_change_protection          = true

  tags = {
    Environment = var.env
    Purpose     = "central-egress-inspection"
  }
}

############################################
# Discover Firewall Endpoints (per AZ)
############################################
data "aws_networkfirewall_firewall" "this" {
  name = aws_networkfirewall_firewall.egress.name
}

locals {
  # Map AZ directly to endpoint
  firewall_endpoints = {
    for state in data.aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.availability_zone => state.attachment[0].endpoint_id
  }
}

# Note: Firewall subnets are defined as Private Subnets in the Egress VPC module.
# Routes to NAT Gateway are automatically managed by the VPC module.
