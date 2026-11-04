output "repository_url" {
  description = "Repository URL; deploy images by immutable tag or digest."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "Repository ARN for CI push-role policies."
  value       = aws_ecr_repository.this.arn
}
