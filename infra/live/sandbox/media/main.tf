module "media" {
  source = "../../../modules/media-pipeline"

  environment          = var.environment
  name                 = var.pipeline_name
  input_bucket_name    = var.input_bucket_name
  output_bucket_name   = var.output_bucket_name
  kms_key_arn          = var.media_kms_key_arn
  submitter_lambda_arn = var.submitter_lambda_arn
  alarm_topic_arn      = var.alarm_topic_arn
  tags                 = local.tags
  additional_tags      = var.additional_tags
}
