############################################
# Access Logs Bucket
############################################
resource "aws_s3_bucket" "terraform_state_logs" {
  bucket = "workload-account-terraform-state-access-logs"

  tags = {
    Name        = "terraform-state-access-logs"
    Environment = "prod"
    Account     = "security"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
