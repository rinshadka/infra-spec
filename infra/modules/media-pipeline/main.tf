data "aws_partition" "current" {}

locals {
  name_prefix      = "infra-spec-${var.environment}-${var.name}"
  partition        = data.aws_partition.current.partition
  status_rule_name = "${var.name}-job-status"
}

module "input_bucket" {
  source = "../s3-bucket"

  environment               = var.environment
  tags                      = var.tags
  additional_tags           = var.additional_tags
  bucket_name               = var.input_bucket_name
  kms_key_arn               = var.kms_key_arn
  data_classification       = "confidential"
  eventbridge_notifications = true
  lifecycle_rules = [{
    id                                 = "source-media-expiry"
    expiration_days                    = var.input_expiration_days
    noncurrent_version_expiration_days = 7
  }]
}

module "output_bucket" {
  source = "../s3-bucket"

  environment         = var.environment
  tags                = var.tags
  additional_tags     = var.additional_tags
  bucket_name         = var.output_bucket_name
  kms_key_arn         = var.kms_key_arn
  data_classification = "confidential"
  lifecycle_rules = [{
    id              = "renditions-tiering"
    transition_days = var.output_transition_days
  }]
}

resource "aws_media_convert_queue" "this" {
  name         = local.name_prefix
  description  = "${local.name_prefix} on-demand transcoding queue"
  pricing_plan = var.queue_pricing_plan
  status       = "ACTIVE"

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}

data "aws_iam_policy_document" "mediaconvert_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["mediaconvert.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mediaconvert" {
  name               = "${local.name_prefix}-mediaconvert"
  assume_role_policy = data.aws_iam_policy_document.mediaconvert_assume.json

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-mediaconvert"
  })
}

data "aws_iam_policy_document" "mediaconvert" {
  statement {
    sid       = "ReadSource"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${module.input_bucket.bucket_arn}/*"]
  }

  statement {
    sid       = "WriteRenditions"
    actions   = ["s3:PutObject"]
    resources = ["${module.output_bucket.bucket_arn}/*"]
  }

  statement {
    sid       = "UseMediaKey"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "mediaconvert" {
  name   = "media-buckets"
  role   = aws_iam_role.mediaconvert.id
  policy = data.aws_iam_policy_document.mediaconvert.json
}

module "status_queue" {
  source = "../sqs-queue"

  environment     = var.environment
  tags            = var.tags
  additional_tags = var.additional_tags
  name            = "${var.name}-job-status"
  kms_key_arn     = var.kms_key_arn
  alarm_topic_arn = var.alarm_topic_arn
  publisher_service_principals = {
    "events.amazonaws.com" = [module.status_rule.rule_arn]
  }
}

module "status_rule" {
  source = "../eventbridge-rule"

  environment     = var.environment
  tags            = var.tags
  additional_tags = var.additional_tags
  name            = local.status_rule_name
  description     = "MediaConvert job state changes for ${local.name_prefix}"
  event_pattern = jsonencode({
    source      = ["aws.mediaconvert"]
    detail-type = ["MediaConvert Job State Change"]
    detail = {
      queue  = [aws_media_convert_queue.this.arn]
      status = ["COMPLETE", "ERROR", "CANCELED"]
    }
  })
  targets = {
    status-queue = {
      arn  = module.status_queue.queue_arn
      type = "sqs"
    }
  }
}

module "submit_rule" {
  source = "../eventbridge-rule"
  count  = var.submitter_lambda_arn == null ? 0 : 1

  environment     = var.environment
  tags            = var.tags
  additional_tags = var.additional_tags
  name            = "${var.name}-submit"
  description     = "Source media arrivals for ${local.name_prefix}"
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [module.input_bucket.bucket_id] }
      object = { key = [for suffix in var.input_suffixes : { suffix = suffix }] }
    }
  })
  targets = {
    submitter = {
      arn  = var.submitter_lambda_arn
      type = "lambda"
    }
  }
}
