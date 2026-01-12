############################################
# AWS Glue Configuration for Security Lake
# Purpose: Catalog Security Lake data for Athena queries
############################################

############################################
# Glue Catalog Database
############################################
resource "aws_glue_catalog_database" "security_lake" {
  name        = "amazon_security_lake_glue_db_${replace(local.region, "-", "_")}"
  description = "Security Lake data catalog for Athena queries"

  tags = merge(local.common_tags, {
    Name = "security-lake-database"
  })
}

############################################
# IAM Role for Glue Crawler
############################################
resource "aws_iam_role" "glue_crawler" {
  name        = "SecurityLakeGlueCrawlerRole"
  description = "Role for Glue Crawler to catalog Security Lake data"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "GlueCrawlerRole"
  })
}

# Attach AWS Glue Service Role policy
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Additional policy for Security Lake bucket access
resource "aws_iam_role_policy" "glue_security_lake_access" {
  name = "SecurityLakeAccess"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSecurityLakeBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::aws-security-data-lake-*",
          "arn:aws:s3:::aws-security-data-lake-*/*"
        ]
      },
      {
        Sid    = "DecryptKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "s3.${local.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

############################################
# Glue Crawler for Security Lake
############################################
resource "aws_glue_crawler" "security_lake" {
  name          = "security-lake-crawler"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.security_lake.name
  description   = "Crawler to catalog Security Lake OCSF data"

  # Security Lake S3 bucket path
  s3_target {
    path = "s3://aws-security-data-lake-${local.region}-${local.security_account_id}/ext/"
  }

  # Schema change policy
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  # Recrawl policy - only new folders
  recrawl_policy {
    recrawl_behavior = "CRAWL_NEW_FOLDERS_ONLY"
  }

  # Run every 6 hours
  schedule = "cron(0 */6 * * ? *)"

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })

  tags = merge(local.common_tags, {
    Name = "security-lake-crawler"
  })

  depends_on = [
    aws_securitylake_data_lake.main,
    aws_iam_role_policy.glue_security_lake_access
  ]
}

############################################
# Athena Workgroup for Security Lake Queries
############################################
resource "aws_s3_bucket" "athena_results" {
  bucket = "org-athena-security-lake-results-${local.security_account_id}"

  tags = merge(local.common_tags, {
    Name    = "athena-query-results"
    Purpose = "athena-security-lake-queries"
  })
}

# Athena results bucket - Versioning
resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Athena results bucket - Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Athena results bucket - Public access block
resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Athena results bucket - Lifecycle
resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "delete-old-results"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Athena Workgroup
resource "aws_athena_workgroup" "security_lake" {
  name        = "security-lake-queries"
  description = "Workgroup for querying Security Lake data"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }

  tags = merge(local.common_tags, {
    Name = "security-lake-workgroup"
  })
}
