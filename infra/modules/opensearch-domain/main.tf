data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "infra-spec-${var.environment}-${var.domain_name}"
  zone_count  = length(var.subnet_ids)
  domain_arn  = "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:domain/${var.domain_name}"
  log_types   = toset(["INDEX_SLOW_LOGS", "SEARCH_SLOW_LOGS", "ES_APPLICATION_LOGS", "AUDIT_LOGS"])
}

resource "aws_security_group" "this" {
  name        = local.name_prefix
  description = "OpenSearch HTTPS access only from declared clients."
  vpc_id      = var.vpc_id
  ingress     = []
  egress      = []

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}

resource "aws_vpc_security_group_ingress_rule" "client" {
  for_each = var.client_security_group_ids

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from declared OpenSearch client"
}

resource "aws_vpc_security_group_egress_rule" "client" {
  for_each = var.client_security_group_ids

  security_group_id            = each.value
  referenced_security_group_id = aws_security_group.this.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS to ${local.name_prefix}"
}

resource "aws_cloudwatch_log_group" "this" {
  for_each = local.log_types

  name              = "/infra-spec/${var.environment}/opensearch/${var.domain_name}/${lower(each.key)}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-${lower(each.key)}"
  })
}

data "aws_iam_policy_document" "logs" {
  statement {
    actions   = ["logs:PutLogEvents", "logs:CreateLogStream"]
    resources = [for group in aws_cloudwatch_log_group.this : "${group.arn}:*"]
    principals {
      type        = "Service"
      identifiers = ["es.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "this" {
  policy_name     = local.name_prefix
  policy_document = data.aws_iam_policy_document.logs.json
}

data "aws_iam_policy_document" "access" {
  statement {
    actions   = ["es:ESHttp*"]
    resources = ["${local.domain_arn}/*"]
    principals {
      type        = "AWS"
      identifiers = sort(tolist(var.access_principal_arns))
    }
  }
}

resource "aws_opensearch_domain" "this" {
  domain_name     = var.domain_name
  engine_version  = var.engine_version
  access_policies = data.aws_iam_policy_document.access.json

  cluster_config {
    instance_type            = var.instance_type
    instance_count           = var.instance_count
    zone_awareness_enabled   = local.zone_count > 1
    dedicated_master_enabled = var.dedicated_master.enabled
    dedicated_master_type    = var.dedicated_master.enabled ? var.dedicated_master.instance_type : null
    dedicated_master_count   = var.dedicated_master.enabled ? var.dedicated_master.count : null

    dynamic "zone_awareness_config" {
      for_each = local.zone_count > 1 ? [1] : []
      content {
        availability_zone_count = local.zone_count
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.ebs_volume_size_gib
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-PFS-2023-10"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = false
    anonymous_auth_enabled         = false
    master_user_options {
      master_user_arn = var.master_user_role_arn
    }
  }

  software_update_options {
    auto_software_update_enabled = true
  }

  auto_tune_options {
    desired_state       = var.auto_tune_enabled ? "ENABLED" : "DISABLED"
    rollback_on_disable = "NO_ROLLBACK"
  }

  dynamic "log_publishing_options" {
    for_each = local.log_types
    content {
      log_type                 = log_publishing_options.value
      cloudwatch_log_group_arn = aws_cloudwatch_log_group.this[log_publishing_options.value].arn
      enabled                  = true
    }
  }

  lifecycle {
    precondition {
      condition     = local.zone_count == 1 || var.instance_count % local.zone_count == 0
      error_message = "instance_count must be a multiple of the number of subnets (AZs) when zone awareness is enabled."
    }
    precondition {
      condition     = var.environment != "production" || (local.zone_count >= 2 && var.dedicated_master.enabled)
      error_message = "Production domains require at least two AZs and dedicated cluster-manager nodes."
    }
  }

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })

  depends_on = [aws_cloudwatch_log_resource_policy.this]
}

resource "aws_cloudwatch_metric_alarm" "cluster_red" {
  alarm_name          = "${local.name_prefix}-cluster-red"
  alarm_description   = "At least one primary shard is unassigned."
  namespace           = "AWS/ES"
  metric_name         = "ClusterStatus.red"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]

  dimensions = {
    DomainName = var.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-cluster-red"
  })
}

resource "aws_cloudwatch_metric_alarm" "free_storage" {
  alarm_name          = "${local.name_prefix}-free-storage-low"
  alarm_description   = "A data node has less than 25% of its EBS volume free (FreeStorageSpace is in MiB)."
  namespace           = "AWS/ES"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = var.ebs_volume_size_gib * 1024 * 0.25
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]

  dimensions = {
    DomainName = var.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-free-storage-low"
  })
}

resource "aws_cloudwatch_metric_alarm" "jvm_pressure" {
  alarm_name          = "${local.name_prefix}-jvm-pressure-high"
  alarm_description   = "JVM memory pressure at or above 95% for three periods."
  namespace           = "AWS/ES"
  metric_name         = "JVMMemoryPressure"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 95
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]

  dimensions = {
    DomainName = var.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-jvm-pressure-high"
  })
}
