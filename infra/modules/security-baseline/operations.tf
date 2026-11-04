resource "aws_sns_topic" "operations" {
  name              = "${local.name_prefix}-operations"
  kms_master_key_id = aws_kms_key.logs.arn

  tags = merge(local.base_tags, {
    Name            = "${local.name_prefix}-operations"
    OperationsOwner = var.operations_owner
  })
}

data "aws_iam_policy_document" "operations_topic" {
  statement {
    sid       = "AccountServicesPublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.operations.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "events.amazonaws.com", "config.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.operations.arn]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sns_topic_policy" "operations" {
  arn    = aws_sns_topic.operations.arn
  policy = data.aws_iam_policy_document.operations_topic.json
}

resource "aws_secretsmanager_secret" "this" {
  for_each = var.secret_containers

  name                    = "infra-spec/${var.environment}/${each.key}"
  description             = each.value.description
  kms_key_id              = local.kms_key_arns[each.value.kms_key]
  recovery_window_in_days = each.value.recovery_window_in_days

  tags = merge(local.base_tags, {
    Name = "infra-spec/${var.environment}/${each.key}"
  })

  lifecycle {
    precondition {
      condition     = contains(keys(local.kms_key_arns), each.value.kms_key)
      error_message = "Each secret kms_key must be logs or a declared data_kms_keys name."
    }
  }
}
