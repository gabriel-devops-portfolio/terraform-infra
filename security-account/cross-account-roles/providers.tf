# terraform {
#   required_version = ">= 1.5.0"

#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }

#   # Backend configuration - update with your actual state bucket
#   backend "s3" {
#     bucket         = "org-workload-terraform-state-prod"
#     key            = "security-account/cross-account-roles/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks-prod"
#     encrypt        = true
#     # role_arn       = "arn:aws:iam::404068503087:role/TerraformExecutionRole"
#   }
# }

# provider "aws" {
#   region = var.region

#   default_tags {
#     tags = var.tags
#   }
# }
