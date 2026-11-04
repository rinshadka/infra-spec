output "certificate_arn" {
  description = "Validated ACM certificate ARN (available only after DNS validation completes)."
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "alias_record_fqdns" {
  description = "Alias record FQDNs keyed by name."
  value       = { for name, record in aws_route53_record.alias : name => record.fqdn }
}
