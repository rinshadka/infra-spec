resource "aws_eip" "nat" {
  for_each = local.nat_gateway_az_ids

  domain = "vpc"

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-nat-eip-${each.key}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_gateway_az_ids

  allocation_id     = aws_eip.nat[each.key].id
  subnet_id         = aws_subnet.this["${each.key}/public"].id
  connectivity_type = "public"

  depends_on = [aws_internet_gateway.this]

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-nat-${each.key}"
  })
}

locals {
  private_route_az_by_key = {
    for key, subnet in local.subnets : key => (
      var.nat_mode == "shared" ? sort(tolist(var.availability_zone_ids))[0] : subnet.az
    ) if contains(["application", "data"], subnet.tier) && var.nat_mode != "disabled"
  }
}

resource "aws_route" "private_application_to_nat" {
  for_each = {
    for key, az_id in local.private_route_az_by_key : key => az_id
    if local.subnets[key].tier == "application"
  }

  route_table_id         = aws_route_table.private_application[local.subnets[each.key].az].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}

resource "aws_route" "private_data_to_nat" {
  for_each = {
    for key, az_id in local.private_route_az_by_key : key => az_id
    if local.subnets[key].tier == "data"
  }

  route_table_id         = aws_route_table.private_data[local.subnets[each.key].az].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}
