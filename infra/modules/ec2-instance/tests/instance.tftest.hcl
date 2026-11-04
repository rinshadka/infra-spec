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
  name            = "batch"
  ami_id          = "ami-0123456789abcdef0"
  instance_type   = "t3.micro"
  vpc_id          = "vpc-0123456789abcdef0"
  subnet_id       = "subnet-aaa"
  kms_key_arn     = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  alarm_topic_arn = "arn:aws:sns:us-east-1:111111111111:ops"
}

run "hardened_private_instance" {
  command = plan

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required" && !aws_instance.this.associate_public_ip_address
    error_message = "IMDSv2 is required and no public IP is assigned."
  }
  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted
    error_message = "Root volume is encrypted."
  }
  assert {
    condition     = length(aws_security_group.this.egress) == 0 && length(aws_vpc_security_group_egress_rule.this) == 0
    error_message = "Egress is default-deny."
  }
}

run "rejects_universal_egress" {
  command = plan

  variables {
    egress_rules = [{ name = "any", destination_cidr = "0.0.0.0/0", protocol = "tcp", from_port = 443, to_port = 443, description = "bad" }]
  }

  expect_failures = [var.egress_rules]
}
