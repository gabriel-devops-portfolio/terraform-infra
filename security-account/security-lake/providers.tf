############################################
# Terraform Provider Configuration
# Security Lake Module
############################################

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "terraform-infra"
      ManagedBy   = "terraform"
      Environment = "production"
      Module      = "security-lake"
    }
  }
}
