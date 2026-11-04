variable "name" {
  description = "Short cluster purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "kubernetes_version" {
  description = "Explicit EKS Kubernetes minor version (for example 1.33). No default: upgrades are deliberate."
  type        = string

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "kubernetes_version must be a minor version such as 1.33."
  }
}

variable "upgrade_support_type" {
  description = "STANDARD (default; forces upgrades at end of standard support) or EXTENDED (paid)."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXTENDED"], var.upgrade_support_type)
    error_message = "upgrade_support_type must be STANDARD or EXTENDED."
  }
}

variable "subnet_ids" {
  description = "Private application subnet IDs (at least two AZs) for control-plane ENIs and nodes."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires subnets in at least two AZs."
  }
}

variable "additional_security_group_ids" {
  description = "Extra security groups attached to control-plane ENIs (for example the network application group)."
  type        = list(string)
  default     = []
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API publicly. Default false; true requires public_access_cidrs and approval."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "Exact CIDRs allowed to reach a public API endpoint."
  type        = set(string)
  default     = []

  validation {
    condition     = !contains(var.public_access_cidrs, "0.0.0.0/0")
    error_message = "public_access_cidrs must not include 0.0.0.0/0."
  }
}

variable "secrets_kms_key_arn" {
  description = "KMS key for Kubernetes secrets envelope encryption."
  type        = string
}

variable "log_kms_key_arn" {
  description = "KMS key for the control-plane log group."
  type        = string
}

variable "log_retention_days" {
  description = "Control-plane log retention."
  type        = number
  default     = 90
}

variable "access_entries" {
  description = "Cluster access entries keyed by name. Cluster-creator admin bootstrap is disabled, so declare at least one admin."
  type = map(object({
    principal_arn = string
    policy_name   = string
    namespaces    = optional(set(string), [])
  }))

  validation {
    condition = length(var.access_entries) > 0 && alltrue([
      for e in values(var.access_entries) :
      contains(["AmazonEKSClusterAdminPolicy", "AmazonEKSAdminPolicy", "AmazonEKSEditPolicy", "AmazonEKSViewPolicy"], e.policy_name)
    ])
    error_message = "Declare at least one access entry using an AWS managed EKS access policy name."
  }
}

variable "node_groups" {
  description = "Managed node groups keyed by name."
  type = map(object({
    instance_types             = list(string)
    capacity_type              = optional(string, "ON_DEMAND")
    ami_type                   = optional(string, "AL2023_x86_64_STANDARD")
    min_size                   = number
    max_size                   = number
    desired_size               = number
    disk_size_gib              = optional(number, 50)
    max_unavailable_percentage = optional(number, 33)
    labels                     = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for ng in values(var.node_groups) :
      contains(["ON_DEMAND", "SPOT"], ng.capacity_type) &&
      ng.min_size >= 0 && ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size
    ])
    error_message = "Node groups need ON_DEMAND or SPOT capacity and min <= desired <= max."
  }
}

variable "node_volume_kms_key_arn" {
  description = "KMS key for node EBS volumes."
  type        = string
}

variable "addons" {
  description = "EKS add-ons keyed by name; null version selects the default for the cluster version at create time."
  type = map(object({
    version = optional(string)
  }))
  default = {
    "vpc-cni"                = {}
    "kube-proxy"             = {}
    "coredns"                = {}
    "eks-pod-identity-agent" = {}
  }
}
