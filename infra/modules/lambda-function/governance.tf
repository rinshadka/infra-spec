# Shared governance contract. Keep identical across modules in infra/modules/.

variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string

  validation {
    condition     = contains(["sandbox", "development", "staging", "production"], var.environment)
    error_message = "environment must be sandbox, development, staging, or production."
  }
}

variable "tags" {
  description = "Required governance tags supplied by the environment root."
  type = object({
    Project     = string
    Environment = string
    ManagedBy   = string
    Owner       = string
    CostCenter  = string
  })

  validation {
    condition = (
      alltrue([for value in values(var.tags) : length(trimspace(value)) > 0]) &&
      var.tags.Project == "infra-spec" &&
      var.tags.ManagedBy == "Terraform" &&
      var.tags.Environment == var.environment
    )
    error_message = "Required governance tags must be non-empty, Project must be infra-spec, ManagedBy must be Terraform, and Environment must match the environment input."
  }
}

variable "additional_tags" {
  description = "Optional additional tags; cannot replace required governance tags or Name."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.additional_tags) :
      !contains(["Project", "Environment", "ManagedBy", "Owner", "CostCenter", "Name"], key)
    ])
    error_message = "additional_tags cannot override required governance tags or Name."
  }
}

locals {
  base_tags = merge(var.additional_tags, var.tags)
}
