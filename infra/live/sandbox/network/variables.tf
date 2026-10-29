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
  description = "Organization team or person accountable for this network."
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

variable "ipam_approval_reference" {
  description = "IPAM allocation or approval record that reviewers verify before plan."
  type        = string

  validation {
    condition     = length(trimspace(var.ipam_approval_reference)) > 0
    error_message = "ipam_approval_reference must not be empty."
  }
}

variable "vpc_cidr_block" {
  description = "Organization-IPAM-approved canonical IPv4 VPC CIDR."
  type        = string
}

variable "availability_zone_ids" {
  description = "Explicit AZ IDs selected for this environment."
  type        = set(string)

  validation {
    condition     = length(var.availability_zone_ids) >= 2
    error_message = "At least two availability_zone_ids must be selected."
  }
}

variable "subnet_cidrs_by_az" {
  description = "IPAM-approved public, application, and data IPv4 CIDRs keyed by AZ ID."
  type = map(object({
    public      = string
    application = string
    data        = string
  }))
}

variable "nat_mode" {
  description = "Explicit private egress mode: disabled, shared, or per_az. No mode is selected by default."
  type        = string

  validation {
    condition     = contains(["disabled", "shared", "per_az"], var.nat_mode)
    error_message = "nat_mode must be disabled, shared, or per_az."
  }
}

variable "endpoint_configs" {
  description = "Workload-declared VPC endpoints; empty unless a workload requires a service."
  type = map(object({
    service_name       = string
    type               = string
    subnet_tiers       = set(string)
    route_table_tiers  = set(string)
    workload_tiers     = set(string)
    policy_json        = string
  }))
  default = {}
}

variable "allowed_flows" {
  description = "Explicit stateful workload-tier flows."
  type = list(object({
    name             = string
    source_tier      = string
    destination_tier = string
    protocol         = string
    from_port        = number
    to_port          = number
    description      = string
  }))
  default = []
}

variable "public_lb_ingress" {
  description = "Public load-balancer ingress declarations with a business need and reviewer approval reference. Empty by default."
  type = list(object({
    name               = string
    business_need      = string
    approval_reference = string
    source_cidr_blocks = set(string)
    protocol           = string
    from_port          = number
    to_port            = number
    description        = string
  }))
  default = []
}

variable "allowed_egress" {
  description = "Explicit destination-restricted workload internet egress rules."
  type = list(object({
    name                   = string
    source_tier            = string
    destination_cidr_blocks = set(string)
    prefix_list_ids        = set(string)
    protocol               = string
    from_port              = number
    to_port                = number
    description            = string
  }))
  default = []
}

variable "flow_log_destination_arn" {
  description = "Approved encrypted central S3 destination for VPC Flow Logs."
  type        = string
}

variable "flow_log_operations_owner" {
  description = "Operations team responsible for Flow Log destination and use."
  type        = string
}

variable "nat_alarm_topic_arn" {
  description = "Operations-owned SNS topic; required when NAT is enabled."
  type        = string
  default     = null

  validation {
    condition = (
      var.nat_mode == "disabled" ? var.nat_alarm_topic_arn == null :
      try(can(regex("^arn:[^:]+:sns:[^:]+:[0-9]{12}:.+", var.nat_alarm_topic_arn)), false)
    )
    error_message = "nat_alarm_topic_arn must be null when NAT is disabled and a valid SNS topic ARN when NAT is enabled."
  }
}

variable "additional_tags" {
  description = "Optional resource tags; required governance keys are set by the root and cannot be overridden."
  type        = map(string)
  default     = {}
}
