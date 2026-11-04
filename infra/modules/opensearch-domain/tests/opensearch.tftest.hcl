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
  additional_tags       = {}
  domain_name           = "sbx-search"
  engine_version        = "OpenSearch_2.19"
  instance_type         = "t3.small.search"
  instance_count        = 2
  vpc_id                = "vpc-0123456789abcdef0"
  subnet_ids            = ["subnet-aaa", "subnet-bbb"]
  kms_key_arn           = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  log_kms_key_arn       = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  master_user_role_arn  = "arn:aws:iam::111111111111:role/SearchAdmin"
  access_principal_arns = ["arn:aws:iam::111111111111:role/SearchAdmin"]
  alarm_topic_arn       = "arn:aws:sns:us-east-1:111111111111:ops"
}

run "private_encrypted_fgac" {
  command = plan

  assert {
    condition     = aws_opensearch_domain.this.encrypt_at_rest[0].enabled && aws_opensearch_domain.this.node_to_node_encryption[0].enabled && aws_opensearch_domain.this.domain_endpoint_options[0].enforce_https
    error_message = "Encryption at rest, node-to-node, and HTTPS are required."
  }
  assert {
    condition     = aws_opensearch_domain.this.advanced_security_options[0].enabled && !aws_opensearch_domain.this.advanced_security_options[0].internal_user_database_enabled
    error_message = "Fine-grained access control uses IAM, not internal users."
  }
  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].zone_awareness_enabled
    error_message = "Two subnets enable zone awareness."
  }
}

run "instance_count_must_match_zones" {
  command = plan

  variables {
    instance_count = 3
  }

  expect_failures = [aws_opensearch_domain.this]
}
