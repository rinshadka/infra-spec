data "aws_iam_policy_document" "consumer_queue_key" {
  source_policy_documents = compact([var.consumer.policy_json])

  statement {
    sid       = "DecryptQueueMessages"
    actions   = ["kms:Decrypt"]
    resources = [var.messaging_kms_key_arn]
  }
}

module "queue" {
  source = "../../../modules/sqs-queue"

  environment                = var.environment
  name                       = var.integration_name
  visibility_timeout_seconds = var.consumer.timeout_seconds * 6
  kms_key_arn                = var.messaging_kms_key_arn
  alarm_topic_arn            = var.alarm_topic_arn
  tags                       = local.tags
  additional_tags            = var.additional_tags
  publisher_service_principals = {
    "events.amazonaws.com" = [module.route.rule_arn]
  }
}

module "consumer" {
  source = "../../../modules/lambda-function"

  environment     = var.environment
  name            = "${var.integration_name}-consumer"
  description     = "Consumes ${var.integration_name} events from SQS"
  runtime         = var.consumer.runtime
  handler         = var.consumer.handler
  timeout_seconds = var.consumer.timeout_seconds
  memory_mb       = var.consumer.memory_mb
  kms_key_arn     = var.log_kms_key_arn
  alarm_topic_arn = var.alarm_topic_arn
  policy_json     = data.aws_iam_policy_document.consumer_queue_key.json
  tags            = local.tags
  additional_tags = var.additional_tags

  package = {
    s3_bucket = var.consumer.s3_bucket
    s3_key    = var.consumer.s3_key
  }

  sqs_event_source = {
    queue_arn           = module.queue.queue_arn
    maximum_concurrency = var.consumer.max_concurrency
  }
}

module "route" {
  source = "../../../modules/eventbridge-rule"

  environment     = var.environment
  name            = var.integration_name
  description     = "Routes ${var.integration_name} events to SQS"
  tags            = local.tags
  additional_tags = var.additional_tags
  event_pattern = jsonencode({
    source      = var.event_sources
    detail-type = var.event_detail_types
  })
  targets = {
    queue = {
      arn  = module.queue.queue_arn
      type = "sqs"
    }
  }
}
