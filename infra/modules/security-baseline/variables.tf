variable "operations_owner" {
  description = "Operations team that owns audit logs, alarms, and finding remediation."
  type        = string

  validation {
    condition     = length(trimspace(var.operations_owner)) > 0
    error_message = "operations_owner must name the accountable operations team."
  }
}

variable "data_kms_keys" {
  description = "Workload data keys keyed by purpose (for example rds, s3, opensearch). The logs key is always created."
  type = map(object({
    description             = string
    service_principals      = optional(set(string), [])
    deletion_window_in_days = optional(number, 30)
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, key in var.data_kms_keys :
      can(regex("^[a-z][a-z0-9-]{1,30}$", name)) &&
      name != "logs" &&
      length(trimspace(key.description)) > 0 &&
      key.deletion_window_in_days >= 7 && key.deletion_window_in_days <= 30 &&
      alltrue([for principal in key.service_principals : can(regex("^[a-z0-9.-]+\\.amazonaws\\.com$", principal))])
    ])
    error_message = "Key names must be lowercase slugs other than logs, with a description, a 7-30 day deletion window, and AWS service principals only."
  }
}

variable "audit_log_retention_days" {
  description = "Days to retain CloudTrail and AWS Config objects in the audit bucket before expiry."
  type        = number
  default     = 365

  validation {
    condition     = var.audit_log_retention_days >= 90
    error_message = "audit_log_retention_days must be at least 90."
  }
}

variable "enable_cloudtrail" {
  description = "Create an account multi-Region trail. Disable only when an approved organization trail already records this account."
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Create the AWS Config recorder and delivery channel. Disable only when an organization-managed recorder already exists."
  type        = bool
  default     = true
}

variable "config_include_global_resources" {
  description = "Record global IAM resources. Enable in exactly one Region per account to avoid duplicate items."
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable Security Hub in this account and Region. Disable when delegated-administrator automation enables it."
  type        = bool
  default     = true
}

variable "security_hub_standards" {
  description = "Security Hub standard paths relative to arn:<partition>:securityhub:<region>::standards/."
  type        = set(string)
  default     = ["aws-foundational-security-best-practices/v/1.0.0"]
}

variable "secret_containers" {
  description = "Secrets Manager containers created without values; workloads or operators populate them out of band."
  type = map(object({
    description             = string
    kms_key                 = optional(string, "logs")
    recovery_window_in_days = optional(number, 30)
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, secret in var.secret_containers :
      can(regex("^[a-z][a-z0-9/_-]{1,100}$", name)) &&
      length(trimspace(secret.description)) > 0 &&
      secret.recovery_window_in_days >= 7 && secret.recovery_window_in_days <= 30
    ])
    error_message = "Secret names must be lowercase paths with a description and a 7-30 day recovery window."
  }
}
