output "ready" {
  value       = time_sleep.wait_for_aws_lb_controller.id
  description = "Output that indicates AWS Load Balancer Controller is ready (use as dependency)"
}

output "service_account_name" {
  value       = kubernetes_service_account.aws_lb_controller.metadata[0].name
  description = "Name of the Kubernetes service account for AWS Load Balancer Controller"
}

output "namespace" {
  value       = kubernetes_service_account.aws_lb_controller.metadata[0].namespace
  description = "Namespace where AWS Load Balancer Controller is deployed"
}
