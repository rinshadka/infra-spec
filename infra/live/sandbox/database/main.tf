module "database" {
  source = "../../../modules/relational-database"

  environment               = var.environment
  name                      = var.database_name
  engine                    = var.engine
  engine_version            = var.engine_version
  parameter_group_family    = var.parameter_group_family
  instance_class            = var.instance_class
  multi_az                  = var.multi_az
  aurora_instance_count     = var.aurora_instance_count
  backup_retention_days     = var.backup_retention_days
  vpc_id                    = var.vpc_id
  subnet_ids                = var.data_subnet_ids
  client_security_group_ids = var.client_security_group_ids
  kms_key_arn               = var.database_kms_key_arn
  alarm_topic_arn           = var.alarm_topic_arn
  tags                      = local.tags
  additional_tags           = var.additional_tags
}
