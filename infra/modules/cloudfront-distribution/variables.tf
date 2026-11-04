variable "name" {
  description = "Short distribution purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "origins" {
  description = "Origins keyed by ID. s3 origins use Origin Access Control; custom origins are HTTPS-only (for example an ALB)."
  type = map(object({
    type        = string
    domain_name = string
    origin_path = optional(string, "")
  }))

  validation {
    condition     = length(var.origins) > 0 && alltrue([for o in values(var.origins) : contains(["s3", "custom"], o.type)])
    error_message = "Declare at least one origin with type s3 or custom."
  }
}

variable "default_origin_id" {
  description = "Origin key served by the default cache behaviour."
  type        = string
}

variable "aliases" {
  description = "Alternate domain names; require acm_certificate_arn issued in us-east-1."
  type        = set(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "us-east-1 ACM certificate ARN for aliases; null uses the CloudFront default certificate."
  type        = string
  default     = null
}

variable "web_acl_arn" {
  description = "Optional CLOUDFRONT-scope WAF web ACL ARN."
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "default_root_object" {
  description = "Object returned for the root URL."
  type        = string
  default     = "index.html"
}

variable "geo_restriction_locations" {
  description = "ISO country codes allowed (whitelist); empty disables geo restriction."
  type        = set(string)
  default     = []
}

variable "logging_bucket_domain_name" {
  description = "Standard-logging bucket domain (ACL-enabled bucket); null disables standard logs (record the exception)."
  type        = string
  default     = null
}
