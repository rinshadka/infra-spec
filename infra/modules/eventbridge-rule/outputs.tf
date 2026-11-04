output "rule_arn" {
  description = "Rule ARN; use as the aws:SourceArn for SQS/SNS target policies."
  value       = aws_cloudwatch_event_rule.this.arn
}

output "event_bus_name" {
  description = "Event bus the rule is attached to."
  value       = local.bus_name
}
