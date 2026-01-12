# KMS Key for all encrypted services
resource "aws_kms_key" "main" {
  description             = "Bank-grade CMK"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}
