resource "aws_cloudtrail" "audit" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.audit.id
  s3_key_prefix                 = "cloudtrail"
  kms_key_id                    = aws_kms_key.logs.arn
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = merge(local.base_tags, {
    Name            = local.trail_name
    OperationsOwner = var.operations_owner
  })

  depends_on = [aws_s3_bucket_policy.audit]
}
