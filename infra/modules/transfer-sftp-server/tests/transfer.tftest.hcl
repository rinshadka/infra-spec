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
  additional_tags      = {}
  name                 = "partners"
  internet_facing      = false
  vpc_id               = "vpc-0123456789abcdef0"
  subnet_ids           = ["subnet-aaa", "subnet-bbb"]
  allowed_source_cidrs = ["10.20.0.0/16"]
  log_kms_key_arn      = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  users = {
    acme = {
      bucket_name     = "infra-spec-sandbox-transfer"
      home_prefix     = "partners/acme"
      kms_key_arn     = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
      ssh_public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyOnly acme"]
    }
  }
}

run "private_sftp_with_chrooted_user" {
  command = plan

  assert {
    condition     = aws_transfer_server.this.endpoint_type == "VPC" && aws_transfer_server.this.protocols == toset(["SFTP"]) && length(aws_eip.this) == 0
    error_message = "Private VPC endpoint, SFTP only, no Elastic IPs."
  }
  assert {
    condition     = aws_transfer_user.this["acme"].home_directory_type == "LOGICAL"
    error_message = "Users are chrooted with logical home directories."
  }
}

run "internet_facing_requires_approval" {
  command = plan

  variables {
    internet_facing = true
  }

  expect_failures = [aws_transfer_server.this]
}

run "rejects_open_source_range" {
  command = plan

  variables {
    allowed_source_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.allowed_source_cidrs]
}
