# Grafana OpenSearch Access Configuration
# Purpose: Allow Grafana in workload account to access OpenSearch in security account

############################################
# IAM Role for Grafana to Access OpenSearch
############################################
resource "aws_iam_role" "grafana_opensearch" {
  name        = "GrafanaOpenSearchRole"
  description = "Cross-account role for Grafana to access OpenSearch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.workload_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "grafana-opensearch-${local.security_account_id}"
          }
          StringLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${local.workload_account_id}:role/grafana-*",
              "arn:aws:iam::${local.workload_account_id}:role/*grafana*"
            ]
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "grafana-opensearch-access-role"
    Purpose = "cross-account-opensearch-access"
  })
}

# IAM Policy for OpenSearch Access
resource "aws_iam_policy" "grafana_opensearch" {
  name        = "GrafanaOpenSearchPolicy"
  description = "Policy for Grafana to access OpenSearch domain"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OpenSearchDomainAccess"
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpHead"
        ]
        Resource = [
          "arn:aws:es:${data.aws_region.current.name}:${local.security_account_id}:domain/security-logs",
          "arn:aws:es:${data.aws_region.current.name}:${local.security_account_id}:domain/security-logs/*"
        ]
      },
      {
        Sid    = "OpenSearchClusterAccess"
        Effect = "Allow"
        Action = [
          "es:DescribeDomain",
          "es:DescribeDomains",
          "es:DescribeDomainConfig",
          "es:ListDomainNames",
          "es:ListTags"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "grafana-opensearch-policy"
    Purpose = "opensearch-read-access"
  })
}

resource "aws_iam_role_policy_attachment" "grafana_opensearch" {
  role       = aws_iam_role.grafana_opensearch.name
  policy_arn = aws_iam_policy.grafana_opensearch.arn
}

# Note: OpenSearch domain access policy is managed by the opensearch module
# This role can be referenced by the opensearch module for cross-account access
