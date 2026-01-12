############################################
# EventBridge – Firewall Health Events
############################################
resource "aws_cloudwatch_event_rule" "firewall_events" {
  name        = "${var.env}-firewall-health-events"
  description = "React to Network Firewall health changes"

  event_pattern = jsonencode({
    source      = ["aws.network-firewall"]
    detail-type = [
      "Network Firewall Stateful Engine Health Change",
      "Network Firewall Stateless Engine Health Change"
    ]
  })
}

resource "aws_cloudwatch_event_target" "firewall_lambda" {
  rule = aws_cloudwatch_event_rule.firewall_events.name
  arn  = aws_lambda_function.inspection_controller.arn
}

############################################
# EventBridge – Scheduled Health Poll
############################################
resource "aws_cloudwatch_event_rule" "scheduled_check" {
  name                = "${var.env}-inspection-scheduled-check"
  description         = "Periodic firewall health verification"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "scheduled_lambda" {
  rule = aws_cloudwatch_event_rule.scheduled_check.name
  arn  = aws_lambda_function.inspection_controller.arn
}

############################################
# Lambda Permissions – EventBridge
############################################
resource "aws_lambda_permission" "allow_eventbridge_firewall" {
  statement_id  = "AllowEventBridgeFirewallEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inspection_controller.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.firewall_events.arn
}

resource "aws_lambda_permission" "allow_eventbridge_schedule" {
  statement_id  = "AllowEventBridgeScheduledCheck"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inspection_controller.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled_check.arn
}
