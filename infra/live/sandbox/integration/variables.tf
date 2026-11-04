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

variable "integration_name" {
  description = "Integration purpose slug (queue, function, and rule names)."
  type        = string
}

variable "event_sources" {
  description = "EventBridge source values routed to the queue (for example app.orders)."
  type        = list(string)
}

variable "event_detail_types" {
  description = "EventBridge detail-type values routed to the queue."
  type        = list(string)
}

variable "consumer" {
  description = "Consumer Lambda built by the application pipeline."
  type = object({
    runtime         = string
    handler         = string
    s3_bucket       = string
    s3_key          = string
    timeout_seconds = optional(number, 30)
    memory_mb       = optional(number, 256)
    max_concurrency = optional(number, 5)
    policy_json     = optional(string)
  })
}

variable "messaging_kms_key_arn" {
  description = "security-baseline data_kms_key_arns[\"messaging\"] (queue encryption)."
  type        = string
}

variable "log_kms_key_arn" {
  description = "security-baseline logs_kms_key_arn (function logs and environment)."
  type        = string
}

variable "alarm_topic_arn" {
  description = "security-baseline operations_topic_arn."
  type        = string
}
