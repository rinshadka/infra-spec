resource "aws_cloudwatch_metric_alarm" "nat_error_port_allocation" {
  for_each = aws_nat_gateway.this

  alarm_name          = "${local.name_prefix}-nat-${each.key}-error-port-allocation"
  alarm_description   = "NAT gateway port allocation errors exceeded zero for three consecutive five-minute periods."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  metric_name         = "ErrorPortAllocation"
  namespace           = "AWS/NATGateway"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.nat_alarm_topic_arn]
  ok_actions          = [var.nat_alarm_topic_arn]

  dimensions = {
    NatGatewayId = each.value.id
  }

  tags = merge(local.base_tags, {
    Name            = "${local.name_prefix}-nat-${each.key}-error-port-allocation"
    OperationsOwner = var.flow_log_operations_owner
  })
}

resource "aws_cloudwatch_metric_alarm" "nat_dropped_packet_ratio" {
  for_each = aws_nat_gateway.this

  alarm_name          = "${local.name_prefix}-nat-${each.key}-dropped-packet-ratio"
  alarm_description   = "NAT dropped packet ratio exceeded 0.01 percent in two of three one-minute periods."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 0.01
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.nat_alarm_topic_arn]
  ok_actions          = [var.nat_alarm_topic_arn]

  metric_query {
    id          = "drop_ratio"
    expression  = "IF((in_source + in_destination) > 0, (dropped / (in_source + in_destination)) * 100, 0)"
    label       = "Dropped packet ratio percent"
    return_data = true
  }

  metric_query {
    id          = "dropped"
    return_data = false

    metric {
      metric_name = "PacketsDropCount"
      namespace   = "AWS/NATGateway"
      period      = 60
      stat        = "Sum"
      dimensions  = { NatGatewayId = each.value.id }
    }
  }

  metric_query {
    id          = "in_source"
    return_data = false

    metric {
      metric_name = "PacketsInFromSource"
      namespace   = "AWS/NATGateway"
      period      = 60
      stat        = "Sum"
      dimensions  = { NatGatewayId = each.value.id }
    }
  }

  metric_query {
    id          = "in_destination"
    return_data = false

    metric {
      metric_name = "PacketsInFromDestination"
      namespace   = "AWS/NATGateway"
      period      = 60
      stat        = "Sum"
      dimensions  = { NatGatewayId = each.value.id }
    }
  }

  tags = merge(local.base_tags, {
    Name            = "${local.name_prefix}-nat-${each.key}-dropped-packet-ratio"
    OperationsOwner = var.flow_log_operations_owner
  })
}
