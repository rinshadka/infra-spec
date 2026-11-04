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
  mock_resource "aws_acm_certificate" {
    override_during = plan
    defaults = {
      arn = "arn:aws:acm:us-east-1:111111111111:certificate/mock"
      domain_validation_options = [{
        domain_name           = "app.sandbox.example.com"
        resource_record_name  = "_mock.app.sandbox.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_mock.acm-validations.aws."
      }]
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
  hosted_zone_id  = "Z0123456789ABCDEFGHIJ"
  domain_name     = "app.sandbox.example.com"
}

run "dns_validated_certificate" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this.validation_method == "DNS"
    error_message = "Certificates use DNS validation."
  }
}

run "rejects_invalid_zone" {
  command = plan

  variables {
    hosted_zone_id = "not-a-zone"
  }

  expect_failures = [var.hosted_zone_id]
}
