# Staging environment main configuration

module "networking" {
  source = "../../modules/networking"
  # Staging-specific networking variables
}

module "security" {
  source = "../../modules/security"
  # Staging-specific security variables
}

module "compute" {
  source = "../../modules/compute"
  # Staging-specific compute variables
}

module "data" {
  source = "../../modules/data"
  # Staging-specific data variables
}
