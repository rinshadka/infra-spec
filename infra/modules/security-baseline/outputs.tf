output "logs_kms_key_arn" {
  description = "Customer-managed KMS key for audit logs, CloudWatch log groups, and the operations topic."
  value       = aws_kms_key.logs.arn
}

output "data_kms_key_arns" {
  description = "Workload data KMS key ARNs keyed by declared purpose."
  value       = { for name, key in aws_kms_key.data : name => key.arn }
}

output "audit_bucket_name" {
  description = "Audit bucket receiving CloudTrail and AWS Config delivery."
  value       = aws_s3_bucket.audit.id
}

output "audit_bucket_arn" {
  description = "Audit bucket ARN."
  value       = aws_s3_bucket.audit.arn
}

output "cloudtrail_arn" {
  description = "Account trail ARN, or null when an organization trail is used."
  value       = try(aws_cloudtrail.audit[0].arn, null)
}

output "operations_topic_arn" {
  description = "Encrypted operations SNS topic for alarms (for example the network nat_alarm_topic_arn input)."
  value       = aws_sns_topic.operations.arn
}

output "secret_arns" {
  description = "Secret container ARNs keyed by declared name; values are never managed here."
  value       = { for name, secret in aws_secretsmanager_secret.this : name => secret.arn }
}
