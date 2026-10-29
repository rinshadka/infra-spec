variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string

  validation {
    condition     = contains(["sandbox", "development", "staging", "production"], var.environment)
    error_message = "environment must be sandbox, development, staging, or production."
  }
}

variable "ipam_approval_reference" {
  description = "IPAM allocation or approval reference recorded for reviewer verification."
  type        = string

  validation {
    condition     = length(trimspace(var.ipam_approval_reference)) > 0
    error_message = "ipam_approval_reference must contain the approved IPAM allocation or ticket reference."
  }
}

variable "vpc_cidr_block" {
  description = "Canonical IPv4 CIDR allocated and approved by organization IPAM."
  type        = string

  validation {
    condition = try(
      can(cidrnetmask(var.vpc_cidr_block)) &&
      tonumber(split("/", var.vpc_cidr_block)[1]) >= 16 &&
      tonumber(split("/", var.vpc_cidr_block)[1]) <= 28 &&
      cidrhost(var.vpc_cidr_block, 0) == split("/", var.vpc_cidr_block)[0],
      false
    )
    error_message = "vpc_cidr_block must be a canonical IPv4 CIDR between /16 and /28."
  }
}

variable "availability_zone_ids" {
  description = "Explicit AWS Availability Zone IDs selected for this environment."
  type        = set(string)

  validation {
    condition = length(var.availability_zone_ids) >= 2 && alltrue([
      for az_id in var.availability_zone_ids : can(regex("^[a-z0-9-]+-az[0-9]+$", az_id))
    ])
    error_message = "availability_zone_ids must contain at least two valid AZ IDs."
  }
}

variable "subnet_cidrs_by_az" {
  description = "IPAM-approved public, application, and data IPv4 CIDRs keyed by AZ ID."
  type = map(object({
    public      = string
    application = string
    data        = string
  }))

  validation {
    condition = (
      length(setsubtract(toset(keys(var.subnet_cidrs_by_az)), var.availability_zone_ids)) == 0 &&
      length(setsubtract(var.availability_zone_ids, toset(keys(var.subnet_cidrs_by_az)))) == 0 &&
      alltrue(flatten([
        for tiers in values(var.subnet_cidrs_by_az) : [
          for cidr in values(tiers) :
          try(can(cidrnetmask(cidr)) && cidrhost(cidr, 0) == split("/", cidr)[0] && tonumber(split("/", cidr)[1]) >= 16 && tonumber(split("/", cidr)[1]) <= 28, false)
        ]
      ]))
    )
    error_message = "Each selected AZ ID must have public, application, and data subnets with canonical IPv4 CIDRs between /16 and /28."
  }
}

variable "flow_log_destination_arn" {
  description = "Approved central S3 destination ARN for all-traffic VPC Flow Logs."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:s3:::.+", var.flow_log_destination_arn))
    error_message = "flow_log_destination_arn must be an S3 bucket or object-prefix ARN."
  }
}

variable "flow_log_operations_owner" {
  description = "Operations team accountable for Flow Log access, retention, and use."
  type        = string

  validation {
    condition     = length(trimspace(var.flow_log_operations_owner)) > 0
    error_message = "flow_log_operations_owner must not be empty."
  }
}

variable "tags" {
  description = "Required governance tags supplied by the environment root."
  type = object({
    Project     = string
    Environment = string
    ManagedBy   = string
    Owner       = string
    CostCenter  = string
  })

  validation {
    condition = (
      alltrue([for value in values(var.tags) : length(trimspace(value)) > 0]) &&
      var.tags.Project == "infra-spec" &&
      var.tags.ManagedBy == "Terraform" &&
      var.tags.Environment == var.environment
    )
    error_message = "Required governance tags must be non-empty, Project must be infra-spec, ManagedBy must be Terraform, and Environment must match the environment input."
  }
}

variable "additional_tags" {
  description = "Optional additional tags; cannot replace required governance tags or Name."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.additional_tags) :
      !contains(["Project", "Environment", "ManagedBy", "Owner", "CostCenter", "Name"], key)
    ])
    error_message = "additional_tags cannot override required governance tags or Name."
  }
}

variable "nat_mode" {
  description = "Private IPv4 egress topology: disabled, shared, or per_az. No default is intentional."
  type        = string

  validation {
    condition     = contains(["disabled", "shared", "per_az"], var.nat_mode)
    error_message = "nat_mode must be disabled, shared, or per_az."
  }
}

variable "nat_alarm_topic_arn" {
  description = "Operations SNS topic for NAT alarms; required whenever NAT is enabled."
  type        = string
  default     = null

  validation {
    condition = (
      var.nat_mode == "disabled" ? var.nat_alarm_topic_arn == null :
      var.nat_alarm_topic_arn != null && can(regex("^arn:[^:]+:sns:[^:]+:[0-9]{12}:.+$", var.nat_alarm_topic_arn))
    )
    error_message = "NAT modes require a valid SNS topic ARN; disabled mode must not configure one."
  }
}

variable "endpoint_configs" {
  description = "Explicit VPC endpoints keyed by short stable name; each endpoint requires reviewed least-privilege policy JSON."
  type = map(object({
    service_name      = string
    type              = string
    subnet_tiers      = set(string)
    route_table_tiers = set(string)
    workload_tiers    = set(string)
    policy_json       = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, endpoint in var.endpoint_configs :
      can(regex("^[a-z0-9][a-z0-9-]{0,62}$", name)) &&
      length(trimspace(endpoint.service_name)) > 0 &&
      contains(["interface", "gateway"], endpoint.type) &&
      alltrue([for tier in endpoint.subnet_tiers : contains(["application", "data"], tier)]) &&
      alltrue([for tier in endpoint.route_table_tiers : contains(["application", "data"], tier)]) &&
      alltrue([for tier in endpoint.workload_tiers : contains(["application", "data"], tier)]) &&
      length(endpoint.workload_tiers) > 0 &&
      (endpoint.type == "interface" ? length(endpoint.subnet_tiers) == 1 && length(endpoint.route_table_tiers) == 0 : length(endpoint.route_table_tiers) > 0 && length(endpoint.subnet_tiers) == 0 && can(regex("\\.(s3|dynamodb)$", endpoint.service_name))) &&
      endpoint.policy_json != null && can(jsondecode(endpoint.policy_json))
    ]) && length(distinct([for endpoint in values(var.endpoint_configs) : endpoint.service_name])) == length(var.endpoint_configs)
    error_message = "Endpoints need unique services, a valid name/service/type, eligible scope (one subnet tier per interface endpoint or private route tables for gateway endpoints), workload tiers, and valid reviewed policy JSON."
  }
}

variable "allowed_egress" {
  description = "Explicit workload security-group egress destinations; unrestricted CIDRs are prohibited."
  type = list(object({
    name                    = string
    source_tier             = string
    destination_cidr_blocks = optional(set(string), [])
    prefix_list_ids         = optional(set(string), [])
    protocol                = string
    from_port               = number
    to_port                 = number
    description             = string
  }))
  default = []

  validation {
    condition = (
      length(distinct([for rule in var.allowed_egress : rule.name])) == length(var.allowed_egress) &&
      alltrue([
        for rule in var.allowed_egress :
        can(regex("^[a-z0-9][a-z0-9-]{0,62}$", rule.name)) &&
        contains(["application", "data"], rule.source_tier) &&
        contains(["tcp", "udp"], rule.protocol) &&
        rule.from_port >= 1 && rule.from_port <= rule.to_port && rule.to_port <= 65535 &&
        length(trimspace(rule.description)) > 0 &&
        (length(rule.destination_cidr_blocks) + length(rule.prefix_list_ids) > 0) &&
        alltrue([for cidr in rule.destination_cidr_blocks : can(cidrnetmask(cidr)) && try(cidrhost(cidr, 0) == split("/", cidr)[0], false) && cidr != "0.0.0.0/0"]) &&
        alltrue([for prefix_list_id in rule.prefix_list_ids : can(regex("^pl-[0-9a-f]+$", prefix_list_id))])
      ])
    )
    error_message = "Egress rules must be unique, scoped to application/data, use TCP/UDP and valid ports, include a destination and rationale, and exclude universal CIDRs."
  }
}

variable "allowed_flows" {
  description = "Explicit stateful flows between load-balancer, application, and data security groups."
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

  validation {
    condition = (
      length(distinct([for flow in var.allowed_flows : flow.name])) == length(var.allowed_flows) &&
      alltrue([
        for flow in var.allowed_flows :
        can(regex("^[a-z0-9][a-z0-9-]{0,62}$", flow.name)) &&
        contains(["load_balancer", "application", "data"], flow.source_tier) &&
        contains(["load_balancer", "application", "data"], flow.destination_tier) &&
        flow.source_tier != flow.destination_tier &&
        contains(["tcp", "udp"], flow.protocol) &&
        flow.from_port >= 1 && flow.from_port <= flow.to_port && flow.to_port <= 65535 &&
        length(trimspace(flow.description)) > 0
      ])
    )
    error_message = "Flows must be unique and describe distinct valid tiers, TCP/UDP port ranges, and rationale."
  }
}

variable "public_lb_ingress" {
  description = "Explicit workload-owned public load-balancer ingress with reviewer-verifiable approval evidence."
  type = list(object({
    name              = string
    business_need     = string
    approval_reference = string
    source_cidr_blocks = set(string)
    protocol          = string
    from_port         = number
    to_port           = number
    description       = string
  }))
  default = []

  validation {
    condition = (
      length(distinct([for rule in var.public_lb_ingress : rule.name])) == length(var.public_lb_ingress) &&
      alltrue([
        for rule in var.public_lb_ingress :
        can(regex("^[a-z0-9][a-z0-9-]{0,62}$", rule.name)) &&
        length(trimspace(rule.business_need)) > 0 &&
        length(trimspace(rule.approval_reference)) > 0 &&
        length(rule.source_cidr_blocks) > 0 &&
        contains(["tcp", "udp"], rule.protocol) &&
        rule.from_port >= 1 && rule.from_port <= rule.to_port && rule.to_port <= 65535 &&
        length(trimspace(rule.description)) > 0 &&
        alltrue([for cidr in rule.source_cidr_blocks : can(cidrnetmask(cidr)) && try(cidrhost(cidr, 0) == split("/", cidr)[0], false)])
      ])
    )
    error_message = "Public load-balancer ingress must have a unique name, documented need and approval reference, exact canonical IPv4 source CIDRs, TCP/UDP ports, and rationale."
  }
}
