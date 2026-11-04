module "security_baseline" {
  source = "../../../modules/security-baseline"

  environment              = var.environment
  operations_owner         = var.operations_owner
  data_kms_keys            = var.data_kms_keys
  audit_log_retention_days = var.audit_log_retention_days
  enable_cloudtrail        = var.enable_cloudtrail
  enable_config            = var.enable_config
  enable_security_hub      = var.enable_security_hub
  secret_containers        = var.secret_containers
  tags                     = local.tags
  additional_tags          = var.additional_tags
}
