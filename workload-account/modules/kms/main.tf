//todo: define what is the key policy and who can access it, discuss rotation
output "test-oz" {
  value = format("var is: %s", var.environment)
}

resource "aws_kms_key" "eks" {
  description         = "KMS Key for EKS ${var.environment}"
  enable_key_rotation = var.enable_key_rotation
  tags = {
    "Environment" : var.environment,
    "Name" : format("%s-eks-encryption-key", var.environment)
  }
}

resource "aws_kms_key" "s3" {
  description         = "KMS Key for S3 ${var.environment}"
  enable_key_rotation = var.enable_key_rotation
  tags = {
    "Environment" : var.environment,
    "Name" : format("%s-s3-encryption-key", var.environment)
  }
}

resource "aws_kms_key_policy" "kms_policy" {
  count = var.enable_custom_kms_key_policy ? 1 : 0

  key_id = aws_kms_key.eks.id
  policy = var.custom_kms_key_policy
}

resource "aws_kms_alias" "a" {
  name          = format("alias/%s-key", var.environment)
  target_key_id = aws_kms_key.eks.key_id
}
