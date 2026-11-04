variable "name" {
  description = "Repository name (for example a service name)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._/-]{1,100}$", var.name))
    error_message = "name must be a valid lowercase ECR repository name."
  }
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for image encryption."
  type        = string
}

variable "untagged_expiry_days" {
  description = "Days before untagged images expire."
  type        = number
  default     = 14
}

variable "tagged_images_to_keep" {
  description = "Number of most recent tagged images to retain (supports rollback)."
  type        = number
  default     = 30
}

variable "pull_principal_arns" {
  description = "Additional IAM principal ARNs (for example other accounts' roles) allowed to pull images."
  type        = set(string)
  default     = []
}
