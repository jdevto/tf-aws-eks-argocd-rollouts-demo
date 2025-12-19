output "argocd_namespace" {
  value = var.namespace
}

output "argocd_server_service_name" {
  value = "argocd-server"
}

output "argocd_username" {
  value       = "admin"
  description = "ArgoCD admin username"
}

output "argocd_password" {
  value       = try(nonsensitive(base64decode(data.kubernetes_secret.argocd_admin.data["password"])), null)
  sensitive   = false
  description = "ArgoCD admin password"
}

output "argocd_server_url" {
  value = try(
    length(data.kubernetes_ingress_v1.argocd_server.status[0].load_balancer[0].ingress) > 0 ? (
      try(
        "http://${data.kubernetes_ingress_v1.argocd_server.status[0].load_balancer[0].ingress[0].hostname}",
        "http://${data.kubernetes_ingress_v1.argocd_server.status[0].load_balancer[0].ingress[0].ip}"
      )
    ) : null,
    null
  )
  description = "ArgoCD server ALB URL (HTTP, insecure mode enabled)"
}
