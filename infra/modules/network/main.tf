data "aws_region" "current" {}

resource "aws_vpc" "this" {
  cidr_block                       = var.vpc_cidr_block
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = false

  lifecycle {
    precondition {
      condition     = local.subnet_topology_valid
      error_message = "Subnet CIDRs must be contained by the VPC, meet the AWS subnet-size limit, and not overlap."
    }
  }

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}
