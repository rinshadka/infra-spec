output "load_balancer_arn" {
  description = "ALB ARN."
  value       = module.load_balancer.load_balancer_arn
}

output "target_group_arns" {
  description = "Target groups consumed by the containers/compute roots (target_group_arn)."
  value       = module.load_balancer.target_group_arns
}

output "listener_arns" {
  description = "Declared listener inventory owned by this root."
  value       = module.load_balancer.listener_arns
}

output "certificate_arn" {
  description = "Regional ACM certificate ARN."
  value       = module.certificate.certificate_arn
}

output "cdn_distribution_arn" {
  description = "Feed into the storage root bucket cloudfront_distribution_arns for OAC reads."
  value       = try(module.cdn[0].distribution_arn, null)
}
