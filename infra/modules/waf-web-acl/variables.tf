variable "name" {
  description = "Short web ACL purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "scope" {
  description = "REGIONAL (ALB/API) or CLOUDFRONT (requires a us-east-1 provider)."
  type        = string

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "justification" {
  description = "Workload need for WAF recorded for review (the catalogue adds WAF only when justified)."
  type        = string

  validation {
    condition     = length(trimspace(var.justification)) > 0
    error_message = "justification is required."
  }
}

variable "managed_rule_groups" {
  description = "AWS managed rule groups evaluated in list order."
  type        = list(string)
  default     = ["AWSManagedRulesAmazonIpReputationList", "AWSManagedRulesCommonRuleSet", "AWSManagedRulesKnownBadInputsRuleSet"]
}

variable "rate_limit_per_5_minutes" {
  description = "Per-source-IP request limit per five minutes; null disables the rate rule."
  type        = number
  default     = 2000
}

variable "log_retention_days" {
  description = "CloudWatch retention for WAF logs."
  type        = number
  default     = 90
}

variable "log_kms_key_arn" {
  description = "KMS key for the WAF log group (security-baseline logs key)."
  type        = string
}

variable "associated_resource_arns" {
  description = "Regional resource ARNs (for example ALBs) to associate. CloudFront associates via its web_acl_id."
  type        = set(string)
  default     = []
}
