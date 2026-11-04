module "bucket" {
  source   = "../../../modules/s3-bucket"
  for_each = var.buckets

  environment                  = var.environment
  bucket_name                  = each.value.bucket_name
  kms_key_arn                  = var.kms_key_arn
  data_classification          = each.value.data_classification
  access_log_bucket_name       = var.access_log_bucket_name
  lifecycle_rules              = each.value.lifecycle_rules
  eventbridge_notifications    = each.value.eventbridge_notifications
  cloudfront_distribution_arns = each.value.cloudfront_distribution_arns
  tags                         = local.tags
  additional_tags              = var.additional_tags
}

module "file_system" {
  source   = "../../../modules/efs-file-system"
  for_each = var.file_systems

  environment               = var.environment
  name                      = each.key
  vpc_id                    = var.vpc_id
  subnet_ids                = var.data_subnet_ids
  client_security_group_ids = each.value.client_security_group_ids
  kms_key_arn               = var.kms_key_arn
  throughput_mode           = each.value.throughput_mode
  access_points             = each.value.access_points
  tags                      = local.tags
  additional_tags           = var.additional_tags
}
