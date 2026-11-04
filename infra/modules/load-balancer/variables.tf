variable "name" {
  description = "Short workload name; combined with environment it must fit the 32-character load-balancer limit."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.name))
    error_message = "name must be a 2-20 character lowercase slug."
  }
}

variable "load_balancer_type" {
  description = "application (HTTP/HTTPS routing) or network (Layer 4 / static IP)."
  type        = string

  validation {
    condition     = contains(["application", "network"], var.load_balancer_type)
    error_message = "load_balancer_type must be application or network."
  }
}

variable "internal" {
  description = "Explicit exposure choice. No default: false creates an internet-facing load balancer and requires approval evidence."
  type        = bool
}

variable "public_exposure_approval_reference" {
  description = "Platform Network/Security approval reference; required when internal is false."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID from the network foundation."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs for internet-facing, or private application subnet IDs for internal load balancers."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Load balancers require subnets in at least two AZs."
  }
}

variable "security_group_ids" {
  description = "Security groups for the load balancer (normally the network load_balancer_security_group_id)."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) >= 1
    error_message = "At least one security group is required; ingress is declared in the network module."
  }
}

variable "access_logs_bucket" {
  description = "Existing access-log bucket name; required in production."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Protect the load balancer from deletion."
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "ALB idle timeout in seconds."
  type        = number
  default     = 60
}

variable "target_groups" {
  description = "Target groups keyed by name."
  type = map(object({
    port                 = number
    protocol             = string
    target_type          = optional(string, "ip")
    deregistration_delay = optional(number, 30)
    health_check = optional(object({
      path                = optional(string, "/")
      matcher             = optional(string, "200-399")
      port                = optional(string, "traffic-port")
      protocol            = optional(string)
      interval            = optional(number, 30)
      healthy_threshold   = optional(number, 3)
      unhealthy_threshold = optional(number, 3)
    }), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, tg in var.target_groups :
      can(regex("^[a-z][a-z0-9-]{0,14}$", name)) &&
      contains(["HTTP", "HTTPS", "TCP", "TLS", "UDP", "TCP_UDP"], tg.protocol) &&
      contains(["ip", "instance", "alb"], tg.target_type) &&
      tg.port >= 1 && tg.port <= 65535
    ])
    error_message = "Target group names are 1-15 character slugs with a valid protocol, target type (ip, instance, alb), and port."
  }
}

variable "listeners" {
  description = "Listeners keyed by name. HTTP listeners on internet-facing ALBs may only redirect to HTTPS."
  type = map(object({
    port             = number
    protocol         = string
    certificate_arn  = optional(string)
    ssl_policy       = optional(string, "ELBSecurityPolicy-TLS13-1-2-2021-06")
    default_action   = string
    target_group_key = optional(string)
  }))

  validation {
    condition = alltrue([
      for name, l in var.listeners :
      contains(["HTTP", "HTTPS", "TCP", "TLS", "UDP", "TCP_UDP"], l.protocol) &&
      contains(["forward", "redirect_https", "fixed_404"], l.default_action) &&
      (!contains(["HTTPS", "TLS"], l.protocol) || l.certificate_arn != null) &&
      (l.default_action != "forward" || l.target_group_key != null)
    ])
    error_message = "Listeners need a valid protocol and default_action (forward, redirect_https, fixed_404); HTTPS/TLS listeners need certificate_arn; forward needs target_group_key."
  }
}

variable "listener_rules" {
  description = "ALB host/path routing rules keyed by name."
  type = map(object({
    listener_key     = string
    priority         = number
    host_headers     = optional(list(string), [])
    path_patterns    = optional(list(string), [])
    target_group_key = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, r in var.listener_rules :
      r.priority >= 1 && r.priority <= 50000 && length(r.host_headers) + length(r.path_patterns) > 0
    ])
    error_message = "Rules need a priority from 1 to 50000 and at least one host header or path pattern."
  }
}
