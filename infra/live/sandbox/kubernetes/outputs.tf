output "cluster_name" {
  description = "EKS cluster name (aws eks update-kubeconfig --name)."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Private Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Cluster security group; reference it in data-tier client_security_group_ids."
  value       = module.eks.cluster_security_group_id
}

output "kubernetes_version" {
  description = "Control-plane version."
  value       = module.eks.kubernetes_version
}
