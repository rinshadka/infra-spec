locals {
  alarm_dimensions = local.is_aurora ? { DBClusterIdentifier = local.identifier } : { DBInstanceIdentifier = local.identifier }
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${local.identifier}-cpu-high"
  alarm_description   = "Database CPU above ${var.cpu_alarm_threshold_percent}% for 15 minutes."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cpu_alarm_threshold_percent
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]
  dimensions          = local.alarm_dimensions

  tags = merge(local.base_tags, {
    Name = "${local.identifier}-cpu-high"
  })

  depends_on = [aws_db_instance.this, aws_rds_cluster.this]
}

resource "aws_cloudwatch_metric_alarm" "free_storage" {
  count = local.is_aurora ? 0 : 1

  alarm_name          = "${local.identifier}-free-storage-low"
  alarm_description   = "Free storage below 10% of allocated storage."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = var.allocated_storage_gib * 1073741824 * 0.1
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]
  dimensions          = local.alarm_dimensions

  tags = merge(local.base_tags, {
    Name = "${local.identifier}-free-storage-low"
  })

  depends_on = [aws_db_instance.this]
}
