output "distribution_arn" {
  description = "Distribution ARN; pass to the s3-bucket cloudfront_distribution_arns input for OAC reads."
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_id" {
  description = "Distribution ID for invalidations."
  value       = aws_cloudfront_distribution.this.id
}

output "domain_name" {
  description = "CloudFront domain for Route 53 alias records."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "hosted_zone_id" {
  description = "CloudFront hosted zone ID for Route 53 alias records."
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}
