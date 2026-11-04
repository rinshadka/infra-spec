module "sftp" {
  source = "../../../modules/transfer-sftp-server"

  environment                        = var.environment
  name                               = var.server_name
  internet_facing                    = var.internet_facing
  public_exposure_approval_reference = var.public_exposure_approval_reference
  vpc_id                             = var.vpc_id
  subnet_ids                         = var.subnet_ids
  allowed_source_cidrs               = var.allowed_source_cidrs
  log_kms_key_arn                    = var.log_kms_key_arn
  users                              = var.users
  tags                               = local.tags
  additional_tags                    = var.additional_tags
}
