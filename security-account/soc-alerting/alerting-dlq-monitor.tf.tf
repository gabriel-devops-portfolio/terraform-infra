resource "aws_cloudwatch_metric_alarm" "soc_dlq_alarm" {
  alarm_name          = "soc-dlq-messages-present"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    QueueName = aws_sqs_queue.soc_alerts_dlq.name
  }

  treat_missing_data = "notBreaching"

  alarm_description = "SOC alert delivery failure: messages detected in SQS DLQ"

  alarm_actions = [
    aws_sns_topic.high.arn
  ]
}
