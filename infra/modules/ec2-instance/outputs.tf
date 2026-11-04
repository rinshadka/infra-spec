output "instance_id" {
  description = "Instance ID (connect with SSM Session Manager; no SSH key pair is configured)."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IPv4 address."
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "Instance security group for downstream rule references."
  value       = aws_security_group.this.id
}

output "role_arn" {
  description = "Instance role ARN."
  value       = aws_iam_role.this.arn
}
