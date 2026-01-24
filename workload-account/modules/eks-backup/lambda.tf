# Lambda Functions for EKS Backup Operations

############################
# EBS Snapshot Lambda Function
############################

# Lambda function code for EBS snapshots
resource "aws_lambda_function" "ebs_snapshot" {
  count = var.enable_ebs_snapshots ? 1 : 0

  filename         = data.archive_file.ebs_snapshot_zip[0].output_path
  function_name    = "${var.cluster_name}-ebs-snapshot"
  role            = aws_iam_role.ebs_snapshot_lambda.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.ebs_snapshot_zip[0].output_base64sha256
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      CLUSTER_NAME = var.cluster_name
      RETENTION_DAYS = var.backup_retention_days
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-ebs-snapshot"
    Purpose   = "EKSBackup"
    Component = "EBSSnapshot"
  })
}

# Create the Lambda deployment package
data "archive_file" "ebs_snapshot_zip" {
  count = var.enable_ebs_snapshots ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/ebs_snapshot.zip"
  source {
    content = templatefile("${path.module}/lambda_functions/ebs_snapshot.py", {
      cluster_name = var.cluster_name
    })
    filename = "index.py"
  }
}

# EventBridge rule for scheduled EBS snapshots
resource "aws_cloudwatch_event_rule" "ebs_snapshot_schedule" {
  count = var.enable_ebs_snapshots ? 1 : 0

  name                = "${var.cluster_name}-ebs-snapshot-schedule"
  description         = "Trigger EBS snapshot Lambda on schedule"
  schedule_expression = "cron(${var.backup_schedule})"

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-ebs-snapshot-schedule"
    Purpose   = "EKSBackup"
    Component = "EBSSnapshot"
  })
}

# EventBridge target for EBS snapshot Lambda
resource "aws_cloudwatch_event_target" "ebs_snapshot_target" {
  count = var.enable_ebs_snapshots ? 1 : 0

  rule      = aws_cloudwatch_event_rule.ebs_snapshot_schedule[0].name
  target_id = "EBSSnapshotLambdaTarget"
  arn       = aws_lambda_function.ebs_snapshot[0].arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_ebs" {
  count = var.enable_ebs_snapshots ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_snapshot[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ebs_snapshot_schedule[0].arn
}

############################
# Backup Cleanup Lambda Function
############################

# Lambda function for cleaning up old backups
resource "aws_lambda_function" "backup_cleanup" {
  filename         = data.archive_file.backup_cleanup_zip.output_path
  function_name    = "${var.cluster_name}-backup-cleanup"
  role            = aws_iam_role.backup_cleanup_lambda.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.backup_cleanup_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      CLUSTER_NAME = var.cluster_name
      VELERO_BUCKET = aws_s3_bucket.velero_backups.bucket
      ETCD_BUCKET = aws_s3_bucket.etcd_backups.bucket
      RETENTION_DAYS = var.backup_retention_days
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-backup-cleanup"
    Purpose   = "EKSBackup"
    Component = "BackupCleanup"
  })
}

# IAM Role for Backup Cleanup Lambda
resource "aws_iam_role" "backup_cleanup_lambda" {
  name = "${var.cluster_name}-backup-cleanup-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-backup-cleanup-lambda"
    Purpose   = "EKSBackup"
    Component = "BackupCleanup"
  })
}

# IAM Policy for Backup Cleanup Lambda
resource "aws_iam_policy" "backup_cleanup_lambda" {
  name        = "${var.cluster_name}-backup-cleanup-lambda-policy"
  description = "Policy for backup cleanup Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.velero_backups.arn,
          "${aws_s3_bucket.velero_backups.arn}/*",
          aws_s3_bucket.etcd_backups.arn,
          "${aws_s3_bucket.etcd_backups.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSnapshots",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_cleanup_lambda" {
  role       = aws_iam_role.backup_cleanup_lambda.name
  policy_arn = aws_iam_policy.backup_cleanup_lambda.arn
}

# Create the backup cleanup Lambda deployment package
data "archive_file" "backup_cleanup_zip" {
  type        = "zip"
  output_path = "${path.module}/backup_cleanup.zip"
  source {
    content = templatefile("${path.module}/lambda_functions/backup_cleanup.py", {
      cluster_name = var.cluster_name
    })
    filename = "index.py"
  }
}

# EventBridge rule for backup cleanup
resource "aws_cloudwatch_event_rule" "backup_cleanup_schedule" {
  name                = "${var.cluster_name}-backup-cleanup-schedule"
  description         = "Trigger backup cleanup Lambda weekly"
  schedule_expression = "cron(0 3 ? * SUN *)" # Weekly on Sunday at 3 AM

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-backup-cleanup-schedule"
    Purpose   = "EKSBackup"
    Component = "BackupCleanup"
  })
}

# EventBridge target for backup cleanup Lambda
resource "aws_cloudwatch_event_target" "backup_cleanup_target" {
  rule      = aws_cloudwatch_event_rule.backup_cleanup_schedule.name
  target_id = "BackupCleanupLambdaTarget"
  arn       = aws_lambda_function.backup_cleanup.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_cleanup" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_cleanup_schedule.arn
}
