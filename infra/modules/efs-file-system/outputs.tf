output "file_system_id" {
  description = "EFS file system ID."
  value       = aws_efs_file_system.this.id
}

output "file_system_arn" {
  description = "EFS file system ARN."
  value       = aws_efs_file_system.this.arn
}

output "security_group_id" {
  description = "Mount-target security group; clients need TCP 2049 egress to it."
  value       = aws_security_group.this.id
}

output "access_point_arns" {
  description = "Access point ARNs keyed by name."
  value       = { for name, ap in aws_efs_access_point.this : name => ap.arn }
}

output "access_point_ids" {
  description = "Access point IDs keyed by name."
  value       = { for name, ap in aws_efs_access_point.this : name => ap.id }
}
