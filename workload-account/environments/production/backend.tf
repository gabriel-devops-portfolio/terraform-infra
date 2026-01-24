terraform {
  backend "s3" {
    bucket         = "org-workload-terraform-state-prod"
    key            = "production/workload/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-prod"
    encrypt        = true
    role_arn       = "arn:aws:iam::333333444444:role/TerraformExecutionRole"
  }
}
