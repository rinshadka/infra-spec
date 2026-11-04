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

variable "server_name" {
  description = "Server purpose slug."
  type        = string
}

variable "internet_facing" {
  description = "Explicit exposure choice; true requires approval evidence."
  type        = bool
}

variable "public_exposure_approval_reference" {
  description = "Platform Network/Security approval reference for internet-facing endpoints."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "Network root output vpc_id."
  type        = string
}

variable "subnet_ids" {
  description = "public_subnet_ids if internet_facing, otherwise private_application_subnet_ids."
  type        = list(string)
}

variable "allowed_source_cidrs" {
  description = "Exact partner/corporate CIDRs for TCP 22."
  type        = set(string)
}

variable "log_kms_key_arn" {
  description = "security-baseline logs_kms_key_arn."
  type        = string
}

variable "users" {
  description = "SFTP users chrooted to one bucket prefix each (bucket from the storage root)."
  type = map(object({
    bucket_name     = string
    home_prefix     = string
    kms_key_arn     = string
    read_only       = optional(bool, false)
    ssh_public_keys = list(string)
  }))
  default = {}
}
