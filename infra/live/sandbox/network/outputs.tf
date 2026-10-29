output "vpc_id" {
  description = "Sandbox VPC ID."
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "Sandbox VPC IPv4 CIDR."
  value       = module.network.vpc_cidr_block
}

output "availability_zone_ids" {
  description = "AZ IDs selected for the sandbox network."
  value       = module.network.availability_zone_ids
}

output "public_subnet_ids_by_az" {
  description = "Public edge subnet IDs by AZ."
  value       = module.network.public_subnet_ids_by_az
}

output "private_application_subnet_ids_by_az" {
  description = "Private ECS/EKS subnet IDs by AZ."
  value       = module.network.private_application_subnet_ids_by_az
}

output "private_data_subnet_ids_by_az" {
  description = "Private RDS/data subnet IDs by AZ."
  value       = module.network.private_data_subnet_ids_by_az
}

output "public_subnet_ids" {
  description = "Public edge subnet IDs in stable AZ order."
  value       = module.network.public_subnet_ids
}

output "private_application_subnet_ids" {
  description = "Private ECS/EKS subnet IDs in stable AZ order."
  value       = module.network.private_application_subnet_ids
}

output "private_data_subnet_ids" {
  description = "Private RDS/data subnet IDs in stable AZ order."
  value       = module.network.private_data_subnet_ids
}

output "public_route_table_ids" {
  description = "Public route table IDs by AZ."
  value       = module.network.public_route_table_ids
}

output "private_application_route_table_ids" {
  description = "Private application route table IDs by AZ."
  value       = module.network.private_application_route_table_ids
}

output "private_data_route_table_ids" {
  description = "Private data route table IDs by AZ."
  value       = module.network.private_data_route_table_ids
}

output "internet_gateway_id" {
  description = "Internet gateway attached to the VPC; routes only public subnet tables."
  value       = module.network.internet_gateway_id
}

output "nat_gateway_ids_by_az" {
  description = "NAT gateway IDs keyed by placement AZ ID."
  value       = module.network.nat_gateway_ids_by_az
}

output "vpc_endpoint_ids_by_service" {
  description = "Declared VPC endpoint IDs keyed by stable service name."
  value       = module.network.vpc_endpoint_ids_by_service
}

output "load_balancer_security_group_id" {
  description = "Default-deny security group for workload-owned load balancers."
  value       = module.network.load_balancer_security_group_id
}

output "application_security_group_id" {
  description = "Default-deny ECS/EKS application security group."
  value       = module.network.application_security_group_id
}

output "data_security_group_id" {
  description = "Default-deny RDS/data security group."
  value       = module.network.data_security_group_id
}

output "network_flow_rule_ids" {
  description = "Declared flow ingress/egress rule IDs keyed by name and direction."
  value       = module.network.network_flow_rule_ids
}

output "public_lb_ingress_approvals" {
  description = "Public LB ingress approval references and exact scope declared for review."
  value       = module.network.public_lb_ingress_approvals
}

output "ipam_approval_reference" {
  description = "IPAM allocation/approval reference used for this network."
  value       = module.network.ipam_approval_reference
}
