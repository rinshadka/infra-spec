data "aws_partition" "current" {}

locals {
  identifier  = "infra-spec-${var.environment}-${var.name}"
  is_aurora   = startswith(var.engine, "aurora-")
  is_postgres = strcontains(var.engine, "postgres")
  port        = local.is_postgres ? 5432 : 3306

  tls_parameter = local.is_postgres ? { "rds.force_ssl" = { value = "1", apply_method = "pending-reboot" } } : { "require_secure_transport" = { value = "ON", apply_method = "immediate" } }

  log_exports = local.is_postgres ? ["postgresql"] : ["audit", "error", "slowquery"]

  instance_parameters = local.is_aurora ? var.parameters : merge(var.parameters, local.tls_parameter)
  cluster_parameters  = merge(var.parameters, local.tls_parameter)
}

resource "aws_db_subnet_group" "this" {
  name       = local.identifier
  subnet_ids = var.subnet_ids

  tags = merge(local.base_tags, {
    Name = local.identifier
  })
}

resource "aws_security_group" "this" {
  name        = local.identifier
  description = "Database access only from declared client security groups."
  vpc_id      = var.vpc_id
  ingress     = []
  egress      = []

  tags = merge(local.base_tags, {
    Name = local.identifier
  })
}

resource "aws_vpc_security_group_ingress_rule" "client" {
  for_each = var.client_security_group_ids

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = local.port
  to_port                      = local.port
  description                  = "Database from declared client"
}

resource "aws_vpc_security_group_egress_rule" "client" {
  for_each = var.client_security_group_ids

  security_group_id            = each.value
  referenced_security_group_id = aws_security_group.this.id
  ip_protocol                  = "tcp"
  from_port                    = local.port
  to_port                      = local.port
  description                  = "Database ${local.identifier}"
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${local.identifier}-"
  family      = var.parameter_group_family
  description = "${local.identifier} instance parameters"

  dynamic "parameter" {
    for_each = local.instance_parameters
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

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "${local.identifier}-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json

  tags = merge(local.base_tags, {
    Name = "${local.identifier}-monitoring"
  })
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "terraform_data" "guardrails" {
  input = local.identifier

  lifecycle {
    precondition {
      condition     = var.environment != "production" || (var.deletion_protection && var.backup_retention_days >= 7)
      error_message = "Production databases require deletion_protection and at least 7 days of backups."
    }
    precondition {
      condition     = var.environment != "production" || (local.is_aurora ? var.aurora_instance_count >= 2 : var.multi_az)
      error_message = "Production databases require Multi-AZ (instance) or at least two Aurora instances."
    }
    precondition {
      condition     = startswith(var.parameter_group_family, var.engine)
      error_message = "parameter_group_family must match the engine (for example postgres17 for postgres)."
    }
  }
}
