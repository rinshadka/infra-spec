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
  additional_tags          = {}
  name                     = "edge"
  scope                    = "REGIONAL"
  justification            = "Public ALB serving customer traffic"
  log_kms_key_arn          = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  associated_resource_arns = ["arn:aws:elasticloadbalancing:us-east-1:111111111111:loadbalancer/app/x/y"]
}

run "managed_rules_rate_limit_and_logging" {
  command = plan

  assert {
    condition     = length(aws_wafv2_web_acl.this.rule) == 4
    error_message = "Three managed rule groups plus the rate rule are expected."
  }
  assert {
    condition     = startswith(aws_cloudwatch_log_group.this.name, "aws-waf-logs-")
    error_message = "WAF log groups must use the aws-waf-logs- prefix."
  }
  assert {
    condition     = length(aws_wafv2_web_acl_association.this) == 1
    error_message = "Regional ACLs associate declared resources."
  }
}

run "requires_justification" {
  command = plan

  variables {
    justification = " "
  }

  expect_failures = [var.justification]
}
