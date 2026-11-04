module "certificate" {
  source = "../../../modules/dns-certificate"

  environment     = var.environment
  hosted_zone_id  = var.hosted_zone_id
  domain_name     = var.domain_name
  tags            = local.tags
  additional_tags = var.additional_tags
  alias_records = {
    app = {
      record_name     = var.domain_name
      target_dns_name = module.load_balancer.dns_name
      target_zone_id  = module.load_balancer.zone_id
    }
  }
}

module "load_balancer" {
  source = "../../../modules/load-balancer"

  environment                        = var.environment
  name                               = var.workload_name
  load_balancer_type                 = "application"
  internal                           = var.internal
  public_exposure_approval_reference = var.public_exposure_approval_reference
  vpc_id                             = var.vpc_id
  subnet_ids                         = var.load_balancer_subnet_ids
  security_group_ids                 = [var.load_balancer_security_group_id]
  access_logs_bucket                 = var.access_logs_bucket
  tags                               = local.tags
  additional_tags                    = var.additional_tags

  target_groups = {
    app = {
      port         = var.target_port
      protocol     = "HTTP"
      target_type  = "ip"
      health_check = { path = var.health_check_path }
    }
  }

  listeners = {
    http = {
      port           = 80
      protocol       = "HTTP"
      default_action = "redirect_https"
    }
    https = {
      port             = 443
      protocol         = "HTTPS"
      certificate_arn  = module.certificate.certificate_arn
      default_action   = "forward"
      target_group_key = "app"
    }
  }
}

module "waf" {
  source = "../../../modules/waf-web-acl"
  count  = var.enable_waf ? 1 : 0

  environment              = var.environment
  name                     = "${var.workload_name}-alb"
  scope                    = "REGIONAL"
  justification            = var.waf_justification
  log_kms_key_arn          = var.log_kms_key_arn
  associated_resource_arns = [module.load_balancer.load_balancer_arn]
  tags                     = local.tags
  additional_tags          = var.additional_tags
}

module "cdn_certificate" {
  source    = "../../../modules/dns-certificate"
  count     = var.cdn == null ? 0 : 1
  providers = { aws = aws.us_east_1 }

  environment     = var.environment
  hosted_zone_id  = var.hosted_zone_id
  domain_name     = var.cdn.domain_name
  tags            = local.tags
  additional_tags = var.additional_tags
}

module "cdn_waf" {
  source    = "../../../modules/waf-web-acl"
  count     = try(var.cdn.enable_waf, false) ? 1 : 0
  providers = { aws = aws.us_east_1 }

  environment     = var.environment
  name            = "${var.workload_name}-cdn"
  scope           = "CLOUDFRONT"
  justification   = var.cdn.waf_justification
  log_kms_key_arn = var.cdn.us_east_1_log_kms_key_arn
  tags            = local.tags
  additional_tags = var.additional_tags
}

module "cdn" {
  source = "../../../modules/cloudfront-distribution"
  count  = var.cdn == null ? 0 : 1

  environment         = var.environment
  name                = var.workload_name
  default_origin_id   = "static"
  aliases             = [var.cdn.domain_name]
  acm_certificate_arn = module.cdn_certificate[0].certificate_arn
  web_acl_arn         = try(module.cdn_waf[0].web_acl_arn, null)
  tags                = local.tags
  additional_tags     = var.additional_tags
  origins = {
    static = { type = "s3", domain_name = var.cdn.origin_bucket_domain_name }
  }
}

resource "aws_route53_record" "cdn" {
  count = var.cdn == null ? 0 : 1

  zone_id = var.hosted_zone_id
  name    = var.cdn.domain_name
  type    = "A"

  alias {
    name                   = module.cdn[0].domain_name
    zone_id                = module.cdn[0].hosted_zone_id
    evaluate_target_health = false
  }
}
