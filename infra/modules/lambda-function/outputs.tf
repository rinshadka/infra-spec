output "function_name" {
  description = "Function name."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "Function ARN (EventBridge targets, S3 notifications)."
  value       = aws_lambda_function.this.arn
}

output "role_arn" {
  description = "Execution role ARN; grant resource access to this role."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Execution role name for attaching additional reviewed policies."
  value       = aws_iam_role.this.name
}
