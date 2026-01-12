output "eks_kms_key_arn" {
  value = aws_kms_key.eks.arn
}

output "eks_kms_key_id" {
  value = aws_kms_key.eks.key_id
}
