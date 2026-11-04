output "server_endpoint" {
  description = "SFTP endpoint hostname."
  value       = module.sftp.server_endpoint
}

output "public_ips" {
  description = "Elastic IPs to share with partners (empty when private)."
  value       = module.sftp.public_ips
}
