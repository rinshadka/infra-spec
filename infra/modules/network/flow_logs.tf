resource "aws_flow_log" "all_traffic" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = var.flow_log_destination_arn

  tags = merge(local.base_tags, {
    Name            = "${local.name_prefix}-all-traffic-flow-logs"
    OperationsOwner = var.flow_log_operations_owner
  })
}
