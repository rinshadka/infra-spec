data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  name_prefix = "infra-spec-${var.environment}-${var.name}"
  instance_tags = merge(local.base_tags, { Name = local.name_prefix },
  var.backup_plan_tag == null ? {} : { BackupPolicy = var.backup_plan_tag })
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = local.name_prefix
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "application" {
  count = var.iam_policy_json == null ? 0 : 1

  name   = "application"
  role   = aws_iam_role.this.id
  policy = var.iam_policy_json
}

resource "aws_iam_instance_profile" "this" {
  name = local.name_prefix
  role = aws_iam_role.this.name

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}

resource "aws_security_group" "this" {
  name        = local.name_prefix
  description = "Default-deny instance security group; rules are declared explicitly."
  vpc_id      = var.vpc_id
  ingress     = []
  egress      = []

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for r in var.ingress_rules : r.name => r }

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value.source_security_group_id
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  description                  = each.value.description
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = { for r in var.egress_rules : r.name => r }

  security_group_id            = aws_security_group.this.id
  cidr_ipv4                    = each.value.destination_cidr
  prefix_list_id               = each.value.destination_prefix_list_id
  referenced_security_group_id = each.value.destination_security_group_id
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  description                  = each.value.description
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = false
  disable_api_termination     = var.termination_protection
  monitoring                  = true
  ebs_optimized               = true
  user_data                   = var.user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gib
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
    tags                  = local.instance_tags
  }

  maintenance_options {
    auto_recovery = "default"
  }

  tags = local.instance_tags
}

resource "aws_ebs_volume" "data" {
  for_each = var.data_volumes

  availability_zone = aws_instance.this.availability_zone
  size              = each.value.size_gib
  type              = "gp3"
  iops              = each.value.iops
  encrypted         = true
  kms_key_id        = var.kms_key_arn

  tags = merge(local.instance_tags, {
    Name   = "${local.name_prefix}-${replace(each.key, "/", "-")}"
    Device = each.key
  })
}

resource "aws_volume_attachment" "data" {
  for_each = var.data_volumes

  device_name = each.key
  volume_id   = aws_ebs_volume.data[each.key].id
  instance_id = aws_instance.this.id
}

resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "${local.name_prefix}-status-check-failed"
  alarm_description   = "Instance or system status check failed for two consecutive minutes."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]

  dimensions = {
    InstanceId = aws_instance.this.id
  }

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-status-check-failed"
  })
}

resource "aws_cloudwatch_metric_alarm" "system_recover" {
  alarm_name          = "${local.name_prefix}-system-recover"
  alarm_description   = "Recover the instance onto healthy hardware after system status check failures."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  alarm_actions       = ["arn:${data.aws_partition.current.partition}:automate:${data.aws_region.current.region}:ec2:recover", var.alarm_topic_arn]

  dimensions = {
    InstanceId = aws_instance.this.id
  }

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-system-recover"
  })
}
