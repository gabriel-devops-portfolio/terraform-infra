############################################
# Terraform Backend – Security Account
############################################
terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "org-security-account-terraform-state-prod"
    key            = "security/backend-bootstrap.tfstate"
    region         = "us-east-1"
    #dynamodb_table = "terraform-locks-prod"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
