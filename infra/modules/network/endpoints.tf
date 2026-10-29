locals {
  interface_endpoint_flows = flatten([
    for endpoint_name, endpoint in local.endpoint_configs : [
      for tier in endpoint.workload_tiers : {
        key           = "${endpoint_name}/${tier}"
        endpoint_name = endpoint_name
        tier          = tier
      }
    ] if endpoint.type == "interface"
  ])

  gateway_endpoint_flows = flatten([
    for endpoint_name, endpoint in local.endpoint_configs : [
      for tier in endpoint.workload_tiers : {
        key           = "${endpoint_name}/${tier}"
        endpoint_name = endpoint_name
        tier          = tier
      }
    ] if endpoint.type == "gateway"
  ])
}

resource "aws_security_group" "endpoint_interface" {
  for_each = {
    for name, endpoint in local.endpoint_configs : name => endpoint
    if endpoint.type == "interface"
  }

  name        = "${local.name_prefix}-vpce-${each.key}"
  description = "HTTPS ingress only from explicitly declared workload tiers for ${each.value.service_name}."
  vpc_id      = aws_vpc.this.id
  ingress     = []
  egress      = []

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-vpce-${each.key}"
  })
}

resource "aws_vpc_endpoint" "this" {
  for_each = local.endpoint_configs

  vpc_id            = aws_vpc.this.id
  service_name      = each.value.service_name
  vpc_endpoint_type = each.value.aws_type
  subnet_ids = each.value.type == "interface" ? flatten([
    for az_id in sort(tolist(var.availability_zone_ids)) : [
      for tier in sort(tolist(each.value.subnet_tiers)) : aws_subnet.this["${az_id}/${tier}"].id
    ]
  ]) : null
  route_table_ids = each.value.type == "gateway" ? flatten([
    for tier in sort(tolist(each.value.route_table_tiers)) : [
      for az_id in sort(tolist(var.availability_zone_ids)) : local.route_tables_by_tier[tier][az_id].id
    ]
  ]) : null
  security_group_ids  = each.value.type == "interface" ? [aws_security_group.endpoint_interface[each.key].id] : null
  private_dns_enabled = each.value.type == "interface"
  policy              = each.value.policy_json

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-vpce-${each.key}"
  })
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_interface" {
  for_each = { for flow in local.interface_endpoint_flows : flow.key => flow }

  security_group_id            = aws_security_group.endpoint_interface[each.value.endpoint_name].id
  referenced_security_group_id = aws_security_group.workload[each.value.tier].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from explicitly declared ${each.value.tier} workloads."
  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-vpce-${each.value.endpoint_name}-${each.value.tier}-ingress"
  })
}

resource "aws_vpc_security_group_egress_rule" "endpoint_interface" {
  for_each = { for flow in local.interface_endpoint_flows : flow.key => flow }

  security_group_id            = aws_security_group.workload[each.value.tier].id
  referenced_security_group_id = aws_security_group.endpoint_interface[each.value.endpoint_name].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS to declared ${each.value.endpoint_name} VPC endpoint."
  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-vpce-${each.value.endpoint_name}-${each.value.tier}-egress"
  })
}

resource "aws_vpc_security_group_egress_rule" "endpoint_gateway" {
  for_each = { for flow in local.gateway_endpoint_flows : flow.key => flow }

  security_group_id = aws_security_group.workload[each.value.tier].id
  prefix_list_id    = aws_vpc_endpoint.this[each.value.endpoint_name].prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to declared ${each.value.endpoint_name} gateway endpoint."
  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-vpce-${each.value.endpoint_name}-${each.value.tier}-egress"
  })
}
