output "endpoint" {
  description = "Private HTTPS endpoint."
  value       = module.search.endpoint
}

output "domain_arn" {
  description = "Domain ARN for client IAM policies."
  value       = module.search.domain_arn
}
