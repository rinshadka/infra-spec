variable "hosted_zone_id" {
  description = "Existing Route 53 hosted zone ID whose ownership is documented for this environment."
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.hosted_zone_id))
    error_message = "hosted_zone_id must be a Route 53 hosted zone ID."
  }
}

variable "domain_name" {
  description = "Primary certificate domain name. For CloudFront, instantiate this module with a us-east-1 provider."
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional names on the certificate."
  type        = set(string)
  default     = []
}

variable "alias_records" {
  description = "Alias A records keyed by name pointing at load balancers or CloudFront."
  type = map(object({
    record_name            = string
    target_dns_name        = string
    target_zone_id         = string
    evaluate_target_health = optional(bool, true)
  }))
  default = {}
}
