output "endpoint" {
  description = "Writer endpoint hostname."
  value       = local.is_aurora ? aws_rds_cluster.this[0].endpoint : aws_db_instance.this[0].address
}

output "reader_endpoint" {
  description = "Aurora reader endpoint, or null for standard RDS."
  value       = local.is_aurora ? aws_rds_cluster.this[0].reader_endpoint : null
}

output "port" {
  description = "Database port."
  value       = local.port
}

output "security_group_id" {
  description = "Database security group."
  value       = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN of the RDS-managed master credential (value never in state outputs)."
  value       = local.is_aurora ? aws_rds_cluster.this[0].master_user_secret[0].secret_arn : aws_db_instance.this[0].master_user_secret[0].secret_arn
}

output "resource_identifier" {
  description = "DB instance or cluster identifier."
  value       = local.identifier
}
