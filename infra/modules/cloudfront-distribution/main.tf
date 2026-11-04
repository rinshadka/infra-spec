locals {
  name_prefix = "infra-spec-${var.environment}-${var.name}"

  # AWS managed policy IDs (stable, documented by CloudFront).
  cache_policy_optimized            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  cache_policy_disabled             = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  origin_request_all_viewer_no_host = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  response_headers_security         = "67f7725c-6f97-4210-82d7-5512b31e9d03"

  s3_origins    = { for id, o in var.origins : id => o if o.type == "s3" }
  default_is_s3 = var.origins[var.default_origin_id].type == "s3"
}

resource "aws_cloudfront_origin_access_control" "s3" {
  count = length(local.s3_origins) > 0 ? 1 : 0

  name                              = local.name_prefix
  description                       = "OAC for ${local.name_prefix} private S3 origins"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = local.name_prefix
  aliases             = sort(tolist(var.aliases))
  price_class         = var.price_class
  default_root_object = var.default_root_object
  web_acl_id          = var.web_acl_arn
  http_version        = "http2and3"
  is_ipv6_enabled     = true

  dynamic "origin" {
    for_each = var.origins
    content {
      origin_id                = origin.key
      domain_name              = origin.value.domain_name
      origin_path              = origin.value.origin_path
      origin_access_control_id = origin.value.type == "s3" ? aws_cloudfront_origin_access_control.s3[0].id : null

      dynamic "custom_origin_config" {
        for_each = origin.value.type == "custom" ? [1] : []
        content {
          http_port              = 80
          https_port             = 443
          origin_protocol_policy = "https-only"
          origin_ssl_protocols   = ["TLSv1.2"]
        }
      }
    }
  }

  default_cache_behavior {
    target_origin_id           = var.default_origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = local.default_is_s3 ? ["GET", "HEAD", "OPTIONS"] : ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.default_is_s3 ? local.cache_policy_optimized : local.cache_policy_disabled
    origin_request_policy_id   = local.default_is_s3 ? null : local.origin_request_all_viewer_no_host
    response_headers_policy_id = local.response_headers_security
  }

  restrictions {
    geo_restriction {
      restriction_type = length(var.geo_restriction_locations) > 0 ? "whitelist" : "none"
      locations        = sort(tolist(var.geo_restriction_locations))
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == null ? "TLSv1" : "TLSv1.2_2021"
  }

  dynamic "logging_config" {
    for_each = var.logging_bucket_domain_name == null ? [] : [1]
    content {
      bucket          = var.logging_bucket_domain_name
      include_cookies = false
      prefix          = "cloudfront/${local.name_prefix}/"
    }
  }

  lifecycle {
    precondition {
      condition     = contains(keys(var.origins), var.default_origin_id)
      error_message = "default_origin_id must name a declared origin."
    }
    precondition {
      condition     = length(var.aliases) == 0 || var.acm_certificate_arn != null
      error_message = "aliases require acm_certificate_arn from us-east-1."
    }
  }

  tags = merge(local.base_tags, {
    Name = local.name_prefix
  })
}
