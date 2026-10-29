module "network" {
  source = "../../../modules/network"

  environment              = var.environment
  ipam_approval_reference  = var.ipam_approval_reference
  vpc_cidr_block           = var.vpc_cidr_block
  availability_zone_ids    = var.availability_zone_ids
  subnet_cidrs_by_az       = var.subnet_cidrs_by_az
  nat_mode                 = var.nat_mode
  endpoint_configs         = var.endpoint_configs
  allowed_flows            = var.allowed_flows
  public_lb_ingress        = var.public_lb_ingress
  allowed_egress           = var.allowed_egress
  flow_log_destination_arn = var.flow_log_destination_arn
  flow_log_operations_owner = var.flow_log_operations_owner
  nat_alarm_topic_arn      = var.nat_alarm_topic_arn

  tags = {
    Project     = "infra-spec"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }

  additional_tags = var.additional_tags
}
