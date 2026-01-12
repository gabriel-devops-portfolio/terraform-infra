############################################################
# SNS TOPICS BY SEVERITY
############################################################

resource "aws_sns_topic" "critical" {
  name = "soc-alerts-critical"
}

resource "aws_sns_topic" "high" {
  name = "soc-alerts-high"
}

resource "aws_sns_topic" "medium" {
  name = "soc-alerts-medium"
}

resource "aws_sns_topic_subscription" "email_critical" {
  topic_arn = aws_sns_topic.critical.arn
  protocol  = "email"
  endpoint  = "captain.gab@protonmail.com"
}

resource "aws_sns_topic_subscription" "email_high" {
  topic_arn = aws_sns_topic.high.arn
  protocol  = "email"
  endpoint  = "captain.gab@protonmail.com"
}

resource "aws_sns_topic_subscription" "email_medium" {
  topic_arn = aws_sns_topic.medium.arn
  protocol  = "email"
  endpoint  = "captain.gab@protonmail.com"
}

############################################################
# OUTPUTS
############################################################

output "critical_topic_arn" {
  description = "ARN of the critical severity SNS topic"
  value       = aws_sns_topic.critical.arn
}

output "high_topic_arn" {
  description = "ARN of the high severity SNS topic"
  value       = aws_sns_topic.high.arn
}

output "medium_topic_arn" {
  description = "ARN of the medium severity SNS topic"
  value       = aws_sns_topic.medium.arn
}

output "sns_topics" {
  description = "Map of all SNS topic ARNs by severity"
  value = {
    critical = aws_sns_topic.critical.arn
    high     = aws_sns_topic.high.arn
    medium   = aws_sns_topic.medium.arn
  }
}
