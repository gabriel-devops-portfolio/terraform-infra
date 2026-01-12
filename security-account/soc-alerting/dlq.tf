############################################################
# EVENTBRIDGE DEAD-LETTER QUEUE (DLQ)
############################################################
resource "aws_sqs_queue" "soc_alerts_dlq" {
  name                      = "soc-security-alerts-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = "alias/aws/sqs"

  tags = {
    Purpose = "DLQ for failed SOC alert notifications"
    Owner   = "SOC"
  }
}
