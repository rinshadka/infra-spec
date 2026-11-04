data "aws_region" "current" {}

locals {
  name_prefix = "infra-spec-${var.environment}-${data.aws_region.current.region}-${var.name}"
}

resource "aws_efs_file_system" "this" {
  encrypted                       = true
  kms_key_id                      = var.kms_key_arn
  performance_mode                = var.performance_mode
  throughput_mode                 = var.throughput_mode
  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_in_mibps : null

  dynamic "lifecycle_policy" {
    for_each = var.transition_to_ia == null ? [] : [1]
    content {
      transition_to_ia = var.transition_to_ia
    }
  }

  lifecycle {
    precondition {
      condition     = var.throughput_mode != "provisioned" || var.provisioned_throughput_in_mibps != null
      error_message = "provisioned_throughput_in_mibps is required when throughput_mode is provisioned."
    }
  }

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  backup_policy {
    status = var.backup_enabled ? "ENABLED" : "DISABLED"
  }
}

resource "aws_security_group" "this" {
  name        = local.name_prefix
  description = "EFS mount targets; NFS only from declared client security groups."
  vpc_id      = var.vpc_id
  ingress     = []
  egress      = []

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}

resource "aws_vpc_security_group_ingress_rule" "nfs" {
  for_each = var.client_security_group_ids

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "NFS from declared EFS client"
}

# Paired client egress so default-deny client groups can reach only this file system.
resource "aws_vpc_security_group_egress_rule" "client_nfs" {
  for_each = var.client_security_group_ids

  security_group_id            = each.value
  referenced_security_group_id = aws_security_group.this.id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "NFS to ${local.name_prefix}"
}

resource "aws_efs_mount_target" "this" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.this.id]
}

resource "aws_efs_access_point" "this" {
  for_each = var.access_points

  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = each.value.uid
    gid = each.value.gid
  }

  root_directory {
    path = each.value.path
    creation_info {
      owner_uid   = each.value.uid
      owner_gid   = each.value.gid
      permissions = each.value.permissions
    }
  }

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-${each.key}"
  })
}

data "aws_iam_policy_document" "file_system" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["*"]
    resources = [aws_efs_file_system.this.arn]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "DenyAnonymousAccess"
    effect    = "Deny"
    actions   = ["elasticfilesystem:ClientMount"]
    resources = [aws_efs_file_system.this.arn]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "elasticfilesystem:AccessedViaMountTarget"
      values   = ["false"]
    }
  }
}

resource "aws_efs_file_system_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  policy         = data.aws_iam_policy_document.file_system.json
}
