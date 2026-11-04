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
  additional_tags = {}
  name            = "orders-created"
  description     = "Route order events"
  event_pattern   = "{\"source\":[\"app.orders\"]}"
  targets = {
    fn = { arn = "arn:aws:lambda:us-east-1:111111111111:function:x", type = "lambda" }
  }
}

run "lambda_target_permission" {
  command = plan

  assert {
    condition     = length(aws_lambda_permission.this) == 1 && aws_lambda_permission.this["fn"].principal == "events.amazonaws.com"
    error_message = "Lambda targets receive a rule-scoped invoke permission."
  }
}

run "rejects_invalid_pattern" {
  command = plan

  variables {
    event_pattern = "not json"
  }

  expect_failures = [var.event_pattern]
}
