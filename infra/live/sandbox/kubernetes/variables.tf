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

variable "kubernetes_version" {
  description = "Explicit EKS minor version approved for this environment."
  type        = string
}

variable "application_subnet_ids" {
  description = "Network root output private_application_subnet_ids."
  type        = list(string)
}

variable "compute_kms_key_arn" {
  description = "security-baseline data key for Kubernetes secrets and node volumes."
  type        = string
}

variable "log_kms_key_arn" {
  description = "security-baseline logs_kms_key_arn."
  type        = string
}

variable "access_entries" {
  description = "Cluster access entries; declare at least one administrator role."
  type = map(object({
    principal_arn = string
    policy_name   = string
    namespaces    = optional(set(string), [])
  }))
}

variable "node_groups" {
  description = "Managed node groups."
  type = map(object({
    instance_types             = list(string)
    capacity_type              = optional(string, "ON_DEMAND")
    ami_type                   = optional(string, "AL2023_x86_64_STANDARD")
    min_size                   = number
    max_size                   = number
    desired_size               = number
    disk_size_gib              = optional(number, 50)
    max_unavailable_percentage = optional(number, 33)
    labels                     = optional(map(string), {})
  }))
}
