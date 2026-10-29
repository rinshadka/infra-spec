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
  nat_mode                  = "disabled"
  endpoint_configs          = {}
  allowed_flows             = []
  allowed_egress             = []
  flow_log_destination_arn  = "arn:aws:s3:::unit-test-flow-logs"
  flow_log_operations_owner = "platform-test"
  nat_alarm_topic_arn       = null
  tags = {
    Project     = "infra-spec"
    Environment = "sandbox"
    ManagedBy   = "Terraform"
    Owner       = "platform-test"
    CostCenter  = "test"
  }
  additional_tags = {}
}

run "two_az_three_tier_topology" {
  command = plan

  assert {
    condition     = length(aws_subnet.this) == 6
    error_message = "Each of two AZ IDs must have public, application, and data subnets."
  }

  assert {
    condition     = alltrue([for subnet in values(aws_subnet.this) : subnet.map_public_ip_on_launch == false])
    error_message = "No subnet may auto-assign public IPv4 addresses to workloads."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "Amazon-provided DNS resolution and hostnames must be enabled."
  }

  assert {
    condition     = aws_flow_log.this.traffic_type == "ALL"
    error_message = "Exactly one VPC flow log must capture accepted and rejected traffic."
  }

  assert {
    condition = alltrue([
      for subnet in values(aws_subnet.this) :
      subnet.tags.Project == "infra-spec" && subnet.tags.Environment == "sandbox" &&
      subnet.tags.ManagedBy == "Terraform" && subnet.tags.Owner == "platform-test" &&
      subnet.tags.CostCenter == "test" && length(trimspace(subnet.tags.Name)) > 0
    ])
    error_message = "Every subnet must carry the required governance and naming tags."
  }

  assert {
    condition     = length(aws_route.private_application_to_nat) == 0 && length(aws_route.private_data_to_nat) == 0
    error_message = "Disabled NAT mode must not create private NAT default routes."
  }
}

run "rejects_fewer_than_two_az_ids" {
  command = plan

  variables {
    availability_zone_ids = ["use1-az1"]
  }

  expect_failures = [var.availability_zone_ids]
}

run "rejects_overlapping_subnets" {
  command = plan

  variables {
    subnet_cidrs_by_az = {
      "use1-az1" = {
        public      = "10.40.1.0/24"
        application = "10.40.2.0/24"
        data        = "10.40.3.0/24"
      }
      "use1-az2" = {
        public      = "10.40.4.0/24"
        application = "10.40.2.0/24"
        data        = "10.40.6.0/24"
      }
    }
  }

  expect_failures = [aws_vpc.this]
}

run "rejects_subnets_smaller_than_aws_minimum" {
  command = plan

  variables {
    subnet_cidrs_by_az = {
      "use1-az1" = {
        public      = "10.40.1.0/29"
        application = "10.40.2.0/24"
        data        = "10.40.3.0/24"
      }
      "use1-az2" = {
        public      = "10.40.4.0/24"
        application = "10.40.5.0/24"
        data        = "10.40.6.0/24"
      }
    }
  }

  expect_failures = [var.subnet_cidrs_by_az]
}

run "rejects_subnets_outside_vpc" {
  command = plan

  variables {
    subnet_cidrs_by_az = {
      "use1-az1" = {
        public      = "10.40.1.0/24"
        application = "10.40.2.0/24"
        data        = "10.41.3.0/24"
      }
      "use1-az2" = {
        public      = "10.40.4.0/24"
        application = "10.40.5.0/24"
        data        = "10.40.6.0/24"
      }
    }
  }

  expect_failures = [aws_vpc.this]
}

run "rejects_invalid_noncanonical_subnet_cidr" {
  command = plan

  variables {
    subnet_cidrs_by_az = {
      "use1-az1" = {
        public      = "10.40.1.1/24"
        application = "10.40.2.0/24"
        data        = "10.40.3.0/24"
      }
      "use1-az2" = {
        public      = "10.40.4.0/24"
        application = "10.40.5.0/24"
        data        = "10.40.6.0/24"
      }
    }
  }

  expect_failures = [var.subnet_cidrs_by_az]
}
