module "instance" {
  source = "../../../modules/ec2-instance"

  environment     = var.environment
  name            = var.instance_name
  ami_id          = var.ami_id
  instance_type   = var.instance_type
  vpc_id          = var.vpc_id
  subnet_id       = var.subnet_id
  kms_key_arn     = var.compute_kms_key_arn
  alarm_topic_arn = var.alarm_topic_arn
  ingress_rules   = var.ingress_rules
  egress_rules    = var.egress_rules
  tags            = local.tags
  additional_tags = var.additional_tags
}
