output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "ECS cluster name (used for service autoscaling resource IDs)."
  value       = aws_ecs_cluster.this.name
}
