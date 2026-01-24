############################################
# IAM Roles for Jaeger OpenSearch Integration
############################################

############################################
# Jaeger OpenSearch Access Role (IRSA)
############################################
resource "aws_iam_role" "jaeger_opensearch" {
  name        = "JaegerElasticsearchRole"
  description = "IAM role for Jaeger to access OpenSearch domain"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "opensearch.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = [
              "system:serviceaccount:observability:jaeger-collector",
              "system:serviceaccount:observability:jaeger-query"
            ]
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "JaegerElasticsearchRole"
  })
}

############################################
# Jaeger OpenSearch Access Policy
############################################
resource "aws_iam_role_policy" "jaeger_opensearch" {
  name = "JaegerOpenSearchAccess"
  role = aws_iam_role.jaeger_opensearch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpGet",
          "es:ESHttpDelete",
          "es:ESHttpHead"
        ]
        Resource = "${aws_opensearch_domain.jaeger.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "es:DescribeElasticsearchDomain",
          "es:DescribeElasticsearchDomains",
          "es:DescribeElasticsearchDomainConfig",
          "es:ListDomainNames",
          "es:ListTags"
        ]
        Resource = aws_opensearch_domain.jaeger.arn
      }
    ]
  })
}

############################################
# OpenSearch Domain Access Policy
############################################
resource "aws_opensearch_domain_policy" "jaeger" {
  domain_name = aws_opensearch_domain.jaeger.domain_name

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.jaeger_opensearch.arn
        }
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpGet",
          "es:ESHttpDelete",
          "es:ESHttpHead"
        ]
        Resource = "${aws_opensearch_domain.jaeger.arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "es:*"
        Resource = "${aws_opensearch_domain.jaeger.arn}/*"
      }
    ]
  })
}

############################################
# CloudWatch Logs Resource Policy
############################################
resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  policy_name = "opensearch-jaeger-logs-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "opensearch.amazonaws.com"
        }
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      }
    ]
  })
}
