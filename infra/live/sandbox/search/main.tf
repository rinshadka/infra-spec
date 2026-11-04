module "search" {
  source = "../../../modules/opensearch-domain"

  environment               = var.environment
  domain_name               = var.domain_name
  engine_version            = var.engine_version
  instance_type             = var.instance_type
  instance_count            = var.instance_count
  ebs_volume_size_gib       = var.ebs_volume_size_gib
  vpc_id                    = var.vpc_id
  subnet_ids                = var.data_subnet_ids
  client_security_group_ids = var.client_security_group_ids
  kms_key_arn               = var.search_kms_key_arn
  log_kms_key_arn           = var.log_kms_key_arn
  master_user_role_arn      = var.master_user_role_arn
  access_principal_arns     = var.access_principal_arns
  alarm_topic_arn           = var.alarm_topic_arn
  tags                      = local.tags
  additional_tags           = var.additional_tags
}
