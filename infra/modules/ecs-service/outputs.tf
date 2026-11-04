output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "Current task definition revision; the previous revision is the rollback target."
  value       = aws_ecs_task_definition.this.arn
}

output "task_role_arn" {
  description = "Application task role ARN (grant resource access to this role)."
  value       = aws_iam_role.task.arn
}

output "execution_role_arn" {
  description = "Task execution role ARN."
  value       = aws_iam_role.execution.arn
}

output "log_group_name" {
  description = "Application log group."
  value       = aws_cloudwatch_log_group.this.name
}
