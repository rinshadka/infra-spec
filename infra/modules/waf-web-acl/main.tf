locals {
  acl_name = "infra-spec-${var.environment}-${var.name}"
}

resource "aws_wafv2_web_acl" "this" {
  name        = local.acl_name
  description = substr(var.justification, 0, 256)
  scope       = var.scope

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = { for index, group in var.managed_rule_groups : group => index }
    content {
      name     = rule.key
      priority = rule.value + 10

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = rule.key
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.rate_limit_per_5_minutes == null ? [] : [1]
    content {
      name     = "rate-limit-per-ip"
      priority = 1

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit_per_5_minutes
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "rate-limit-per-ip"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.acl_name
    sampled_requests_enabled   = true
  }

  tags = merge(local.base_tags, {
    Name = local.acl_name
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "aws-waf-logs-${local.acl_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn

  tags = merge(local.base_tags, {
    Name = "aws-waf-logs-${local.acl_name}"
  })
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.this.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  for_each = var.scope == "REGIONAL" ? var.associated_resource_arns : toset([])

  resource_arn = each.value
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
