variable "domain_name" {
  description = "Domain name (3-28 lowercase characters), for example sbx-search."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,27}$", var.domain_name))
    error_message = "domain_name must be 3-28 characters, start with a letter, and use lowercase letters, digits, or hyphens."
  }
}

variable "engine_version" {
  description = "Explicit engine version, for example OpenSearch_2.19. Upgrades are deliberate changes."
  type        = string

  validation {
    condition     = can(regex("^OpenSearch_[0-9]+\\.[0-9]+$", var.engine_version))
    error_message = "engine_version must look like OpenSearch_2.19."
  }
}

variable "instance_type" {
  description = "Data node instance type (for example r7g.large.search)."
  type        = string
}

variable "instance_count" {
  description = "Data node count; use a multiple of the AZ count when zone awareness is enabled."
  type        = number
  default     = 2
}

variable "dedicated_master" {
  description = "Dedicated cluster-manager nodes; recommended for production (count 3)."
  type = object({
    enabled       = bool
    instance_type = optional(string)
    count         = optional(number, 3)
  })
  default = { enabled = false }
}

variable "ebs_volume_size_gib" {
  description = "gp3 EBS volume size per data node."
  type        = number
  default     = 20
}

variable "vpc_id" {
  description = "VPC ID from the network foundation."
  type        = string
}

variable "subnet_ids" {
  description = "Private data subnet IDs, one per AZ used (1-3). Two or more enable zone awareness."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1 && length(var.subnet_ids) <= 3
    error_message = "Provide one to three private data subnet IDs."
  }
}

variable "client_security_group_ids" {
  description = "Security groups allowed HTTPS access; paired egress rules are created."
  type        = set(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key for encryption at rest."
  type        = string
}

variable "log_kms_key_arn" {
  description = "KMS key for OpenSearch log groups."
  type        = string
}

variable "log_retention_days" {
  description = "Log group retention."
  type        = number
  default     = 90
}

variable "master_user_role_arn" {
  description = "IAM role mapped as the fine-grained access-control master user (no internal user database)."
  type        = string
}

variable "access_principal_arns" {
  description = "IAM principals allowed to call the domain HTTP APIs; fine-grained access control further restricts them."
  type        = set(string)
}

variable "auto_tune_enabled" {
  description = "Enable Auto-Tune (not supported on t2/t3 instance types)."
  type        = bool
  default     = false
}

variable "alarm_topic_arn" {
  description = "Operations SNS topic for domain alarms."
  type        = string
}
