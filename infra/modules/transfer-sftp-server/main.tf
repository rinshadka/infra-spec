data "aws_partition" "current" {}

locals {
  name_prefix = "infra-spec-${var.environment}-${var.name}"
  partition   = data.aws_partition.current.partition
}

resource "aws_security_group" "this" {
  name        = local.name_prefix
  description = "SFTP from declared source CIDRs only."
  vpc_id      = var.vpc_id
  ingress     = []
  egress      = []

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}

resource "aws_vpc_security_group_ingress_rule" "sftp" {
  for_each = var.allowed_source_cidrs

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SFTP from declared source"
}

resource "aws_eip" "this" {
  for_each = var.internet_facing ? toset(var.subnet_ids) : toset([])

  domain = "vpc"

  tags = merge(local.base_tags, {
    Name              = "${local.name_prefix}-${each.key}"
    ApprovalReference = var.public_exposure_approval_reference
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/transfer/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}

data "aws_iam_policy_document" "transfer_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "logging" {
  name               = "${local.name_prefix}-logging"
  assume_role_policy = data.aws_iam_policy_document.transfer_assume.json

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-logging"
  })
}

resource "aws_iam_role_policy_attachment" "logging" {
  role       = aws_iam_role.logging.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWSTransferLoggingAccess"
}

resource "aws_transfer_server" "this" {
  endpoint_type          = "VPC"
  protocols              = ["SFTP"]
  identity_provider_type = "SERVICE_MANAGED"
  domain                 = "S3"
  security_policy_name   = var.security_policy_name
  logging_role           = aws_iam_role.logging.arn
  structured_log_destinations = [
    "${aws_cloudwatch_log_group.this.arn}:*"
  ]

  endpoint_details {
    vpc_id                 = var.vpc_id
    subnet_ids             = var.subnet_ids
    security_group_ids     = [aws_security_group.this.id]
    address_allocation_ids = var.internet_facing ? [for subnet in var.subnet_ids : aws_eip.this[subnet].id] : null
  }

  lifecycle {
    precondition {
      condition     = !var.internet_facing || try(length(trimspace(var.public_exposure_approval_reference)) > 0, false)
      error_message = "Internet-facing SFTP endpoints require public_exposure_approval_reference."
    }
  }

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}

data "aws_iam_policy_document" "user" {
  for_each = var.users

  statement {
    sid       = "ListHomePrefix"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${local.partition}:s3:::${each.value.bucket_name}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${each.value.home_prefix}/*", each.value.home_prefix]
    }
  }

  statement {
    sid = "HomePrefixObjects"
    actions = each.value.read_only ? ["s3:GetObject", "s3:GetObjectVersion"] : [
      "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion",
    ]
    resources = ["arn:${local.partition}:s3:::${each.value.bucket_name}/${each.value.home_prefix}/*"]
  }

  statement {
    sid       = "UseBucketKey"
    actions   = each.value.read_only ? ["kms:Decrypt"] : ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [each.value.kms_key_arn]
  }
}

resource "aws_iam_role" "user" {
  for_each = var.users

  name               = substr("${local.name_prefix}-${replace(each.key, "/[^a-zA-Z0-9+=,.@_-]/", "-")}", 0, 64)
  assume_role_policy = data.aws_iam_policy_document.transfer_assume.json

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-${each.key}"
  })
}

resource "aws_iam_role_policy" "user" {
  for_each = var.users

  name   = "home-prefix"
  role   = aws_iam_role.user[each.key].id
  policy = data.aws_iam_policy_document.user[each.key].json
}

resource "aws_transfer_user" "this" {
  for_each = var.users

  server_id           = aws_transfer_server.this.id
  user_name           = each.key
  role                = aws_iam_role.user[each.key].arn
  home_directory_type = "LOGICAL"

  home_directory_mappings {
    entry  = "/"
    target = "/${each.value.bucket_name}/${each.value.home_prefix}"
  }

  tags = merge(local.base_tags, {
    Name = each.key
  })
}

resource "aws_transfer_ssh_key" "this" {
  for_each = merge([
    for username, u in var.users : {
      for index, key in u.ssh_public_keys : "${username}/${index}" => { username = username, body = key }
    }
  ]...)

  server_id = aws_transfer_server.this.id
  user_name = aws_transfer_user.this[each.value.username].user_name
  body      = each.value.body
}
