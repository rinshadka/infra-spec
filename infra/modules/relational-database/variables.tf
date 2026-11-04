variable "name" {
  description = "Short database purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "engine" {
  description = "postgres or mysql (standard RDS instance) or aurora-postgresql or aurora-mysql (Aurora cluster)."
  type        = string

  validation {
    condition     = contains(["postgres", "mysql", "aurora-postgresql", "aurora-mysql"], var.engine)
    error_message = "engine must be postgres, mysql, aurora-postgresql, or aurora-mysql."
  }
}

variable "engine_version" {
  description = "Explicit engine version. Minor auto-upgrades are enabled; major upgrades are deliberate changes."
  type        = string
}

variable "parameter_group_family" {
  description = "Parameter group family matching engine_version (for example postgres17, aurora-postgresql16)."
  type        = string
}

variable "instance_class" {
  description = "DB instance class (for example db.t4g.medium, db.r7g.large)."
  type        = string
}

variable "allocated_storage_gib" {
  description = "Initial storage for standard RDS instances (ignored for Aurora)."
  type        = number
  default     = 20
}

variable "max_allocated_storage_gib" {
  description = "Storage autoscaling ceiling for standard RDS instances."
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Standard RDS Multi-AZ standby. Production should be true."
  type        = bool
  default     = false
}

variable "aurora_instance_count" {
  description = "Aurora instances (writer plus readers). Production should be at least 2 for cross-AZ failover."
  type        = number
  default     = 1

  validation {
    condition     = var.aurora_instance_count >= 1 && var.aurora_instance_count <= 15
    error_message = "aurora_instance_count must be 1-15."
  }
}

variable "vpc_id" {
  description = "VPC ID from the network foundation."
  type        = string
}

variable "subnet_ids" {
  description = "Private data subnet IDs in at least two AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "DB subnet groups require at least two AZs."
  }
}

variable "client_security_group_ids" {
  description = "Security groups allowed to connect on the database port; paired egress rules are created."
  type        = set(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key for storage, Performance Insights, and the managed master secret."
  type        = string
}

variable "master_username" {
  description = "Master username; the password is generated and rotated in Secrets Manager by RDS."
  type        = string
  default     = "dbadmin"
}

variable "database_name" {
  description = "Initial database name, or null."
  type        = string
  default     = null
}

variable "backup_retention_days" {
  description = "Automated backup / point-in-time recovery retention."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be 1-35."
  }
}

variable "backup_window" {
  description = "Daily UTC backup window."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly UTC maintenance window."
  type        = string
  default     = "sun:04:30-sun:05:30"
}

variable "deletion_protection" {
  description = "Protect against deletion."
  type        = bool
  default     = true
}

variable "parameters" {
  description = "Extra DB parameters; TLS enforcement parameters are always added."
  type = map(object({
    value        = string
    apply_method = optional(string, "pending-reboot")
  }))
  default = {}
}

variable "alarm_topic_arn" {
  description = "Operations SNS topic for database alarms."
  type        = string
}

variable "cpu_alarm_threshold_percent" {
  description = "CPU utilisation alarm threshold."
  type        = number
  default     = 80
}
