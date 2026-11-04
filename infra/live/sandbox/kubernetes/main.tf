module "eks" {
  source = "../../../modules/eks-cluster"

  environment             = var.environment
  name                    = "platform"
  kubernetes_version      = var.kubernetes_version
  subnet_ids              = var.application_subnet_ids
  secrets_kms_key_arn     = var.compute_kms_key_arn
  node_volume_kms_key_arn = var.compute_kms_key_arn
  log_kms_key_arn         = var.log_kms_key_arn
  access_entries          = var.access_entries
  node_groups             = var.node_groups
  tags                    = local.tags
  additional_tags         = var.additional_tags
}
