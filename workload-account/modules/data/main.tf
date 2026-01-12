############################
# RDS Security Group
############################
resource "aws_security_group" "rds" {
  name        = "${var.env}-rds-sg"
  description = "Security group for RDS PostgreSQL - allows traffic from EKS cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS cluster"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.env}-rds-sg"
    Environment = var.env
    Purpose     = "database"
  }
}

############################
# RDS Subnet Group
############################
resource "aws_db_subnet_group" "main" {
  name       = "${var.env}-rds-subnet-group"
  subnet_ids = var.database_subnets

  tags = {
    Name        = "${var.env}-rds-subnet-group"
    Environment = var.env
  }
}

############################
# RDS with KMS and IAM Auth
############################
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier     = "${var.env}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Storage Configuration
  allocated_storage = var.db_allocated_storage
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null

  # Security Configuration
  iam_database_authentication_enabled = true
  vpc_security_group_ids              = [aws_security_group.rds.id]

  # Network Configuration
  db_subnet_group_name = aws_db_subnet_group.main.name
  publicly_accessible  = false

  # Backup Configuration
  backup_retention_period         = 35
  backup_window                   = "03:00-04:00"
  maintenance_window              = "sun:04:00-sun:05:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # High Availability
  multi_az = true

  # Database Configuration
  db_name  = "${var.env}db"
  username = "dbadmin"
  port     = "5432"

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn != "" ? var.kms_key_arn : null
  performance_insights_retention_period = 7

  # Deletion Protection
  deletion_protection              = true
  skip_final_snapshot              = false
  final_snapshot_identifier_prefix = "${var.env}-db-final-snapshot"

  tags = {
    Name        = "${var.env}-rds-postgres"
    Environment = var.env
    Backup      = "true"
  }
}

# S3 with Versioning & Encryption (duplicate definition, keeping this one)
# The s3.tf file has the actual backup bucket, commenting this out
# resource "aws_s3_bucket" "backups" {
#   bucket = "${var.env}-bank-backups"
# }

# resource "aws_s3_bucket_versioning" "v" {
#   bucket = aws_s3_bucket.backups.id
#   versioning_configuration { status = "Enabled" }
# }
