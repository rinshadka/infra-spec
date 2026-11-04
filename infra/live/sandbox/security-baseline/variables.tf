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

variable "operations_owner" {
  description = "Operations team owning audit logs, alarms, and finding remediation."
  type        = string
}

variable "data_kms_keys" {
  description = "Workload data keys by purpose; see infra/modules/security-baseline."
  type = map(object({
    description             = string
    service_principals      = optional(set(string), [])
    deletion_window_in_days = optional(number, 30)
  }))
  default = {}
}

variable "audit_log_retention_days" {
  description = "Audit object retention in days (minimum 90)."
  type        = number
  default     = 365
}

variable "enable_cloudtrail" {
  description = "Create an account trail; false only when an approved organization trail covers the account."
  type        = bool
}

variable "enable_config" {
  description = "Create the AWS Config recorder; false only when an organization recorder exists."
  type        = bool
}

variable "enable_security_hub" {
  description = "Enable Security Hub; false only when delegated-administrator automation enables it."
  type        = bool
}

variable "secret_containers" {
  description = "Secrets Manager containers created without values."
  type = map(object({
    description             = string
    kms_key                 = optional(string, "logs")
    recovery_window_in_days = optional(number, 30)
  }))
  default = {}
}
