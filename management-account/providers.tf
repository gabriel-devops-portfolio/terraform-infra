terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for state management
  backend "s3" {
    bucket  = "captaingab-terraform-state"
    key     = "management-account/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    #dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Account   = "Management"
    }
  }
}
