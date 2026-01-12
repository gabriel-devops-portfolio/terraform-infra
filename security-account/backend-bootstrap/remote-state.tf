# data "terraform_remote_state" "workload_network" {
#   backend = "s3"

#   config = {
#     bucket   = "org-terraform-state-bucket"
#     key      = "workload/networking/terraform.tfstate"
#     region   = "us-east-1"
#     role_arn = "arn:aws:iam::<WORKLOAD_ACCOUNT_ID>:role/TerraformReadStateRole"
#   }
# }
