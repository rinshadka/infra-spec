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
  name                      = "orders"
  engine                    = "postgres"
  engine_version            = "17.4"
  parameter_group_family    = "postgres17"
  instance_class            = "db.t4g.micro"
  vpc_id                    = "vpc-0123456789abcdef0"
  subnet_ids                = ["subnet-aaa", "subnet-bbb"]
  client_security_group_ids = ["sg-app"]
  kms_key_arn               = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  alarm_topic_arn           = "arn:aws:sns:us-east-1:111111111111:ops"
}

run "private_encrypted_instance" {
  command = plan

  assert {
    condition     = length(aws_db_instance.this) == 1 && length(aws_rds_cluster.this) == 0
    error_message = "postgres creates a standard RDS instance."
  }
  assert {
    condition     = !aws_db_instance.this[0].publicly_accessible && aws_db_instance.this[0].storage_encrypted && aws_db_instance.this[0].manage_master_user_password
    error_message = "Private, encrypted, with a managed master secret."
  }
  assert {
    condition     = anytrue([for p in aws_db_parameter_group.this.parameter : p.name == "rds.force_ssl" && p.value == "1"])
    error_message = "TLS is enforced."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.client["sg-app"].from_port == 5432
    error_message = "Only the database port is opened to declared clients."
  }
}

run "aurora_cluster" {
  command = plan

  variables {
    engine                 = "aurora-postgresql"
    engine_version         = "16.6"
    parameter_group_family = "aurora-postgresql16"
    instance_class         = "db.r7g.large"
    aurora_instance_count  = 2
  }

  assert {
    condition     = length(aws_rds_cluster.this) == 1 && length(aws_rds_cluster_instance.this) == 2 && length(aws_db_instance.this) == 0
    error_message = "aurora engines create a cluster with the declared instance count."
  }
}

run "production_requires_multi_az" {
  command = plan

  variables {
    environment = "production"
    tags = {
      Project     = "infra-spec"
      Environment = "production"
      ManagedBy   = "Terraform"
      Owner       = "platform-test"
      CostCenter  = "test"
    }
  }

  expect_failures = [terraform_data.guardrails]
}
