resource "aws_db_instance" "this" {
  count = local.is_aurora ? 0 : 1

  identifier                            = local.identifier
  engine                                = var.engine
  engine_version                        = var.engine_version
  instance_class                        = var.instance_class
  allocated_storage                     = var.allocated_storage_gib
  max_allocated_storage                 = var.max_allocated_storage_gib
  storage_type                          = "gp3"
  storage_encrypted                     = true
  kms_key_id                            = var.kms_key_arn
  db_name                               = var.database_name
  username                              = var.master_username
  manage_master_user_password           = true
  master_user_secret_kms_key_id         = var.kms_key_arn
  port                                  = local.port
  multi_az                              = var.multi_az
  db_subnet_group_name                  = aws_db_subnet_group.this.name
  vpc_security_group_ids                = [aws_security_group.this.id]
  parameter_group_name                  = aws_db_parameter_group.this.name
  publicly_accessible                   = false
  iam_database_authentication_enabled   = true
  backup_retention_period               = var.backup_retention_days
  backup_window                         = var.backup_window
  maintenance_window                    = var.maintenance_window
  auto_minor_version_upgrade            = true
  allow_major_version_upgrade           = false
  copy_tags_to_snapshot                 = true
  deletion_protection                   = var.deletion_protection
  skip_final_snapshot                   = false
  final_snapshot_identifier             = "${local.identifier}-final"
  delete_automated_backups              = false
  enabled_cloudwatch_logs_exports       = local.log_exports
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.monitoring.arn

  tags = merge(local.base_tags, {
    Name = local.identifier
  })

  depends_on = [terraform_data.guardrails]
}
