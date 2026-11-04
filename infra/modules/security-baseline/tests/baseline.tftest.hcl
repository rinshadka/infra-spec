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
  additional_tags  = {}
  operations_owner = "platform-ops"
  data_kms_keys = {
    rds = { description = "Relational data", service_principals = ["rds.amazonaws.com"] }
  }
  secret_containers = {
    "app/api-key" = { description = "Partner API key", kms_key = "rds" }
  }
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = aws_kms_key.logs.enable_key_rotation && alltrue([for k in values(aws_kms_key.data) : k.enable_key_rotation])
    error_message = "All customer-managed keys must rotate."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.audit.block_public_policy && aws_s3_bucket_public_access_block.audit.restrict_public_buckets
    error_message = "The audit bucket must block public access."
  }
  assert {
    condition     = aws_cloudtrail.audit[0].is_multi_region_trail && aws_cloudtrail.audit[0].enable_log_file_validation
    error_message = "The trail must be multi-Region with log file validation."
  }
  assert {
    condition     = length(aws_config_configuration_recorder.this) == 1 && length(aws_securityhub_account.this) == 1
    error_message = "Config and Security Hub are enabled by default."
  }
  assert {
    condition     = alltrue([for s in values(aws_secretsmanager_secret.this) : s.recovery_window_in_days >= 7])
    error_message = "Secret containers keep a recovery window."
  }
}

run "organization_managed_services_can_be_disabled" {
  command = plan

  variables {
    enable_cloudtrail   = false
    enable_config       = false
    enable_security_hub = false
  }

  assert {
    condition     = length(aws_cloudtrail.audit) == 0 && length(aws_config_configuration_recorder.this) == 0 && length(aws_securityhub_account.this) == 0
    error_message = "Organization-managed controls must not be duplicated."
  }
}

run "rejects_short_audit_retention" {
  command = plan

  variables {
    audit_log_retention_days = 30
  }

  expect_failures = [var.audit_log_retention_days]
}
