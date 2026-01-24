# 🗄️ Data Persistence Module (RDS & S3)

This module provisions the persistent data layer for the banking application, including a high-availability RDS SQL Server instance and a secure S3 bucket for backups.

## 🏗️ Architecture

- **RDS SQL Server**:
  - **Engine**: SQL Server Standard Edition (SE) 16.0
  - **Deployment**: Multi-AZ for high availability
  - **Encryption**: KMS encrypted at rest (`var.kms_key_arn`)
  - **Security**: Private subnet deployment (no public access)
  - **Access Control**: IAM authentication enabled + Security Group access from EKS
  - **Backups**: 35-day retention with deletion protection enabled

- **S3 Backup Bucket**:
  - **Versioning**: Enabled for data recovery
  - **Encryption**: KMS encrypted (`aws:kms`)
  - **Public Access**: Fully blocked (Block Public Access enabled)

## 📋 Inputs

| Name                            | Type           | Description                                          | Default                            |
| ------------------------------- | -------------- | ---------------------------------------------------- | ---------------------------------- |
| `env`                           | `string`       | Environment name (e.g., `prod`, `dev`)               | -                                  |
| `vpc_id`                        | `string`       | VPC ID for RDS deployment                            | -                                  |
| `database_subnets`              | `list(string)` | List of subnet IDs for RDS                           | -                                  |
| `eks_cluster_security_group_id` | `string`       | Security Group ID of the EKS cluster to allow access | -                                  |
| `kms_key_arn`                   | `string`       | KMS Key ARN for encryption                           | (Optional - uses default if empty) |
| `db_instance_class`             | `string`       | RDS instance type                                    | `db.t3.medium`                     |
| `db_allocated_storage`          | `number`       | Storage size in GB                                   | `100`                              |
| `db_engine_version`             | `string`       | RDS engine version                                   | `15.5`                             |

## 📤 Outputs

| Name                    | Description                       |
| ----------------------- | --------------------------------- |
| `rds_endpoint`          | Endpoint URL of the RDS instance  |
| `rds_instance_id`       | Identifier of the RDS instance    |
| `rds_database_name`     | Name of the database              |
| `rds_security_group_id` | Security Group ID attached to RDS |
| `rds_subnet_group_name` | RDS Subnet Group name             |
| `rds_arn`               | ARN of the RDS instance           |
| `backup_bucket_arn`     | ARN of the S3 backup bucket       |
| `backup_bucket_name`    | Name of the S3 backup bucket      |

## 🛡️ Security Features

1.  **Network Isolation**: DB is placed in `database_subnets`, which should be private subnets.
2.  **Encryption**:
    - **RDS**: Encrypted at rest using KMS.
    - **S3**: Encrypted at rest using KMS.
3.  **Access Control**:
    - RDS Security Group only allows ingress on port `1433` (SQL Server) from the EKS Cluster Security Group.
    - S3 bucket has `Block Public Access` fully enabled.
4.  **Data Protection**:
    - RDS `deletion_protection` is enabled.
    - RDS `skip_final_snapshot` is false.
    - S3 Versioning is enabled.

## 🚀 Usage Example

```hcl
module "data" {
  source = "../modules/data"

  env                             = "prod"
  vpc_id                          = module.networking.vpc_id
  database_subnets                = module.networking.database_subnets
  eks_cluster_security_group_id   = module.eks.cluster_security_group_id
  kms_key_arn                     = module.kms.key_arn

  db_instance_class               = "db.r6i.large"
  db_allocated_storage            = 200
}
```

## 📝 Notes

- The default engine is `sqlserver-se`. Adjust configuration if PostgreSQL or MySQL is needed (module is currently hardcoded to SQL Server in `main.tf`).
- `db_name` is not supported for SQL Server instances; databases must be created after provisioning.
