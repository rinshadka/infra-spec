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

variable "domain_name" {
  description = "OpenSearch domain name (3-28 chars)."
  type        = string
}

variable "engine_version" {
  description = "Approved engine version, e.g. OpenSearch_2.19."
  type        = string
}

variable "instance_type" {
  description = "Approved data node instance type."
  type        = string
}

variable "instance_count" {
  description = "Data node count (multiple of the subnet count)."
  type        = number
}

variable "ebs_volume_size_gib" {
  description = "Storage per data node."
  type        = number
  default     = 20
}

variable "vpc_id" {
  description = "Network root output vpc_id."
  type        = string
}

variable "data_subnet_ids" {
  description = "One to three network private_data_subnet_ids."
  type        = list(string)
}

variable "client_security_group_ids" {
  description = "Client groups allowed HTTPS."
  type        = set(string)
}

variable "search_kms_key_arn" {
  description = "security-baseline data_kms_key_arns[\"search\"]."
  type        = string
}

variable "log_kms_key_arn" {
  description = "security-baseline logs_kms_key_arn."
  type        = string
}

variable "master_user_role_arn" {
  description = "IAM role mapped as fine-grained access-control master user."
  type        = string
}

variable "access_principal_arns" {
  description = "IAM principals allowed to call the domain."
  type        = set(string)
}

variable "alarm_topic_arn" {
  description = "security-baseline operations_topic_arn."
  type        = string
}
