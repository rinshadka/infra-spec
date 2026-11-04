mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
      name   = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111111111111"
    }
  }
}

variables {
  environment = "sandbox"
  tags = {
    Project     = "infra-spec"
    Environment = "sandbox"
    ManagedBy   = "Terraform"
    Owner       = "platform-test"
    CostCenter  = "test"
  }
  additional_tags    = {}
  name               = "web"
  load_balancer_type = "application"
  internal           = true
  vpc_id             = "vpc-0123456789abcdef0"
  subnet_ids         = ["subnet-aaa", "subnet-bbb"]
  security_group_ids = ["sg-lb"]
  target_groups = {
    app = { port = 8080, protocol = "HTTP", health_check = { path = "/healthz" } }
  }
  listeners = {
    https = { port = 443, protocol = "HTTPS", certificate_arn = "arn:aws:acm:us-east-1:111111111111:certificate/abc", default_action = "forward", target_group_key = "app" }
  }
}

run "internal_alb_defaults" {
  command = plan

  assert {
    condition     = aws_lb.this.internal && aws_lb.this.drop_invalid_header_fields && aws_lb.this.enable_deletion_protection
    error_message = "Internal ALB must drop invalid headers and be deletion protected."
  }
  assert {
    condition     = aws_lb_listener.this["https"].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "HTTPS listeners use the TLS 1.2+/1.3 policy."
  }
}

run "public_requires_approval" {
  command = plan

  variables {
    internal = false
  }

  expect_failures = [aws_lb.this]
}

run "public_http_must_redirect" {
  command = plan

  variables {
    internal                           = false
    public_exposure_approval_reference = "NETSEC-123"
    listeners = {
      http = { port = 80, protocol = "HTTP", default_action = "forward", target_group_key = "app" }
    }
  }

  expect_failures = [aws_lb.this]
}

run "https_requires_certificate" {
  command = plan

  variables {
    listeners = {
      https = { port = 443, protocol = "HTTPS", default_action = "fixed_404" }
    }
  }

  expect_failures = [var.listeners]
}
