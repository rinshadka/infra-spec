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
  additional_tags     = {}
  bucket_name         = "infra-spec-sandbox-test-bucket"
  kms_key_arn         = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  data_classification = "internal"
}

run "private_encrypted_versioned" {
  command = plan

  assert {
    condition     = aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be disabled."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls && aws_s3_bucket_public_access_block.this.block_public_policy && aws_s3_bucket_public_access_block.this.ignore_public_acls && aws_s3_bucket_public_access_block.this.restrict_public_buckets
    error_message = "All public access blocks must be enabled."
  }
  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning is enabled by default."
  }
  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "SSE-KMS is required."
  }
  assert {
    condition     = aws_s3_bucket.this.tags["DataClassification"] == "internal"
    error_message = "Data classification must be tagged."
  }
}

run "production_rejects_force_destroy" {
  command = plan

  variables {
    environment   = "production"
    force_destroy = true
    tags = {
      Project     = "infra-spec"
      Environment = "production"
      ManagedBy   = "Terraform"
      Owner       = "platform-test"
      CostCenter  = "test"
    }
  }

  expect_failures = [aws_s3_bucket.this]
}
