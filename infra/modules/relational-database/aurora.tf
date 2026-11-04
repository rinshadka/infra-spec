resource "aws_rds_cluster_parameter_group" "this" {
  count = local.is_aurora ? 1 : 0

  name_prefix = "${local.identifier}-"
  family      = var.parameter_group_family
  description = "${local.identifier} cluster parameters"

  dynamic "parameter" {
    for_each = local.cluster_parameters
    content {
      name         = parameter.key
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.base_tags, {
    Name = local.identifier
  })
}

resource "aws_rds_cluster" "this" {
  count = local.is_aurora ? 1 : 0

  cluster_identifier                  = local.identifier
  engine                              = var.engine
  engine_version                      = var.engine_version
  database_name                       = var.database_name
  master_username                     = var.master_username
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = var.kms_key_arn
  port                                = local.port
  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = [aws_security_group.this.id]
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.this[0].name
  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  iam_database_authentication_enabled = true
  backup_retention_period             = var.backup_retention_days
  preferred_backup_window             = var.backup_window
  preferred_maintenance_window        = var.maintenance_window
  copy_tags_to_snapshot               = true
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "${local.identifier}-final"
  allow_major_version_upgrade         = false
  enabled_cloudwatch_logs_exports     = local.log_exports

  tags = merge(local.base_tags, {
    Name = local.identifier
  })

  depends_on = [terraform_data.guardrails]
}

resource "aws_rds_cluster_instance" "this" {
  count = local.is_aurora ? var.aurora_instance_count : 0

  identifier                            = "${local.identifier}-${count.index + 1}"
  cluster_identifier                    = aws_rds_cluster.this[0].id
  engine                                = var.engine
  engine_version                        = var.engine_version
  instance_class                        = var.instance_class
  db_subnet_group_name                  = aws_db_subnet_group.this.name
  db_parameter_group_name               = aws_db_parameter_group.this.name
  publicly_accessible                   = false
  auto_minor_version_upgrade            = true
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.monitoring.arn
  copy_tags_to_snapshot                 = true

  tags = merge(local.base_tags, {
    Name = "${local.identifier}-${count.index + 1}"
  })
}
