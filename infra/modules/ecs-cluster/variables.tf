variable "name" {
  description = "Short cluster purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "log_kms_key_arn" {
  description = "KMS key for ECS Exec audit logs (security-baseline logs key)."
  type        = string
}

variable "log_retention_days" {
  description = "Retention for ECS Exec audit logs."
  type        = number
  default     = 90
}

variable "container_insights" {
  description = "Container Insights mode: enhanced, enabled, or disabled."
  type        = string
  default     = "enhanced"

  validation {
    condition     = contains(["enhanced", "enabled", "disabled"], var.container_insights)
    error_message = "container_insights must be enhanced, enabled, or disabled."
  }
}

variable "default_capacity_provider_strategy" {
  description = "Default strategy across FARGATE and FARGATE_SPOT. Production should keep a FARGATE base."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = optional(number, 0)
  }))
  default = [{ capacity_provider = "FARGATE", weight = 1, base = 1 }]

  validation {
    condition     = alltrue([for s in var.default_capacity_provider_strategy : contains(["FARGATE", "FARGATE_SPOT"], s.capacity_provider)])
    error_message = "Only FARGATE and FARGATE_SPOT capacity providers are supported by this module."
  }
}
