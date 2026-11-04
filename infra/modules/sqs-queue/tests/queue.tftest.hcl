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
  name            = "orders"
  kms_key_arn     = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  alarm_topic_arn = "arn:aws:sns:us-east-1:111111111111:ops"
}

run "dlq_encryption_and_alarms" {
  command = plan

  assert {
    condition     = aws_sqs_queue.this.kms_master_key_id == var.kms_key_arn && aws_sqs_queue.dlq.kms_master_key_id == var.kms_key_arn
    error_message = "Queues are KMS encrypted."
  }
  assert {
    condition     = aws_sqs_queue.dlq.message_retention_seconds == 1209600
    error_message = "DLQ retains messages for 14 days."
  }
  assert {
    condition     = aws_cloudwatch_metric_alarm.dlq_messages.threshold == 0
    error_message = "Any DLQ message raises an alarm."
  }
}

run "fifo_names" {
  command = plan

  variables {
    fifo = true
  }

  assert {
    condition     = endswith(aws_sqs_queue.this.name, ".fifo") && endswith(aws_sqs_queue.dlq.name, "-dlq.fifo")
    error_message = "FIFO queues use the .fifo suffix."
  }
}
