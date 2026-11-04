variable "name" {
  description = "Server purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "internet_facing" {
  description = "Explicit exposure choice. true attaches Elastic IPs and requires approval evidence and exact partner CIDRs."
  type        = bool
}

variable "public_exposure_approval_reference" {
  description = "Platform Network/Security approval reference; required when internet_facing is true."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID from the network foundation."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnets when internet_facing, otherwise private application subnets."
  type        = list(string)
}

variable "allowed_source_cidrs" {
  description = "Exact partner or corporate CIDRs allowed to reach TCP 22."
  type        = set(string)

  validation {
    condition     = length(var.allowed_source_cidrs) > 0 && !contains(var.allowed_source_cidrs, "0.0.0.0/0") && alltrue([for c in var.allowed_source_cidrs : can(cidrnetmask(c))])
    error_message = "allowed_source_cidrs must list exact IPv4 CIDRs and must not include 0.0.0.0/0."
  }
}

variable "security_policy_name" {
  description = "Transfer Family security policy (cipher suite set)."
  type        = string
  default     = "TransferSecurityPolicy-2024-01"
}

variable "log_kms_key_arn" {
  description = "KMS key for the structured transfer log group."
  type        = string
}

variable "log_retention_days" {
  description = "Transfer log retention."
  type        = number
  default     = 365
}

variable "users" {
  description = "Service-managed SFTP users keyed by username, each chrooted to one bucket prefix."
  type = map(object({
    bucket_name     = string
    home_prefix     = string
    kms_key_arn     = string
    read_only       = optional(bool, false)
    ssh_public_keys = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for username, u in var.users :
      can(regex("^[a-z0-9][a-z0-9_.@-]{2,99}$", username)) &&
      can(regex("^[a-z0-9][a-z0-9/_-]*[a-z0-9]$", u.home_prefix)) &&
      length(u.ssh_public_keys) >= 1 &&
      alltrue([for key in u.ssh_public_keys : can(regex("^(ssh-ed25519|ecdsa-sha2-nistp(256|384|521)|ssh-rsa) ", key))])
    ])
    error_message = "Users need a valid username, a slug home_prefix without leading/trailing slashes, and at least one SSH public key."
  }
}
