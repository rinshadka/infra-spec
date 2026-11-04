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

variable "instance_name" {
  description = "Instance purpose slug."
  type        = string
}

variable "ami_id" {
  description = "Approved, pinned AMI ID."
  type        = string
}

variable "instance_type" {
  description = "Approved instance type."
  type        = string
}

variable "vpc_id" {
  description = "Network root output vpc_id."
  type        = string
}

variable "subnet_id" {
  description = "One network private_application_subnet_ids entry."
  type        = string
}

variable "compute_kms_key_arn" {
  description = "security-baseline data key for EBS volumes."
  type        = string
}

variable "alarm_topic_arn" {
  description = "security-baseline operations_topic_arn."
  type        = string
}

variable "ingress_rules" {
  description = "Ingress from referenced security groups."
  type = list(object({
    name                     = string
    source_security_group_id = string
    protocol                 = string
    from_port                = number
    to_port                  = number
    description              = string
  }))
  default = []
}

variable "egress_rules" {
  description = "Explicit egress rules (one destination each, never 0.0.0.0/0)."
  type = list(object({
    name                          = string
    destination_cidr              = optional(string)
    destination_prefix_list_id    = optional(string)
    destination_security_group_id = optional(string)
    protocol                      = string
    from_port                     = number
    to_port                       = number
    description                   = string
  }))
  default = []
}
