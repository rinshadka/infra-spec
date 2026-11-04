output "endpoint" {
  description = "Writer endpoint."
  value       = module.database.endpoint
}

output "reader_endpoint" {
  description = "Aurora reader endpoint or null."
  value       = module.database.reader_endpoint
}

output "port" {
  description = "Database port."
  value       = module.database.port
}

output "master_user_secret_arn" {
  description = "RDS-managed master credential secret ARN."
  value       = module.database.master_user_secret_arn
}
