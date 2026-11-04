output "input_bucket_name" {
  description = "Source media bucket."
  value       = module.media.input_bucket_name
}

output "output_bucket_name" {
  description = "Rendition bucket."
  value       = module.media.output_bucket_name
}

output "mediaconvert_queue_arn" {
  description = "MediaConvert queue ARN."
  value       = module.media.mediaconvert_queue_arn
}

output "mediaconvert_role_arn" {
  description = "Role passed to MediaConvert jobs."
  value       = module.media.mediaconvert_role_arn
}

output "status_queue_arn" {
  description = "Job status events queue for the workload status handler."
  value       = module.media.status_queue_arn
}

output "submitter_policy_json" {
  description = "Policy to attach to the submitter Lambda role."
  value       = module.media.submitter_policy_json
}
