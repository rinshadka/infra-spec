resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_route_table" "public" {
  for_each = var.availability_zone_ids

  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
    AZID = each.key
  })
}

resource "aws_route_table" "private_application" {
  for_each = var.availability_zone_ids

  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-application-${each.key}"
    Tier = "application"
    AZID = each.key
  })
}

resource "aws_route_table" "private_data" {
  for_each = var.availability_zone_ids

  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-data-${each.key}"
    Tier = "data"
    AZID = each.key
  })
}

resource "aws_route" "public_to_igw" {
  for_each = aws_route_table.public

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = var.availability_zone_ids

  subnet_id      = aws_subnet.this["${each.key}/public"].id
  route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route_table_association" "private_application" {
  for_each = var.availability_zone_ids

  subnet_id      = aws_subnet.this["${each.key}/application"].id
  route_table_id = aws_route_table.private_application[each.key].id
}

resource "aws_route_table_association" "private_data" {
  for_each = var.availability_zone_ids

  subnet_id      = aws_subnet.this["${each.key}/data"].id
  route_table_id = aws_route_table.private_data[each.key].id
}
