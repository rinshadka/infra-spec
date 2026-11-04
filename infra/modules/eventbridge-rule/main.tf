locals {
  rule_name = "infra-spec-${var.environment}-${var.name}"
  bus_name  = var.create_event_bus ? aws_cloudwatch_event_bus.this[0].name : var.event_bus_name
}

resource "aws_cloudwatch_event_bus" "this" {
  count = var.create_event_bus ? 1 : 0

  name = local.rule_name

  tags = merge(local.base_tags, {
    Name = local.rule_name
  })
}

resource "aws_cloudwatch_event_rule" "this" {
  name           = local.rule_name
  description    = var.description
  event_bus_name = local.bus_name
  event_pattern  = var.event_pattern
  state          = "ENABLED"

  tags = merge(local.base_tags, {
    Name = local.rule_name
  })
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = var.targets

  rule           = aws_cloudwatch_event_rule.this.name
  event_bus_name = local.bus_name
  target_id      = each.key
  arn            = each.value.arn

  retry_policy {
    maximum_retry_attempts       = each.value.maximum_retry_attempts
    maximum_event_age_in_seconds = each.value.maximum_event_age_sec
  }

  dynamic "dead_letter_config" {
    for_each = each.value.dead_letter_queue_arn == null ? [] : [1]
    content {
      arn = each.value.dead_letter_queue_arn
    }
  }
}

resource "aws_lambda_permission" "this" {
  for_each = { for id, t in var.targets : id => t if t.type == "lambda" }

  statement_id  = "AllowEventBridge-${local.rule_name}-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}
