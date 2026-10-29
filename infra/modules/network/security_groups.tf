locals {
  security_group_tiers = toset(["load_balancer", "application", "data"])

  tier_flows = {
    for flow in var.allowed_flows : flow.name => flow
  }

  public_lb_rules = {
    for entry in flatten([
      for rule in var.public_lb_ingress : [
        for cidr in rule.source_cidr_blocks : {
          key  = "${rule.name}/${cidr}"
          rule = rule
          cidr = cidr
        }
      ]
    ]) : entry.key => entry
  }

  explicit_egress_rules = flatten([
    for rule in var.allowed_egress : concat(
      [for cidr in rule.destination_cidr_blocks : {
        key         = "${rule.name}/cidr/${replace(cidr, "/", "-")}"
        rule        = rule
        cidr        = cidr
        prefix_list = null
      }],
      [for prefix_list_id in rule.prefix_list_ids : {
        key         = "${rule.name}/prefix/${prefix_list_id}"
        rule        = rule
        cidr        = null
        prefix_list = prefix_list_id
      }]
    )
  ])
}

resource "aws_security_group" "workload" {
  for_each = local.security_group_tiers

  name        = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  description = "Default-deny security group for the ${replace(each.key, "_", " ")} tier."
  vpc_id      = aws_vpc.this.id
  ingress     = []
  egress      = []

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  })
}

resource "aws_vpc_security_group_ingress_rule" "tier_flow" {
  for_each = local.tier_flows

  security_group_id            = aws_security_group.workload[each.value.destination_tier].id
  referenced_security_group_id = aws_security_group.workload[each.value.source_tier].id
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  description                  = each.value.description
  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-flow-${each.key}-ingress"
  })
}

resource "aws_vpc_security_group_ingress_rule" "public_load_balancer" {
  for_each = local.public_lb_rules

  security_group_id = aws_security_group.workload["load_balancer"].id
  cidr_ipv4         = each.value.cidr
  ip_protocol       = each.value.rule.protocol
  from_port         = each.value.rule.from_port
  to_port           = each.value.rule.to_port
  description       = each.value.rule.description
  tags = merge(local.base_tags, {
    Name               = "${local.name_prefix}-public-ingress-${each.value.rule.name}-${replace(each.value.cidr, "/", "-")}"
    ApprovalReference = each.value.rule.approval_reference
  })
}

resource "aws_vpc_security_group_egress_rule" "tier_flow" {
  for_each = local.tier_flows

  security_group_id            = aws_security_group.workload[each.value.source_tier].id
  referenced_security_group_id = aws_security_group.workload[each.value.destination_tier].id
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  description                  = each.value.description
  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-flow-${each.key}-egress"
  })
}

resource "aws_vpc_security_group_egress_rule" "explicit_destination" {
  for_each = { for rule in local.explicit_egress_rules : rule.key => rule }

  security_group_id = aws_security_group.workload[each.value.rule.source_tier].id
  cidr_ipv4         = each.value.cidr
  prefix_list_id    = each.value.prefix_list
  ip_protocol       = each.value.rule.protocol
  from_port         = each.value.rule.from_port
  to_port           = each.value.rule.to_port
  description       = each.value.rule.description
  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-egress-${each.value.rule.name}-${replace(each.key, "/", "-")}"
  })
}
