variable "name" {
  description = "Short instance purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "ami_id" {
  description = "Approved, explicitly pinned AMI ID. Changing it replaces the instance (immutable replacement)."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must be an AMI ID."
  }
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from the network foundation."
  type        = string
}

variable "subnet_id" {
  description = "Private application subnet ID; instances never receive public IPs."
  type        = string
}

variable "ingress_rules" {
  description = "Ingress rules from referenced security groups only."
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
  description = "Explicit egress rules to a CIDR, prefix list, or security group (exactly one per rule)."
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

  validation {
    condition = alltrue([
      for r in var.egress_rules :
      length(compact([r.destination_cidr, r.destination_prefix_list_id, r.destination_security_group_id])) == 1 &&
      r.destination_cidr != "0.0.0.0/0"
    ])
    error_message = "Each egress rule names exactly one destination and must not use 0.0.0.0/0."
  }
}

variable "kms_key_arn" {
  description = "KMS key for EBS volumes."
  type        = string
}

variable "root_volume_size_gib" {
  description = "Root volume size."
  type        = number
  default     = 30
}

variable "data_volumes" {
  description = "Additional encrypted gp3 volumes keyed by device name (for example /dev/sdf)."
  type = map(object({
    size_gib = number
    iops     = optional(number)
  }))
  default = {}
}

variable "iam_policy_json" {
  description = "Least-privilege application policy for the instance role; SSM core access is always attached."
  type        = string
  default     = null
}

variable "user_data" {
  description = "Non-secret bootstrap user data. Retrieve secrets at runtime from Secrets Manager."
  type        = string
  default     = null
}

variable "termination_protection" {
  description = "Protect against API termination."
  type        = bool
  default     = true
}

variable "alarm_topic_arn" {
  description = "Operations SNS topic for status-check alarms."
  type        = string
}

variable "backup_plan_tag" {
  description = "Value for the BackupPolicy tag selected by AWS Backup plans; null for no backup selection."
  type        = string
  default     = null
}
