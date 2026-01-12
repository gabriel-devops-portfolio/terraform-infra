############################################
# S3 Bucket for -workload -Terraform State
############################################
resource "aws_s3_bucket" "terraform_state" {
  bucket = "org-workload-terraform-state-prod"

  tags = {
    Name        = "workload-terraform-state-prod"
    Environment = "prod"
    Account     = "workload"
    ManagedBy   = "terraform"
  }
}

############################################
# Versioning
############################################
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

############################################
# Server-Side Encryption
############################################
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket        = aws_s3_bucket.terraform_state.id
  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "terraform-state/"
}

############################################
# Block ALL Public Access
############################################
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
