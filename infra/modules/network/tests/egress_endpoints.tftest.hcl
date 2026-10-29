mock_provider "aws" {}

variables {
  environment             = "sandbox"
  ipam_approval_reference = "IPAM-TEST-001"
  vpc_cidr_block          = "10.40.0.0/16"
  availability_zone_ids   = ["use1-az1", "use1-az2"]
  subnet_cidrs_by_az = {
    "use1-az1" = {
      public      = "10.40.1.0/24"
      application = "10.40.2.0/24"
      data        = "10.40.3.0/24"
    }
    "use1-az2" = {
      public      = "10.40.4.0/24"
      application = "10.40.5.0/24"
      data        = "10.40.6.0/24"
    }
  }
  endpoint_configs          = {}
  allowed_flows             = []
  allowed_egress              = []
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

run "disabled_nat_has_no_gateway_routes_or_alarms" {
  command = plan

  variables {
    nat_mode            = "disabled"
    nat_alarm_topic_arn = null
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0
    error_message = "NAT-disabled mode must not create a NAT gateway."
  }

  assert {
    condition     = length(aws_route.private_application_to_nat) == 0 && length(aws_route.private_data_to_nat) == 0
    error_message = "NAT-disabled mode must not create private NAT routes."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.nat_error_port_allocation) == 0 && length(aws_cloudwatch_metric_alarm.nat_dropped_packet_ratio) == 0
    error_message = "NAT-disabled mode must not create NAT alarms."
  }
}

run "shared_nat_has_one_gateway_and_routes_every_private_az" {
  command = plan

  variables {
    nat_mode            = "shared"
    nat_alarm_topic_arn = "arn:aws:sns:us-east-1:123456789012:network-alarms"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Shared NAT mode must create exactly one NAT gateway."
  }

  assert {
    condition     = length(aws_route.private_application_to_nat) == 2 && length(aws_route.private_data_to_nat) == 2
    error_message = "Shared NAT mode must route each private subnet's AZ route table through the shared gateway."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.nat_error_port_allocation) == 1 && length(aws_cloudwatch_metric_alarm.nat_dropped_packet_ratio) == 1
    error_message = "Shared NAT mode must create both required alarms for the gateway."
  }

  assert {
    condition = one(values(aws_cloudwatch_metric_alarm.nat_error_port_allocation)).threshold == 0 &&
      one(values(aws_cloudwatch_metric_alarm.nat_error_port_allocation)).statistic == "Maximum" &&
      one(values(aws_cloudwatch_metric_alarm.nat_error_port_allocation)).evaluation_periods == 3 &&
      one(values(aws_cloudwatch_metric_alarm.nat_error_port_allocation)).period == 300
    error_message = "The NAT allocation-error alarm must use Maximum >0 for three five-minute periods."
  }

  assert {
    condition = one(values(aws_cloudwatch_metric_alarm.nat_dropped_packet_ratio)).threshold == 0.01 &&
      one(values(aws_cloudwatch_metric_alarm.nat_dropped_packet_ratio)).evaluation_periods == 3 &&
      one(values(aws_cloudwatch_metric_alarm.nat_dropped_packet_ratio)).datapoints_to_alarm == 2 &&
      alltrue([for query in one(values(aws_cloudwatch_metric_alarm.nat_dropped_packet_ratio)).metric_query : query.metric[0].period == 60 if query.expression == null])
    error_message = "The NAT drop-ratio alarm must exceed 0.01 percent in two of three one-minute periods."
  }
}

run "per_az_nat_has_local_gateways_and_per_gateway_alarms" {
  command = plan

  variables {
    nat_mode            = "per_az"
    nat_alarm_topic_arn = "arn:aws:sns:us-east-1:123456789012:network-alarms"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Per-AZ NAT mode must create one NAT gateway per selected AZ ID."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.nat_error_port_allocation) == 2 && length(aws_cloudwatch_metric_alarm.nat_dropped_packet_ratio) == 2
    error_message = "Per-AZ NAT mode must create both required alarms for each gateway."
  }
}

run "declared_interface_endpoint_scopes_workload_tier" {
  command = plan

  variables {
    nat_mode = "disabled"
    endpoint_configs = {
      ssm = {
        service_name      = "com.amazonaws.us-east-1.ssm"
        type              = "interface"
        subnet_tiers      = ["application"]
        route_table_tiers = []
        workload_tiers    = ["application"]
        policy_json = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect   = "Allow"
            Action   = ["ssm:GetParameter"]
            Resource = "arn:aws:ssm:us-east-1:123456789012:parameter/example/*"
          }]
        })
      }
    }
  }

  assert {
    condition     = length(aws_vpc_endpoint.this) == 1 && one(values(aws_vpc_endpoint.this)).vpc_endpoint_type == "Interface"
    error_message = "Only the declared interface endpoint should be created with the requested type."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.endpoint_interface) == 1
    error_message = "The application tier should receive endpoint-only egress when that endpoint exists."
  }

  assert {
    condition     = length(one(values(aws_vpc_endpoint.this)).subnet_ids) == 2
    error_message = "The interface endpoint should be placed in the declared application subnet in each selected AZ."
  }
}

run "declared_gateway_endpoint_scopes_private_route_tables" {
  command = plan

  variables {
    nat_mode = "disabled"
    endpoint_configs = {
      dynamodb = {
        service_name      = "com.amazonaws.us-east-1.dynamodb"
        type              = "gateway"
        subnet_tiers      = []
        route_table_tiers = ["application"]
        workload_tiers    = ["application"]
        policy_json       = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "dynamodb:ListTables", Resource = "*" }] })
      }
    }
  }

  assert {
    condition     = length(one(values(aws_vpc_endpoint.this)).route_table_ids) == 2
    error_message = "The gateway endpoint must attach only to application route tables across the selected AZs."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.endpoint_gateway) == 1
    error_message = "Only the declared application tier should receive gateway endpoint prefix-list egress."
  }
}

run "rejects_unrestricted_egress" {
  command = plan

  variables {
    nat_mode = "disabled"
    allowed_egress = [{
      name                    = "unrestricted"
      source_tier             = "application"
      destination_cidr_blocks = ["0.0.0.0/0"]
      prefix_list_ids         = []
      protocol                = "tcp"
      from_port               = 443
      to_port                 = 443
      description             = "invalid wildcard test rule"
    }]
  }

  expect_failures = [var.allowed_egress]
}
