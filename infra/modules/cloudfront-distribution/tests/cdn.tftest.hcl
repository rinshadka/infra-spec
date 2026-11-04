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
  additional_tags   = {}
  name              = "site"
  default_origin_id = "site"
  origins = {
    site = { type = "s3", domain_name = "bucket.s3.us-east-1.amazonaws.com" }
  }
}

run "oac_and_https_only" {
  command = plan

  assert {
    condition     = length(aws_cloudfront_origin_access_control.s3) == 1 && aws_cloudfront_origin_access_control.s3[0].signing_behavior == "always"
    error_message = "S3 origins use signed Origin Access Control."
  }
  assert {
    condition     = one(aws_cloudfront_distribution.this.default_cache_behavior).viewer_protocol_policy == "redirect-to-https"
    error_message = "Viewers are redirected to HTTPS."
  }
}

run "aliases_require_certificate" {
  command = plan

  variables {
    aliases = ["www.example.com"]
  }

  expect_failures = [aws_cloudfront_distribution.this]
}
