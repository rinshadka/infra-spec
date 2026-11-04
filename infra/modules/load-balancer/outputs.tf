output "load_balancer_arn" {
  description = "Load balancer ARN (also used for WAF association)."
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "Load balancer DNS name for Route 53 alias records or CloudFront custom origins."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Canonical hosted zone ID for Route 53 alias records."
  value       = aws_lb.this.zone_id
}

output "target_group_arns" {
  description = "Target group ARNs keyed by name, for ECS services, EKS bindings, or EC2 attachments."
  value       = { for name, tg in aws_lb_target_group.this : name => tg.arn }
}

output "listener_arns" {
  description = "Listener ARNs keyed by name; the declared listener inventory owned by this root."
  value       = { for name, l in aws_lb_listener.this : name => l.arn }
}
