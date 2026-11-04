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
  additional_tags    = {}
  name               = "api"
  cluster_arn        = "arn:aws:ecs:us-east-1:111111111111:cluster/apps"
  cluster_name       = "apps"
  subnet_ids         = ["subnet-aaa", "subnet-bbb"]
  security_group_ids = ["sg-app"]
  image              = "111111111111.dkr.ecr.us-east-1.amazonaws.com/api:1.0.0"
  container_port     = 8080
  target_group_arn   = "arn:aws:elasticloadbalancing:us-east-1:111111111111:targetgroup/app/abc"
  log_kms_key_arn    = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  alarm_topic_arn    = "arn:aws:sns:us-east-1:111111111111:ops"
}

run "private_tasks_with_rollback" {
  command = plan

  assert {
    condition     = aws_ecs_service.this.network_configuration[0].assign_public_ip == false
    error_message = "Tasks never receive public IPs."
  }
  assert {
    condition     = aws_ecs_service.this.deployment_circuit_breaker[0].enable && aws_ecs_service.this.deployment_circuit_breaker[0].rollback
    error_message = "Failed deployments roll back automatically."
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].readonlyRootFilesystem
    error_message = "Root filesystem is read-only by default."
  }
  assert {
    condition     = length(aws_iam_role_policy.task) == 0 && length(aws_iam_role_policy.exec) == 0
    error_message = "The task role has no AWS permissions unless declared."
  }
}

run "production_requires_digest" {
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

  expect_failures = [aws_ecs_task_definition.this]
}
