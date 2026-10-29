locals {
  name_prefix = "infra-spec-${var.environment}-${data.aws_region.current.name}"

  base_tags = merge(var.additional_tags, var.tags)

  vpc_cidr_parts = split("/", var.vpc_cidr_block)
  vpc_cidr_ip    = try(cidrhost(var.vpc_cidr_block, 0), "0.0.0.0")
  vpc_cidr_octets = [
    for octet in split(".", local.vpc_cidr_ip) : try(parseint(octet, 10), 0)
  ]
  vpc_cidr_range = {
    prefix_length = try(tonumber(local.vpc_cidr_parts[1]), 32)
    start = sum([
      for index, octet in local.vpc_cidr_octets : octet * pow(256, 3 - index)
    ])
    end = sum([
      for index, octet in local.vpc_cidr_octets : octet * pow(256, 3 - index)
    ]) + pow(2, 32 - try(tonumber(local.vpc_cidr_parts[1]), 32)) - 1
  }

  subnet_cidr_entries = flatten([
    for az_id, tiers in var.subnet_cidrs_by_az : [
      for tier, cidr in tiers : {
        key  = "${az_id}/${tier}"
        tier = tier
        az   = az_id
        cidr = cidr
      }
    ]
  ])

  subnet_cidr_ranges = [
    for subnet in local.subnet_cidr_entries : {
      key           = subnet.key
      tier          = subnet.tier
      az            = subnet.az
      valid_ipv4    = try(can(cidrnetmask(subnet.cidr)), false)
      canonical     = try(cidrhost(subnet.cidr, 0) == split("/", subnet.cidr)[0], false)
      prefix_length = try(tonumber(split("/", subnet.cidr)[1]), 32)
      start = sum([
        for index, octet in [
          for part in split(".", try(cidrhost(subnet.cidr, 0), "0.0.0.0")) : try(parseint(part, 10), 0)
        ] : octet * pow(256, 3 - index)
      ])
      end = sum([
        for index, octet in [
          for part in split(".", try(cidrhost(subnet.cidr, 0), "0.0.0.0")) : try(parseint(part, 10), 0)
        ] : octet * pow(256, 3 - index)
      ]) + pow(2, 32 - try(tonumber(split("/", subnet.cidr)[1]), 32)) - 1
    }
  ]

  subnet_topology_valid = (
    length(local.subnet_cidr_ranges) == length(var.availability_zone_ids) * 3 &&
    alltrue([
      for subnet in local.subnet_cidr_ranges :
      subnet.prefix_length >= local.vpc_cidr_range.prefix_length &&
      subnet.start >= local.vpc_cidr_range.start &&
      subnet.end <= local.vpc_cidr_range.end
    ]) &&
    alltrue(flatten([
      for i, subnet_a in local.subnet_cidr_ranges : [
        for j, subnet_b in local.subnet_cidr_ranges :
        i == j || subnet_a.start > subnet_b.end || subnet_b.start > subnet_a.end
      ]
    ]))
  )

  subnets = {
    for subnet in local.subnet_cidr_entries : subnet.key => subnet
  }

  nat_gateway_az_ids = var.nat_mode == "disabled" ? toset([]) : (
    var.nat_mode == "shared" ? toset([sort(tolist(var.availability_zone_ids))[0]]) : var.availability_zone_ids
  )

  endpoint_configs = {
    for name, endpoint in var.endpoint_configs : name => merge(endpoint, {
      aws_type = title(endpoint.type)
    })
  }

  route_tables_by_tier = {
    public      = aws_route_table.public
    application = aws_route_table.private_application
    data        = aws_route_table.private_data
  }
}
