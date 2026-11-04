output "server_id" {
  description = "Transfer Family server ID."
  value       = aws_transfer_server.this.id
}

output "server_endpoint" {
  description = "Server endpoint hostname."
  value       = aws_transfer_server.this.endpoint
}

output "public_ips" {
  description = "Elastic IPs to share with partners for allow-listing (empty when private)."
  value       = [for eip in aws_eip.this : eip.public_ip]
}

output "user_role_arns" {
  description = "Per-user scoped IAM role ARNs keyed by username."
  value       = { for name, role in aws_iam_role.user : name => role.arn }
}
