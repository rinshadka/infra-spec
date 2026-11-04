data "aws_partition" "current" {}

locals {
  cluster_name = "infra-spec-${var.environment}-${var.name}"
  partition    = data.aws_partition.current.partition

  # Add-ons that schedule pods need nodes first.
  pre_node_addons  = { for k, v in var.addons : k => v if contains(["vpc-cni", "kube-proxy", "eks-pod-identity-agent"], k) }
  post_node_addons = { for k, v in var.addons : k => v if !contains(keys(local.pre_node_addons), k) }
}

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.cluster_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json

  tags = merge(local.base_tags, {
    Name = "${local.cluster_name}-cluster"
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn

  tags = merge(local.base_tags, {
    Name = local.cluster_name
  })
}

resource "aws_eks_cluster" "this" {
  name                          = local.cluster_name
  version                       = var.kubernetes_version
  role_arn                      = aws_iam_role.cluster.arn
  enabled_cluster_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  bootstrap_self_managed_addons = false

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = var.additional_security_group_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? sort(tolist(var.public_access_cidrs)) : null
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.secrets_kms_key_arn
    }
  }

  upgrade_policy {
    support_type = var.upgrade_support_type
  }

  lifecycle {
    precondition {
      condition     = !var.endpoint_public_access || length(var.public_access_cidrs) > 0
      error_message = "A public API endpoint requires explicit public_access_cidrs."
    }
  }

  tags = merge(local.base_tags, {
    Name = local.cluster_name
  })

  depends_on = [aws_iam_role_policy_attachment.cluster, aws_cloudwatch_log_group.cluster]
}

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  type          = "STANDARD"

  tags = merge(local.base_tags, {
    Name = "${local.cluster_name}-${each.key}"
  })
}

resource "aws_eks_access_policy_association" "this" {
  for_each = var.access_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.this[each.key].principal_arn
  policy_arn    = "arn:${local.partition}:eks::aws:cluster-access-policy/${each.value.policy_name}"

  access_scope {
    type       = length(each.value.namespaces) > 0 ? "namespace" : "cluster"
    namespaces = length(each.value.namespaces) > 0 ? sort(tolist(each.value.namespaces)) : null
  }
}

resource "aws_eks_addon" "pre_node" {
  for_each = local.pre_node_addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = each.value.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.base_tags, {
    Name = "${local.cluster_name}-${each.key}"
  })
}

resource "aws_eks_addon" "post_node" {
  for_each = local.post_node_addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = each.value.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.base_tags, {
    Name = "${local.cluster_name}-${each.key}"
  })

  depends_on = [aws_eks_node_group.this]
}
