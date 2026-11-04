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

variable "workload_name" {
  description = "Workload served by this ingress (2-20 character slug)."
  type        = string
}

variable "vpc_id" {
  description = "Network root output vpc_id."
  type        = string
}

variable "load_balancer_subnet_ids" {
  description = "public_subnet_ids for internet-facing or private_application_subnet_ids for internal load balancers."
  type        = list(string)
}

variable "load_balancer_security_group_id" {
  description = "Network root output load_balancer_security_group_id (ingress is declared in the network root)."
  type        = string
}

variable "internal" {
  description = "Explicit exposure choice; false requires public_exposure_approval_reference."
  type        = bool
}

variable "public_exposure_approval_reference" {
  description = "Platform Network/Security approval reference for internet-facing ingress."
  type        = string
  default     = null
}

variable "access_logs_bucket" {
  description = "Existing ELB access-log bucket (required in production)."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Existing Route 53 hosted zone whose ownership is documented."
  type        = string
}

variable "domain_name" {
  description = "Workload DNS name, for example app.sandbox.example.com."
  type        = string
}

variable "target_port" {
  description = "Application container/instance port."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Target health check path."
  type        = string
  default     = "/healthz"
}

variable "enable_waf" {
  description = "Attach a regional WAF ACL to the ALB (requires waf_justification)."
  type        = bool
  default     = false
}

variable "waf_justification" {
  description = "Workload need for WAF."
  type        = string
  default     = "not-enabled"
}

variable "log_kms_key_arn" {
  description = "security-baseline logs_kms_key_arn."
  type        = string
}

variable "cdn" {
  description = "Optional CloudFront distribution for a private S3 static origin."
  type = object({
    domain_name               = string
    origin_bucket_domain_name = string
    enable_waf                = optional(bool, false)
    waf_justification         = optional(string, "not-enabled")
    us_east_1_log_kms_key_arn = optional(string)
  })
  default = null
}
