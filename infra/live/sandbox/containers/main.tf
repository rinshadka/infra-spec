module "repository" {
  source = "../../../modules/ecr-repository"

  environment     = var.environment
  name            = var.service_name
  kms_key_arn     = var.compute_kms_key_arn
  tags            = local.tags
  additional_tags = var.additional_tags
}

module "cluster" {
  source = "../../../modules/ecs-cluster"

  environment     = var.environment
  name            = "apps"
  log_kms_key_arn = var.log_kms_key_arn
  tags            = local.tags
  additional_tags = var.additional_tags
  default_capacity_provider_strategy = var.use_fargate_spot ? [
    { capacity_provider = "FARGATE_SPOT", weight = 1, base = 0 },
    ] : [
    { capacity_provider = "FARGATE", weight = 1, base = 1 },
  ]
}

module "service" {
  source = "../../../modules/ecs-service"

  environment        = var.environment
  name               = var.service_name
  cluster_arn        = module.cluster.cluster_arn
  cluster_name       = module.cluster.cluster_name
  subnet_ids         = var.application_subnet_ids
  security_group_ids = [var.application_security_group_id]
  image              = startswith(var.image_tag_or_digest, "@") ? "${module.repository.repository_url}${var.image_tag_or_digest}" : "${module.repository.repository_url}:${var.image_tag_or_digest}"
  container_port     = var.container_port
  target_group_arn   = var.target_group_arn
  desired_count      = var.autoscaling.min_capacity
  autoscaling        = var.autoscaling
  log_kms_key_arn    = var.log_kms_key_arn
  alarm_topic_arn    = var.alarm_topic_arn
  tags               = local.tags
  additional_tags    = var.additional_tags
}
