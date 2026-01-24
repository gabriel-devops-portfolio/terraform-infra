# Grafana OpenSearch Integration
# Purpose: Configure Grafana service account to access OpenSearch in security account

############################################
# Local Variables
############################################
locals {
  security_account_id = var.security_account_id # Add this to variables.tf
  workload_account_id = data.aws_caller_identity.current.account_id
}

############################################
# IAM Role for Grafana Service Account (IRSA)
############################################
resource "aws_iam_role" "grafana_service_account" {
  name = "grafana-service-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.kubernetes.oidc_provider_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "${replace(module.kubernetes.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:monitoring:kube-prometheus-stack-grafana"
            "${replace(module.kubernetes.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "grafana-service-account-role"
    Purpose   = "grafana-opensearch-access"
    Component = "observability"
  })
}

# IAM Policy for Cross-Account OpenSearch Access
resource "aws_iam_policy" "grafana_cross_account_opensearch" {
  name        = "GrafanaCrossAccountOpenSearchPolicy"
  description = "Policy for Grafana to assume role in security account for OpenSearch access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeOpenSearchRole"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::${local.security_account_id}:role/GrafanaOpenSearchRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "grafana-opensearch-${local.security_account_id}"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "grafana-cross-account-opensearch-policy"
    Purpose = "cross-account-access"
  })
}

resource "aws_iam_role_policy_attachment" "grafana_cross_account_opensearch" {
  role       = aws_iam_role.grafana_service_account.name
  policy_arn = aws_iam_policy.grafana_cross_account_opensearch.arn
}

############################################
# Kubernetes Service Account Annotation
############################################
resource "kubernetes_annotations" "grafana_service_account" {
  api_version = "v1"
  kind        = "ServiceAccount"

  metadata {
    name      = "kube-prometheus-stack-grafana"
    namespace = "monitoring"
  }

  annotations = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.grafana_service_account.arn
  }

  depends_on = [module.kubernetes]
}

############################################
# Kubernetes Secret for OpenSearch Configuration
############################################
resource "kubernetes_secret" "opensearch_config" {
  metadata {
    name      = "opensearch-grafana-config"
    namespace = "monitoring"
  }

  data = {
    opensearch_endpoint = "https://search-security-logs-${random_id.opensearch_suffix.hex}.${data.aws_region.current.name}.es.amazonaws.com"
    security_account_id = local.security_account_id
    cross_account_role  = "arn:aws:iam::${local.security_account_id}:role/GrafanaOpenSearchRole"
    external_id         = "grafana-opensearch-${local.security_account_id}"
  }

  type = "Opaque"

  depends_on = [module.kubernetes]
}

# Random ID for OpenSearch domain suffix (to match the actual domain)
resource "random_id" "opensearch_suffix" {
  byte_length = 8
}

############################################
# ConfigMap for Grafana Dashboard Provisioning
############################################
resource "kubernetes_config_map" "security_dashboards" {
  metadata {
    name      = "security-dashboards"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "security-overview.json" = jsonencode({
      dashboard = {
        id       = null
        title    = "Security Overview - OCSF Data"
        tags     = ["security", "ocsf", "security-lake"]
        style    = "dark"
        timezone = "browser"
        panels = [
          {
            id    = 1
            title = "Security Events Over Time"
            type  = "timeseries"
            targets = [
              {
                datasource = {
                  type = "opensearch"
                  uid  = "opensearch-security-logs"
                }
                query     = "class_name:\"API Activity\" OR class_name:\"Network Activity\""
                timeField = "@timestamp"
                metrics = [
                  {
                    type = "count"
                    id   = "1"
                  }
                ]
                bucketAggs = [
                  {
                    type  = "date_histogram"
                    field = "@timestamp"
                    id    = "2"
                    settings = {
                      interval = "auto"
                    }
                  }
                ]
              }
            ]
            gridPos = {
              h = 8
              w = 12
              x = 0
              y = 0
            }
          },
          {
            id    = 2
            title = "Top Security Event Types"
            type  = "piechart"
            targets = [
              {
                datasource = {
                  type = "opensearch"
                  uid  = "opensearch-security-logs"
                }
                query     = "*"
                timeField = "@timestamp"
                metrics = [
                  {
                    type = "count"
                    id   = "1"
                  }
                ]
                bucketAggs = [
                  {
                    type  = "terms"
                    field = "class_name.keyword"
                    id    = "2"
                    settings = {
                      size = 10
                    }
                  }
                ]
              }
            ]
            gridPos = {
              h = 8
              w = 12
              x = 12
              y = 0
            }
          },
          {
            id    = 3
            title = "Failed Authentication Attempts"
            type  = "stat"
            targets = [
              {
                datasource = {
                  type = "opensearch"
                  uid  = "opensearch-security-logs"
                }
                query     = "class_name:\"Authentication\" AND activity_name:\"Logon\" AND status:\"Failure\""
                timeField = "@timestamp"
                metrics = [
                  {
                    type = "count"
                    id   = "1"
                  }
                ]
              }
            ]
            gridPos = {
              h = 4
              w = 6
              x = 0
              y = 8
            }
          },
          {
            id    = 4
            title = "Network Anomalies"
            type  = "stat"
            targets = [
              {
                datasource = {
                  type = "opensearch"
                  uid  = "opensearch-security-logs"
                }
                query     = "class_name:\"Network Activity\" AND severity:\"High\""
                timeField = "@timestamp"
                metrics = [
                  {
                    type = "count"
                    id   = "1"
                  }
                ]
              }
            ]
            gridPos = {
              h = 4
              w = 6
              x = 6
              y = 8
            }
          }
        ]
        time = {
          from = "now-24h"
          to   = "now"
        }
        refresh = "30s"
      }
    })

    "terraform-state-access.json" = jsonencode({
      dashboard = {
        id       = null
        title    = "Terraform State Access Monitoring"
        tags     = ["security", "terraform", "infrastructure"]
        style    = "dark"
        timezone = "browser"
        panels = [
          {
            id    = 1
            title = "Terraform State Access Events"
            type  = "timeseries"
            targets = [
              {
                datasource = {
                  type = "opensearch"
                  uid  = "opensearch-security-logs"
                }
                query     = "source_name:\"TerraformStateAccess\""
                timeField = "@timestamp"
                metrics = [
                  {
                    type = "count"
                    id   = "1"
                  }
                ]
                bucketAggs = [
                  {
                    type  = "date_histogram"
                    field = "@timestamp"
                    id    = "2"
                    settings = {
                      interval = "auto"
                    }
                  }
                ]
              }
            ]
            gridPos = {
              h = 8
              w = 24
              x = 0
              y = 0
            }
          },
          {
            id    = 2
            title = "Access by User"
            type  = "table"
            targets = [
              {
                datasource = {
                  type = "opensearch"
                  uid  = "opensearch-security-logs"
                }
                query     = "source_name:\"TerraformStateAccess\""
                timeField = "@timestamp"
                metrics = [
                  {
                    type = "count"
                    id   = "1"
                  }
                ]
                bucketAggs = [
                  {
                    type  = "terms"
                    field = "actor.user.name.keyword"
                    id    = "2"
                    settings = {
                      size = 20
                    }
                  }
                ]
              }
            ]
            gridPos = {
              h = 8
              w = 12
              x = 0
              y = 8
            }
          },
          {
            id    = 3
            title = "Access by Source IP"
            type  = "table"
            targets = [
              {
                datasource = {
                  type = "opensearch"
                  uid  = "opensearch-security-logs"
                }
                query     = "source_name:\"TerraformStateAccess\""
                timeField = "@timestamp"
                metrics = [
                  {
                    type = "count"
                    id   = "1"
                  }
                ]
                bucketAggs = [
                  {
                    type  = "terms"
                    field = "src_endpoint.ip.keyword"
                    id    = "2"
                    settings = {
                      size = 20
                    }
                  }
                ]
              }
            ]
            gridPos = {
              h = 8
              w = 12
              x = 12
              y = 8
            }
          }
        ]
        time = {
          from = "now-7d"
          to   = "now"
        }
        refresh = "1m"
      }
    })
  }

  depends_on = [module.kubernetes]
}
