locals {
  base_name  = "infra-spec-${var.environment}-${var.name}"
  suffix     = var.fifo ? ".fifo" : ""
  queue_name = "${local.base_name}${local.suffix}"
  dlq_name   = "${local.base_name}-dlq${local.suffix}"
}

resource "aws_sqs_queue" "dlq" {
  name                              = local.dlq_name
  fifo_queue                        = var.fifo
  message_retention_seconds         = 1209600
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(local.base_tags, {
    Name = local.dlq_name
  })
}

resource "aws_sqs_queue" "this" {
  name                              = local.queue_name
  fifo_queue                        = var.fifo
  content_based_deduplication       = var.fifo ? true : null
  visibility_timeout_seconds        = var.visibility_timeout_seconds
  message_retention_seconds         = var.message_retention_seconds
  receive_wait_time_seconds         = 20
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(local.base_tags, {
    Name = local.queue_name
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}

data "aws_iam_policy_document" "queue" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.this.arn]
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

  dynamic "statement" {
    for_each = var.publisher_service_principals
    content {
      sid       = "Allow${replace(title(replace(split(".", statement.key)[0], "-", " ")), " ", "")}Send"
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.this.arn]
      principals {
        type        = "Service"
        identifiers = [statement.key]
      }
      condition {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = sort(tolist(statement.value))
      }
    }
  }
}

resource "aws_sqs_queue_policy" "this" {
  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.queue.json
}

data "aws_iam_policy_document" "dlq" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.dlq.arn]
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

resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  policy    = data.aws_iam_policy_document.dlq.json
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${local.base_name}-dlq-not-empty"
  alarm_description   = "Messages are waiting in the dead-letter queue; investigate and redrive."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  tags = merge(local.base_tags, {
    Name = "${local.base_name}-dlq-not-empty"
  })
}

resource "aws_cloudwatch_metric_alarm" "oldest_message" {
  alarm_name          = "${local.base_name}-backlog-age"
  alarm_description   = "Oldest message age exceeds ${var.oldest_message_age_alarm_seconds} seconds."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.oldest_message_age_alarm_seconds
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]

  dimensions = {
    QueueName = aws_sqs_queue.this.name
  }

  tags = merge(local.base_tags, {
    Name = "${local.base_name}-backlog-age"
  })
}
