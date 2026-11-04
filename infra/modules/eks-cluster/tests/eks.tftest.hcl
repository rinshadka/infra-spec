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
  additional_tags         = {}
  name                    = "platform"
  kubernetes_version      = "1.33"
  subnet_ids              = ["subnet-aaa", "subnet-bbb"]
  secrets_kms_key_arn     = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  log_kms_key_arn         = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  node_volume_kms_key_arn = "arn:aws:kms:us-east-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  access_entries = {
    platform-admins = { principal_arn = "arn:aws:iam::111111111111:role/PlatformAdmin", policy_name = "AmazonEKSClusterAdminPolicy" }
  }
  node_groups = {
    general = { instance_types = ["m7g.large"], ami_type = "AL2023_ARM_64_STANDARD", min_size = 2, max_size = 4, desired_size = 2 }
  }
}

run "private_api_and_hardened_nodes" {
  command = plan

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_private_access && !aws_eks_cluster.this.vpc_config[0].endpoint_public_access
    error_message = "The API endpoint is private by default."
  }
  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API" && !aws_eks_cluster.this.access_config[0].bootstrap_cluster_creator_admin_permissions
    error_message = "Access is managed only through declared access entries."
  }
  assert {
    condition     = aws_launch_template.node["general"].metadata_options[0].http_tokens == "required" && aws_launch_template.node["general"].block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "Nodes require IMDSv2 and encrypted volumes."
  }
  assert {
    condition     = length(aws_eks_addon.post_node) == 1 && length(aws_eks_addon.pre_node) == 3
    error_message = "coredns waits for nodes; networking add-ons install first."
  }
}

run "public_endpoint_requires_cidrs" {
  command = plan

  variables {
    endpoint_public_access = true
  }

  expect_failures = [aws_eks_cluster.this]
}
