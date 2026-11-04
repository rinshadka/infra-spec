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
  name            = "processor"
  description     = "Processes order events"
  runtime         = "python3.13"
  handler         = "app.handler"
  package         = { s3_bucket = "artifacts", s3_key = "processor/1.0.0.zip" }
  kms_key_arn     = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  alarm_topic_arn = "arn:aws:sns:us-east-1:111111111111:ops"
  sqs_event_source = {
    queue_arn = "arn:aws:sqs:us-east-1:111111111111:orders"
  }
}

run "traced_partial_batch_consumer" {
  command = plan

  assert {
    condition     = aws_lambda_function.this.tracing_config[0].mode == "Active"
    error_message = "X-Ray tracing is active."
  }
  assert {
    condition     = contains(aws_lambda_event_source_mapping.sqs[0].function_response_types, "ReportBatchItemFailures")
    error_message = "SQS consumers report partial batch failures."
  }
}

run "package_source_is_exclusive" {
  command = plan

  variables {
    package = { s3_bucket = "artifacts", s3_key = "x.zip", filename = "x.zip" }
  }

  expect_failures = [var.package]
}
