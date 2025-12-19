output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca_data" {
  value     = module.eks.cluster_ca_data
  sensitive = true
}

output "argocd_server_service" {
  value = {
    name      = module.argocd.argocd_server_service_name
    namespace = module.argocd.argocd_namespace
  }
}

output "argocd_username" {
  value       = module.argocd.argocd_username
  description = "ArgoCD admin username"
}

output "argocd_password" {
  value       = module.argocd.argocd_password
  description = "ArgoCD admin password"
}

output "argocd_server_url" {
  value       = module.argocd.argocd_server_url
  description = "ArgoCD server LoadBalancer URL"
}
