output "input_bucket_name" {
  description = "Source media bucket."
  value       = module.input_bucket.bucket_id
}

output "output_bucket_name" {
  description = "Rendition output bucket."
  value       = module.output_bucket.bucket_id
}

output "mediaconvert_queue_arn" {
  description = "MediaConvert queue ARN; submit jobs to this queue."
  value       = aws_media_convert_queue.this.arn
}

output "mediaconvert_role_arn" {
  description = "Role MediaConvert assumes for jobs; the submitter needs iam:PassRole on it."
  value       = aws_iam_role.mediaconvert.arn
}

output "status_queue_arn" {
  description = "Queue receiving COMPLETE/ERROR/CANCELED job events for the workload status handler."
  value       = module.status_queue.queue_arn
}

output "status_dlq_arn" {
  description = "Dead-letter queue for unprocessed job status events."
  value       = module.status_queue.dlq_arn
}

output "submitter_policy_json" {
  description = "Least-privilege policy to attach to the workload submitter Lambda role."
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateJobsOnPipelineQueue"
        Effect   = "Allow"
        Action   = ["mediaconvert:CreateJob"]
        Resource = [aws_media_convert_queue.this.arn, "arn:${local.partition}:mediaconvert:*:*:presets/*", "arn:${local.partition}:mediaconvert:*:*:jobTemplates/*"]
      },
      {
        Sid       = "PassMediaConvertRole"
        Effect    = "Allow"
        Action    = ["iam:PassRole"]
        Resource  = [aws_iam_role.mediaconvert.arn]
        Condition = { StringEquals = { "iam:PassedToService" = "mediaconvert.amazonaws.com" } }
      }
    ]
  })
}
