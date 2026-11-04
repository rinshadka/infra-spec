data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  partition   = data.aws_partition.current.partition
  region      = data.aws_region.current.region
  name_prefix = "infra-spec-${var.environment}-${local.region}"
  trail_name  = "${local.name_prefix}-audit"
  trail_arn   = "arn:${local.partition}:cloudtrail:${local.region}:${local.account_id}:trail/${local.trail_name}"
  bucket_name = "infra-spec-${var.environment}-${local.account_id}-${local.region}-audit"

  kms_key_arns = merge(
    { logs = aws_kms_key.logs.arn },
    { for name, key in aws_kms_key.data : name => key.arn }
  )
}
