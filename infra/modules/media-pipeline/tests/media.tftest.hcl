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
  name               = "video"
  input_bucket_name  = "infra-spec-sandbox-media-in"
  output_bucket_name = "infra-spec-sandbox-media-out"
  kms_key_arn        = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  alarm_topic_arn    = "arn:aws:sns:us-east-1:111111111111:ops"
}

run "on_demand_queue_and_status_routing" {
  command = plan

  assert {
    condition     = aws_media_convert_queue.this.pricing_plan == "ON_DEMAND"
    error_message = "Queues are on-demand."
  }
  assert {
    condition     = length(module.submit_rule) == 0
    error_message = "No submission trigger without a workload submitter."
  }
}

run "submitter_trigger" {
  command = plan

  variables {
    submitter_lambda_arn = "arn:aws:lambda:us-east-1:111111111111:function:submit"
  }

  assert {
    condition     = length(module.submit_rule) == 1
    error_message = "A declared submitter gets an S3 object-created rule."
  }
}
