locals {
  lb_name        = "${var.environment}-${var.name}"
  is_application = var.load_balancer_type == "application"
}

resource "aws_lb" "this" {
  name                             = local.lb_name
  load_balancer_type               = var.load_balancer_type
  internal                         = var.internal
  subnets                          = var.subnet_ids
  security_groups                  = var.security_group_ids
  enable_deletion_protection       = var.deletion_protection
  drop_invalid_header_fields       = local.is_application ? true : null
  idle_timeout                     = local.is_application ? var.idle_timeout : null
  enable_cross_zone_load_balancing = local.is_application ? null : true

  dynamic "access_logs" {
    for_each = var.access_logs_bucket == null ? [] : [1]
    content {
      bucket  = var.access_logs_bucket
      prefix  = "lb/${local.lb_name}"
      enabled = true
    }
  }

  lifecycle {
    precondition {
      condition     = var.internal || try(length(trimspace(var.public_exposure_approval_reference)) > 0, false)
      error_message = "Internet-facing load balancers require public_exposure_approval_reference."
    }
    precondition {
      condition     = var.environment != "production" || var.access_logs_bucket != null
      error_message = "Production load balancers require access_logs_bucket."
    }
    precondition {
      condition = alltrue([
        for l in values(var.listeners) :
        local.is_application ? contains(["HTTP", "HTTPS"], l.protocol) : contains(["TCP", "TLS", "UDP", "TCP_UDP"], l.protocol)
      ])
      error_message = "Application load balancers use HTTP/HTTPS listeners; network load balancers use TCP/TLS/UDP listeners."
    }
    precondition {
      condition = var.internal || !local.is_application || alltrue([
        for l in values(var.listeners) : l.protocol != "HTTP" || l.default_action == "redirect_https"
      ])
      error_message = "HTTP listeners on internet-facing ALBs must redirect to HTTPS."
    }
  }

  tags = merge(local.base_tags, {
    Name              = local.lb_name
    ApprovalReference = coalesce(var.public_exposure_approval_reference, "internal")
  })
}

resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name                 = substr("${local.lb_name}-${each.key}", 0, 32)
  port                 = each.value.port
  protocol             = each.value.protocol
  target_type          = each.value.target_type
  vpc_id               = var.vpc_id
  deregistration_delay = each.value.deregistration_delay

  health_check {
    enabled             = true
    path                = contains(["HTTP", "HTTPS"], coalesce(each.value.health_check.protocol, each.value.protocol)) ? each.value.health_check.path : null
    matcher             = contains(["HTTP", "HTTPS"], coalesce(each.value.health_check.protocol, each.value.protocol)) ? each.value.health_check.matcher : null
    port                = each.value.health_check.port
    protocol            = coalesce(each.value.health_check.protocol, each.value.protocol == "UDP" ? "TCP" : each.value.protocol)
    interval            = each.value.health_check.interval
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
  }

  tags = merge(local.base_tags, {
    Name = "${local.lb_name}-${each.key}"
  })
}

resource "aws_lb_listener" "this" {
  for_each = var.listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol
  certificate_arn   = each.value.certificate_arn
  ssl_policy        = contains(["HTTPS", "TLS"], each.value.protocol) ? each.value.ssl_policy : null

  default_action {
    type             = each.value.default_action == "redirect_https" ? "redirect" : (each.value.default_action == "fixed_404" ? "fixed-response" : "forward")
    target_group_arn = each.value.default_action == "forward" ? aws_lb_target_group.this[each.value.target_group_key].arn : null

    dynamic "redirect" {
      for_each = each.value.default_action == "redirect_https" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "fixed_response" {
      for_each = each.value.default_action == "fixed_404" ? [1] : []
      content {
        content_type = "text/plain"
        message_body = "Not found"
        status_code  = "404"
      }
    }
  }

  tags = merge(local.base_tags, {
    Name = "${local.lb_name}-${each.key}"
  })
}

resource "aws_lb_listener_rule" "this" {
  for_each = local.is_application ? var.listener_rules : {}

  listener_arn = aws_lb_listener.this[each.value.listener_key].arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.target_group_key].arn
  }

  dynamic "condition" {
    for_each = length(each.value.host_headers) > 0 ? [1] : []
    content {
      host_header {
        values = each.value.host_headers
      }
    }
  }

  dynamic "condition" {
    for_each = length(each.value.path_patterns) > 0 ? [1] : []
    content {
      path_pattern {
        values = each.value.path_patterns
      }
    }
  }

  tags = merge(local.base_tags, {
    Name = "${local.lb_name}-${each.key}"
  })
}
