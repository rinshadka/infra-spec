output "logs_kms_key_arn" {
  description = "Logs KMS key consumed by every workload root (log_kms_key_arn)."
  value       = module.security_baseline.logs_kms_key_arn
}

output "data_kms_key_arns" {
  description = "Data KMS keys by purpose."
  value       = module.security_baseline.data_kms_key_arns
}

output "operations_topic_arn" {
  description = "Operations SNS topic consumed by workload roots (alarm_topic_arn) and the network nat_alarm_topic_arn."
  value       = module.security_baseline.operations_topic_arn
}

output "audit_bucket_name" {
  description = "Audit bucket name."
  value       = module.security_baseline.audit_bucket_name
}

output "secret_arns" {
  description = "Secret container ARNs."
  value       = module.security_baseline.secret_arns
}
