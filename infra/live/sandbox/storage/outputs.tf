output "bucket_arns" {
  description = "Bucket ARNs by purpose."
  value       = { for k, b in module.bucket : k => b.bucket_arn }
}

output "bucket_names" {
  description = "Bucket names by purpose."
  value       = { for k, b in module.bucket : k => b.bucket_id }
}

output "bucket_regional_domain_names" {
  description = "Regional domain names by purpose (CloudFront OAC origins)."
  value       = { for k, b in module.bucket : k => b.bucket_regional_domain_name }
}

output "file_system_ids" {
  description = "EFS IDs by purpose."
  value       = { for k, f in module.file_system : k => f.file_system_id }
}

output "file_system_access_point_ids" {
  description = "EFS access point IDs by purpose and access point."
  value       = { for k, f in module.file_system : k => f.access_point_ids }
}
