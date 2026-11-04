variable "bucket_name" {
  description = "Globally unique bucket name approved for this environment."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name)) && !strcontains(var.bucket_name, "..")
    error_message = "bucket_name must be a valid 3-63 character lowercase S3 bucket name."
  }
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for SSE-KMS default encryption."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN."
  }
}

variable "data_classification" {
  description = "Data classification recorded on the bucket (for example internal, confidential)."
  type        = string

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be public, internal, confidential, or restricted."
  }
}

variable "versioning_enabled" {
  description = "Enable object versioning. Required for production and recommended everywhere."
  type        = bool
  default     = true
}

variable "access_log_bucket_name" {
  description = "Existing server access-log bucket; null disables access logging (record the exception)."
  type        = string
  default     = null
}

variable "lifecycle_rules" {
  description = "Object lifecycle rules. Each rule may transition, expire current objects, and expire noncurrent versions."
  type = list(object({
    id                                 = string
    prefix                             = optional(string, "")
    transition_days                    = optional(number)
    transition_storage_class           = optional(string, "STANDARD_IA")
    expiration_days                    = optional(number)
    noncurrent_version_expiration_days = optional(number, 90)
  }))
  default = [{ id = "default-noncurrent-cleanup" }]

  validation {
    condition = alltrue([
      for rule in var.lifecycle_rules :
      can(regex("^[a-z0-9-]{1,64}$", rule.id)) &&
      contains(["STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER_IR", "GLACIER", "DEEP_ARCHIVE"], rule.transition_storage_class)
    ])
    error_message = "Lifecycle rules need slug IDs and a supported transition storage class."
  }
}

variable "cloudfront_distribution_arns" {
  description = "CloudFront distributions allowed to read objects through Origin Access Control."
  type        = set(string)
  default     = []
}

variable "additional_policy_statements" {
  description = "Reviewed least-privilege bucket policy statements as JSON policy documents (merged by source_policy_documents)."
  type        = list(string)
  default     = []
}

variable "eventbridge_notifications" {
  description = "Send object events to EventBridge (used by event-driven and media pipelines)."
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Allow deleting a non-empty bucket. Never enable outside disposable sandbox data."
  type        = bool
  default     = false
}
