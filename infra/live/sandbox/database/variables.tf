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

variable "database_name" {
  description = "Database purpose slug."
  type        = string
}

variable "engine" {
  description = "postgres, mysql, aurora-postgresql, or aurora-mysql."
  type        = string
}

variable "engine_version" {
  description = "Approved engine version."
  type        = string
}

variable "parameter_group_family" {
  description = "Parameter group family matching the engine version."
  type        = string
}

variable "instance_class" {
  description = "Approved DB instance class."
  type        = string
}

variable "multi_az" {
  description = "Standard RDS Multi-AZ (required in production)."
  type        = bool
  default     = false
}

variable "aurora_instance_count" {
  description = "Aurora instance count (at least 2 in production)."
  type        = number
  default     = 1
}

variable "backup_retention_days" {
  description = "Automated backup retention."
  type        = number
  default     = 7
}

variable "vpc_id" {
  description = "Network root output vpc_id."
  type        = string
}

variable "data_subnet_ids" {
  description = "Network root output private_data_subnet_ids."
  type        = list(string)
}

variable "client_security_group_ids" {
  description = "Client groups, e.g. network application_security_group_id or an EKS cluster security group."
  type        = set(string)
}

variable "database_kms_key_arn" {
  description = "security-baseline data_kms_key_arns[\"database\"]."
  type        = string
}

variable "alarm_topic_arn" {
  description = "security-baseline operations_topic_arn."
  type        = string
}
