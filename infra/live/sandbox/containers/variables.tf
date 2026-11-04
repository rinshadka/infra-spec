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

variable "service_name" {
  description = "Service and repository name."
  type        = string
}

variable "image_tag_or_digest" {
  description = "Image tag (sandbox) or @sha256 digest (required in production) appended to the repository URL."
  type        = string
}

variable "application_subnet_ids" {
  description = "Network root output private_application_subnet_ids."
  type        = list(string)
}

variable "application_security_group_id" {
  description = "Network root output application_security_group_id."
  type        = string
}

variable "target_group_arn" {
  description = "Edge root output target_group_arns[\"app\"], or null for a worker."
  type        = string
  default     = null
}

variable "container_port" {
  description = "Container port served behind the load balancer."
  type        = number
  default     = 8080
}

variable "compute_kms_key_arn" {
  description = "security-baseline data key for ECR images."
  type        = string
}

variable "log_kms_key_arn" {
  description = "security-baseline logs_kms_key_arn."
  type        = string
}

variable "alarm_topic_arn" {
  description = "security-baseline operations_topic_arn."
  type        = string
}

variable "autoscaling" {
  description = "Service autoscaling bounds."
  type = object({
    min_capacity       = number
    max_capacity       = number
    target_cpu_percent = optional(number, 60)
  })
  default = { min_capacity = 1, max_capacity = 2 }
}

variable "use_fargate_spot" {
  description = "Prefer FARGATE_SPOT capacity (non-production cost saving)."
  type        = bool
  default     = true
}
