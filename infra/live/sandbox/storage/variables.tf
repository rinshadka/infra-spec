variable "aws_account_id" {
  description = "Expected 12-digit AWS account ID for this sandbox deployment."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "AWS Region for this sandbox deployment."
  type        = string

  validation {
    condition     = length(trimspace(var.aws_region)) > 0
    error_message = "aws_region must not be empty."
  }
}

variable "environment" {
  description = "Environment name used for resource naming and governance tags."
  type        = string

  validation {
    condition     = contains(["sandbox", "development", "staging", "production"], var.environment)
    error_message = "environment must be sandbox, development, staging, or production."
  }
}

variable "owner" {
  description = "Organization team or person accountable for this capability."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "cost_center" {
  description = "Approved cost-center value for resource tags."
  type        = string

  validation {
    condition     = length(trimspace(var.cost_center)) > 0
    error_message = "cost_center must not be empty."
  }
}

variable "additional_tags" {
  description = "Optional resource tags; required governance keys are set by the root and cannot be overridden."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "Storage data KMS key (security-baseline data_kms_key_arns[\"storage\"])."
  type        = string
}

variable "access_log_bucket_name" {
  description = "Existing S3 server access-log bucket, or null with a recorded exception."
  type        = string
  default     = null
}

variable "buckets" {
  description = "Buckets keyed by purpose."
  type = map(object({
    bucket_name                  = string
    data_classification          = string
    eventbridge_notifications    = optional(bool, false)
    cloudfront_distribution_arns = optional(set(string), [])
    lifecycle_rules = optional(list(object({
      id                                 = string
      prefix                             = optional(string, "")
      transition_days                    = optional(number)
      transition_storage_class           = optional(string, "STANDARD_IA")
      expiration_days                    = optional(number)
      noncurrent_version_expiration_days = optional(number, 90)
    })), [{ id = "default-noncurrent-cleanup" }])
  }))
  default = {}
}

variable "vpc_id" {
  description = "Network root output vpc_id (required when file_systems is non-empty)."
  type        = string
  default     = null
}

variable "data_subnet_ids" {
  description = "Network root output private_data_subnet_ids."
  type        = list(string)
  default     = []
}

variable "file_systems" {
  description = "EFS file systems keyed by purpose."
  type = map(object({
    client_security_group_ids = set(string)
    throughput_mode           = optional(string, "elastic")
    access_points = optional(map(object({
      path        = string
      uid         = number
      gid         = number
      permissions = optional(string, "0750")
    })), {})
  }))
  default = {}
}
