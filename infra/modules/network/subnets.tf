resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id               = aws_vpc.this.id
  availability_zone_id = each.value.az
  cidr_block           = each.value.cidr

  map_public_ip_on_launch = false

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-${each.value.tier}-${each.value.az}"
    Tier = each.value.tier
  })
}
