data "aws_partition" "current" {}

locals {
  function_name  = "infra-spec-${var.environment}-${var.name}"
  partition      = data.aws_partition.current.partition
  failure_is_sqs = var.async_failure_destination_arn != null && try(strcontains(var.async_failure_destination_arn, ":sqs:"), false)
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(local.base_tags, {
    Name = local.function_name
  })
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = local.function_name
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(local.base_tags, {
    Name = local.function_name
  })
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(concat(
    [var.vpc_config == null ? "service-role/AWSLambdaBasicExecutionRole" : "service-role/AWSLambdaVPCAccessExecutionRole"],
    ["AWSXRayDaemonWriteAccess"],
  ))

  role       = aws_iam_role.this.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/${each.value}"
}

data "aws_iam_policy_document" "integration" {
  statement {
    sid       = "DecryptEnvironment"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }

  dynamic "statement" {
    for_each = var.sqs_event_source == null ? [] : [1]
    content {
      sid       = "ConsumeSourceQueue"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
      resources = [var.sqs_event_source.queue_arn]
    }
  }

  dynamic "statement" {
    for_each = var.async_failure_destination_arn == null ? [] : [1]
    content {
      sid       = "SendFailures"
      actions   = local.failure_is_sqs ? ["sqs:SendMessage"] : ["sns:Publish"]
      resources = [var.async_failure_destination_arn]
    }
  }
}

resource "aws_iam_role_policy" "integration" {
  name   = "integration"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.integration.json
}

resource "aws_iam_role_policy" "application" {
  count = var.policy_json == null ? 0 : 1

  name   = "application"
  role   = aws_iam_role.this.id
  policy = var.policy_json
}

resource "aws_lambda_function" "this" {
  function_name                  = local.function_name
  description                    = var.description
  role                           = aws_iam_role.this.arn
  runtime                        = var.runtime
  handler                        = var.handler
  architectures                  = [var.architecture]
  memory_size                    = var.memory_mb
  timeout                        = var.timeout_seconds
  reserved_concurrent_executions = var.reserved_concurrency
  kms_key_arn                    = var.kms_key_arn
  s3_bucket                      = var.package.s3_bucket
  s3_key                         = var.package.s3_key
  s3_object_version              = var.package.s3_object_version
  filename                       = var.package.filename
  source_code_hash               = var.package.source_code_hash

  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.this.name
  }

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config == null ? [] : [var.vpc_config]
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = merge(local.base_tags, {
    Name = local.function_name
  })

  depends_on = [aws_iam_role_policy_attachment.managed, aws_iam_role_policy.integration]
}

resource "aws_lambda_function_event_invoke_config" "this" {
  count = var.async_failure_destination_arn == null ? 0 : 1

  function_name                = aws_lambda_function.this.function_name
  maximum_retry_attempts       = 2
  maximum_event_age_in_seconds = 3600

  destination_config {
    on_failure {
      destination = var.async_failure_destination_arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs" {
  count = var.sqs_event_source == null ? 0 : 1

  event_source_arn                   = var.sqs_event_source.queue_arn
  function_name                      = aws_lambda_function.this.arn
  batch_size                         = var.sqs_event_source.batch_size
  maximum_batching_window_in_seconds = var.sqs_event_source.maximum_batching_window_sec
  function_response_types            = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = var.sqs_event_source.maximum_concurrency
  }

  tags = merge(local.base_tags, {
    Name = "${local.function_name}-sqs"
  })
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${local.function_name}-errors"
  alarm_description   = "Function errors in two consecutive five-minute periods."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  tags = merge(local.base_tags, {
    Name = "${local.function_name}-errors"
  })
}

resource "aws_cloudwatch_metric_alarm" "throttles" {
  alarm_name          = "${local.function_name}-throttles"
  alarm_description   = "Function invocations were throttled."
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  tags = merge(local.base_tags, {
    Name = "${local.function_name}-throttles"
  })
}
