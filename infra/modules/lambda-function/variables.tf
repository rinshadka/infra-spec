variable "name" {
  description = "Function purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "description" {
  description = "Function description."
  type        = string
}

variable "runtime" {
  description = "Supported managed runtime (for example python3.13, nodejs22.x)."
  type        = string
}

variable "handler" {
  description = "Handler entry point."
  type        = string
}

variable "package" {
  description = "Deployment package built by the application pipeline: S3 object (preferred) or local zip path."
  type = object({
    s3_bucket         = optional(string)
    s3_key            = optional(string)
    s3_object_version = optional(string)
    filename          = optional(string)
    source_code_hash  = optional(string)
  })

  validation {
    condition     = (var.package.filename != null) != (var.package.s3_bucket != null && var.package.s3_key != null)
    error_message = "Provide either filename or s3_bucket and s3_key, not both."
  }
}

variable "architecture" {
  description = "arm64 (default) or x86_64."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "architecture must be arm64 or x86_64."
  }
}

variable "memory_mb" {
  description = "Memory size."
  type        = number
  default     = 256
}

variable "timeout_seconds" {
  description = "Function timeout; SQS visibility timeout should be at least six times this value."
  type        = number
  default     = 30
}

variable "reserved_concurrency" {
  description = "Reserved concurrency cap protecting downstream systems; null for unreserved."
  type        = number
  default     = null
}

variable "environment_variables" {
  description = "Non-secret environment variables (encrypted with kms_key_arn). Read secrets at runtime."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "KMS key for environment variables and the log group."
  type        = string
}

variable "log_retention_days" {
  description = "Log retention."
  type        = number
  default     = 30
}

variable "vpc_config" {
  description = "Private subnet placement, or null for no VPC attachment."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "policy_json" {
  description = "Least-privilege application policy; null grants no extra AWS access."
  type        = string
  default     = null
}

variable "sqs_event_source" {
  description = "SQS trigger with partial-batch failure reporting."
  type = object({
    queue_arn                   = string
    batch_size                  = optional(number, 10)
    maximum_batching_window_sec = optional(number, 0)
    maximum_concurrency         = optional(number, 10)
  })
  default = null
}

variable "async_failure_destination_arn" {
  description = "SQS queue or SNS topic receiving failed asynchronous invocations (EventBridge/S3 triggers)."
  type        = string
  default     = null
}

variable "alarm_topic_arn" {
  description = "Operations SNS topic for error and throttle alarms."
  type        = string
}
