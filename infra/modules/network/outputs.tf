output "vpc_id" {
  description = "ID of the environment VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Approved IPv4 CIDR assigned to the VPC."
  value       = aws_vpc.this.cidr_block
}

output "availability_zone_ids" {
  description = "Explicit AZ IDs used to distribute subnet tiers."
  value       = var.availability_zone_ids
}

output "public_subnet_ids_by_az" {
  description = "Public subnet IDs keyed by AZ ID."
  value = {
    for az_id in var.availability_zone_ids : az_id => aws_subnet.this["${az_id}/public"].id
  }
}

output "private_application_subnet_ids_by_az" {
  description = "Private application subnet IDs keyed by AZ ID."
  value = {
    for az_id in var.availability_zone_ids : az_id => aws_subnet.this["${az_id}/application"].id
  }
}

output "private_data_subnet_ids_by_az" {
  description = "Private data subnet IDs keyed by AZ ID."
  value = {
    for az_id in var.availability_zone_ids : az_id => aws_subnet.this["${az_id}/data"].id
  }
}

output "public_subnet_ids" {
  description = "Public subnet IDs in stable AZ-ID order."
  value       = [for az_id in sort(tolist(var.availability_zone_ids)) : aws_subnet.this["${az_id}/public"].id]
}

output "private_application_subnet_ids" {
  description = "Private application subnet IDs in stable AZ-ID order."
  value       = [for az_id in sort(tolist(var.availability_zone_ids)) : aws_subnet.this["${az_id}/application"].id]
}

output "private_data_subnet_ids" {
  description = "Private data subnet IDs in stable AZ-ID order."
  value       = [for az_id in sort(tolist(var.availability_zone_ids)) : aws_subnet.this["${az_id}/data"].id]
}

output "public_route_table_ids" {
  description = "Public route-table IDs keyed by AZ ID."
  value       = { for az_id, table in aws_route_table.public : az_id => table.id }
}

output "private_application_route_table_ids" {
  description = "Private application route-table IDs keyed by AZ ID."
  value       = { for az_id, table in aws_route_table.private_application : az_id => table.id }
}

output "private_data_route_table_ids" {
  description = "Private data route-table IDs keyed by AZ ID."
  value       = { for az_id, table in aws_route_table.private_data : az_id => table.id }
}

output "internet_gateway_id" {
  description = "ID of the VPC internet gateway used only by public subnet route tables."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids_by_az" {
  description = "NAT gateway IDs keyed by their public subnet AZ ID; empty when disabled."
  value       = { for az_id, gateway in aws_nat_gateway.this : az_id => gateway.id }
}

output "vpc_endpoint_ids_by_service" {
  description = "VPC endpoint IDs keyed by the caller's stable endpoint service name."
  value       = { for name, endpoint in aws_vpc_endpoint.this : name => endpoint.id }
}

output "load_balancer_security_group_id" {
  description = "Default-deny security group for workload-owned load balancers; no public ingress is created."
  value       = aws_security_group.workload["load_balancer"].id
}

output "application_security_group_id" {
  description = "Default-deny security group for ECS/EKS application workloads."
  value       = aws_security_group.workload["application"].id
}

output "data_security_group_id" {
  description = "Default-deny security group for databases and private data services."
  value       = aws_security_group.workload["data"].id
}

output "network_flow_rule_ids" {
  description = "Declared tier-flow ingress and egress rule IDs keyed by rule name and direction."
  value = merge(
    { for name, rule in aws_vpc_security_group_ingress_rule.tier_flow : "${name}/ingress" => rule.id },
    { for name, rule in aws_vpc_security_group_egress_rule.tier_flow : "${name}/egress" => rule.id },
    { for name, rule in aws_vpc_security_group_ingress_rule.public_load_balancer : "public/${name}/ingress" => rule.id },
    { for name, rule in aws_vpc_security_group_egress_rule.endpoint_interface : "endpoint-interface/${name}/egress" => rule.id },
    { for name, rule in aws_vpc_security_group_ingress_rule.endpoint_interface : "endpoint-interface/${name}/ingress" => rule.id },
    { for name, rule in aws_vpc_security_group_egress_rule.endpoint_gateway : "endpoint-gateway/${name}/egress" => rule.id },
    { for name, rule in aws_vpc_security_group_egress_rule.explicit_destination : "destination/${name}/egress" => rule.id }
  )
}

output "public_lb_ingress_approvals" {
  description = "Declared public load-balancer ingress scopes and approval evidence for plan review."
  value = {
    for rule in var.public_lb_ingress : rule.name => {
      business_need      = rule.business_need
      approval_reference = rule.approval_reference
      source_cidr_blocks = rule.source_cidr_blocks
      protocol           = rule.protocol
      from_port          = rule.from_port
      to_port            = rule.to_port
    }
  }
}

output "ipam_approval_reference" {
  description = "Human-reviewed IPAM allocation reference recorded for review."
  value       = var.ipam_approval_reference
}
