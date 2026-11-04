output "domain_arn" {
  description = "OpenSearch domain ARN."
  value       = aws_opensearch_domain.this.arn
}

output "endpoint" {
  description = "Private VPC HTTPS endpoint."
  value       = aws_opensearch_domain.this.endpoint
}

output "security_group_id" {
  description = "Domain security group."
  value       = aws_security_group.this.id
}
