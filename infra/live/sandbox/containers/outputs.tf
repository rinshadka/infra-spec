output "repository_url" {
  description = "ECR repository URL for the CI image push role."
  value       = module.repository.repository_url
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.cluster.cluster_name
}

output "service_name" {
  description = "ECS service name."
  value       = module.service.service_name
}

output "task_role_arn" {
  description = "Task role for downstream resource grants (S3, SQS, Secrets Manager)."
  value       = module.service.task_role_arn
}
