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
  additional_tags           = {}
  name                      = "shared"
  vpc_id                    = "vpc-0123456789abcdef0"
  subnet_ids                = ["subnet-aaa", "subnet-bbb"]
  client_security_group_ids = ["sg-client"]
  kms_key_arn               = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  access_points = {
    app = { path = "/app", uid = 1000, gid = 1000 }
  }
}

run "encrypted_with_paired_nfs_rules" {
  command = plan

  assert {
    condition     = aws_efs_file_system.this.encrypted
    error_message = "EFS must be encrypted."
  }
  assert {
    condition     = length(aws_efs_mount_target.this) == 2
    error_message = "One mount target per subnet."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.nfs["sg-client"].from_port == 2049 && aws_vpc_security_group_egress_rule.client_nfs["sg-client"].to_port == 2049
    error_message = "Only paired NFS rules are created."
  }
  assert {
    condition     = length(aws_security_group.this.ingress) == 0 && length(aws_security_group.this.egress) == 0
    error_message = "No inline rules."
  }
}

run "provisioned_requires_throughput" {
  command = plan

  variables {
    throughput_mode = "provisioned"
  }

  expect_failures = [aws_efs_file_system.this]
}
