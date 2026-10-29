mock_provider "aws" {}

variables {
  environment             = "sandbox"
  ipam_approval_reference = "IPAM-TEST-001"
  vpc_cidr_block          = "10.40.0.0/16"
  availability_zone_ids   = ["use1-az1", "use1-az2"]
  subnet_cidrs_by_az = {
    "use1-az1" = { public = "10.40.1.0/24", application = "10.40.2.0/24", data = "10.40.3.0/24" }
    "use1-az2" = { public = "10.40.4.0/24", application = "10.40.5.0/24", data = "10.40.6.0/24" }
  }
  nat_mode                  = "disabled"
  nat_alarm_topic_arn       = null
  endpoint_configs          = {}
  allowed_egress             = []
  allowed_flows             = []
  public_lb_ingress         = []
  flow_log_destination_arn  = "arn:aws:s3:::unit-test-flow-logs"
  flow_log_operations_owner = "platform-test"
  tags = {
    Project     = "infra-spec"
    Environment = "sandbox"
    ManagedBy   = "Terraform"
    Owner       = "platform-test"
    CostCenter  = "test"
  }
  additional_tags = {}
}

run "default_deny_and_consumer_outputs" {
  command = plan

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.tier_flow) == 0 && length(aws_vpc_security_group_egress_rule.tier_flow) == 0
    error_message = "No tier flow rules may exist without an explicit declaration."
  }

  assert {
    condition     = alltrue([for group in values(aws_security_group.workload) : length(group.ingress) == 0 && length(group.egress) == 0])
    error_message = "Tier security groups must have no inline/default ingress or egress rules."
  }

  assert {
    condition     = output.application_security_group_id != "" && output.data_security_group_id != "" && output.load_balancer_security_group_id != ""
    error_message = "Application, data, and load-balancer consumer security-group outputs must be present."
  }

  assert {
    condition     = aws_flow_log.all_traffic.traffic_type == "ALL" && aws_flow_log.all_traffic.log_destination == "arn:aws:s3:::unit-test-flow-logs"
    error_message = "All-traffic Flow Logs must target the explicitly supplied central destination."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.public_load_balancer) == 0 && length(output.public_lb_ingress_approvals) == 0
    error_message = "Public load-balancer ingress must remain absent without a reviewed declaration."
  }
}

run "declared_application_to_data_flow_is_bidirectional_stateful_pair" {
  command = plan

  variables {
    allowed_flows = [{
      name             = "app-to-db-tls"
      source_tier      = "application"
      destination_tier = "data"
      protocol         = "tcp"
      from_port        = 5432
      to_port          = 5432
      description      = "Application service access to PostgreSQL."
    }]
  }

  assert {
    condition     = one(values(aws_vpc_security_group_ingress_rule.tier_flow)).from_port == 5432 && one(values(aws_vpc_security_group_egress_rule.tier_flow)).to_port == 5432
    error_message = "The declared TCP port must appear on the scoped ingress and source egress rules."
  }

  assert {
    condition     = one(values(aws_vpc_security_group_ingress_rule.tier_flow)).description == "Application service access to PostgreSQL."
    error_message = "The flow rationale must be retained on the created rule."
  }

  assert {
    condition     = output.network_flow_rule_ids["app-to-db-tls/ingress"] != "" && output.network_flow_rule_ids["app-to-db-tls/egress"] != ""
    error_message = "Both rule IDs must be exposed for review traceability."
  }
}

run "public_load_balancer_ingress_carries_approval_and_exact_scope" {
  command = plan

  variables {
    public_lb_ingress = [{
      name               = "public-https"
      business_need      = "Serve the approved public application endpoint."
      approval_reference = "SECURITY-CHANGE-123"
      source_cidr_blocks = ["203.0.113.0/24"]
      protocol           = "tcp"
      from_port          = 443
      to_port            = 443
      description        = "Approved HTTPS client ingress."
    }]
  }

  assert {
    condition     = one(values(aws_vpc_security_group_ingress_rule.public_load_balancer)).cidr_ipv4 == "203.0.113.0/24" && one(values(aws_vpc_security_group_ingress_rule.public_load_balancer)).from_port == 443
    error_message = "The load-balancer ingress rule must use only the declared source range and port."
  }

  assert {
    condition     = output.public_lb_ingress_approvals["public-https"].approval_reference == "SECURITY-CHANGE-123"
    error_message = "The public ingress approval reference must be surfaced for review."
  }
}
