output "web_acl_arn" {
  description = "Web ACL ARN; pass to CloudFront web_acl_id for CLOUDFRONT scope."
  value       = aws_wafv2_web_acl.this.arn
}

output "log_group_name" {
  description = "WAF log group name."
  value       = aws_cloudwatch_log_group.this.name
}
