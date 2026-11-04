variable "name" {
  description = "Short file-system purpose name used in resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be a 2-31 character lowercase slug."
  }
}

variable "vpc_id" {
  description = "VPC ID from the network foundation output vpc_id."
  type        = string
}

variable "subnet_ids" {
  description = "Private data subnet IDs (one per AZ) from private_data_subnet_ids."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "At least one private subnet is required; use one per selected AZ for Regional file systems."
  }
}

variable "client_security_group_ids" {
  description = "Security groups allowed to mount over NFS/TLS (TCP 2049)."
  type        = set(string)
  default     = []
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for encryption at rest."
  type        = string
}

variable "performance_mode" {
  description = "generalPurpose (default) or maxIO."
  type        = string
  default     = "generalPurpose"

  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "performance_mode must be generalPurpose or maxIO."
  }
}

variable "throughput_mode" {
  description = "elastic (default), bursting, or provisioned."
  type        = string
  default     = "elastic"

  validation {
    condition     = contains(["elastic", "bursting", "provisioned"], var.throughput_mode)
    error_message = "throughput_mode must be elastic, bursting, or provisioned."
  }
}

variable "provisioned_throughput_in_mibps" {
  description = "Required only when throughput_mode is provisioned."
  type        = number
  default     = null
}

variable "transition_to_ia" {
  description = "Lifecycle transition to Infrequent Access, or null to disable."
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "backup_enabled" {
  description = "Enable AWS Backup automatic backups for the file system."
  type        = bool
  default     = true
}

variable "access_points" {
  description = "Access points keyed by name, each enforcing a POSIX identity and root directory."
  type = map(object({
    path        = string
    uid         = number
    gid         = number
    permissions = optional(string, "0750")
  }))
  default = {}

  validation {
    condition     = alltrue([for name, ap in var.access_points : startswith(ap.path, "/") && can(regex("^[0-7]{4}$", ap.permissions))])
    error_message = "Access point paths must be absolute and permissions must be four octal digits."
  }
}
