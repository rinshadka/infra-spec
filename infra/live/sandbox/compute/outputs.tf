output "instance_id" {
  description = "Instance ID (aws ssm start-session --target)."
  value       = module.instance.instance_id
}

output "security_group_id" {
  description = "Instance security group for data-tier client_security_group_ids."
  value       = module.instance.security_group_id
}
