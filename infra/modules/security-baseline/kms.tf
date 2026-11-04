data "aws_iam_policy_document" "logs_key" {
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid       = "AuditServicesEncrypt"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com", "config.amazonaws.com", "cloudwatch.amazonaws.com", "events.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }

  statement {
    sid       = "CloudWatchLogsEncrypt"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "logs" {
  description             = "${local.name_prefix} audit, log, and alarm encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.logs_key.json

  tags = merge(local.base_tags, {
    Name    = "${local.name_prefix}-logs"
    Purpose = "logs"
  })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${local.name_prefix}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

data "aws_iam_policy_document" "data_key" {
  for_each = var.data_kms_keys

  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = length(each.value.service_principals) > 0 ? [1] : []
    content {
      sid       = "DeclaredServiceUse"
      actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"]
      resources = ["*"]
      principals {
        type        = "Service"
        identifiers = sort(tolist(each.value.service_principals))
      }
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [local.account_id]
      }
    }
  }
}

resource "aws_kms_key" "data" {
  for_each = var.data_kms_keys

  description             = "${local.name_prefix} ${each.key}: ${each.value.description}"
  enable_key_rotation     = true
  deletion_window_in_days = each.value.deletion_window_in_days
  policy                  = data.aws_iam_policy_document.data_key[each.key].json

  tags = merge(local.base_tags, {
    Name    = "${local.name_prefix}-${each.key}"
    Purpose = each.key
  })
}

resource "aws_kms_alias" "data" {
  for_each = var.data_kms_keys

  name          = "alias/${local.name_prefix}-${each.key}"
  target_key_id = aws_kms_key.data[each.key].key_id
}
