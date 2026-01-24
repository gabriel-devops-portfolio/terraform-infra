############################
# RDS Security Group
############################
resource "aws_security_group" "rds" {
  name        = "${var.env}-rds-sg"
  description = "Security group for RDS SQL Server - allows traffic from EKS cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SQL Server from EKS cluster"
    from_port       = 1433
    to_port         = 1433
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

  identifier           = "${var.env}-db"
  engine               = "sqlserver-se"
  engine_version       = var.db_engine_version
  major_engine_version = "16.00"
  instance_class       = var.db_instance_class
  family               = "sqlserver-se-16.0"
  license_model        = "license-included"
  timezone             = "GMT Standard Time"

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
  enabled_cloudwatch_logs_exports = ["error", "agent"]

  # High Availability
  multi_az = true

  # Database Configuration
  # db_name is not supported for SQL Server (no initial db created)
  username = "dbadmin"
  port     = "1433"

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn != "" ? var.kms_key_arn : null
  performance_insights_retention_period = 7

  # Deletion Protection
  deletion_protection              = true
  skip_final_snapshot              = false
  final_snapshot_identifier_prefix = "${var.env}-db-final-snapshot"

  tags = {
    Name        = "${var.env}-rds-sqlserver"
    Environment = var.env
    Backup      = "true"
  }
}
