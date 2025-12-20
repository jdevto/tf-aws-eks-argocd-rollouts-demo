resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version

  wait = true

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"          = "ip"
            "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}]"
            "alb.ingress.kubernetes.io/subnets"              = join(",", var.subnet_ids)
            "alb.ingress.kubernetes.io/backend-protocol"     = "HTTP"
            "alb.ingress.kubernetes.io/healthcheck-path"     = "/healthz"
            "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
            "alb.ingress.kubernetes.io/healthcheck-port"     = "traffic-port"
          }
        }
        insecure = true # Enable insecure mode for HTTP ingress
      }
      configs = {
        params = {
          "application.types" = "rollout.argoproj.io"
          "server.insecure"   = "true"
        }
        resourceCustomizations = {
          "argoproj.io/Rollout" = {
            health = {
              lua = <<-EOT
                hs = {}
                if obj.status ~= nil then
                  if obj.status.phase ~= nil and obj.status.phase == "Healthy" then
                    hs.status = "Healthy"
                    hs.message = "Rollout is healthy"
                    return hs
                  end
                  if obj.status.conditions ~= nil then
                    for i, condition in ipairs(obj.status.conditions) do
                      if condition.type == "Healthy" and condition.status == "True" then
                        hs.status = "Healthy"
                        hs.message = condition.message
                        return hs
                      end
                      if condition.type == "Completed" and condition.status == "True" then
                        hs.status = "Healthy"
                        hs.message = "Rollout completed"
                        return hs
                      end
                    end
                  end
                end
                hs.status = "Progressing"
                hs.message = "Rollout is progressing"
                return hs
              EOT
            }
          }
        }
      }
    })
  ]
}

# Read the ArgoCD admin credentials from the Kubernetes secret
data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.namespace
  }

  depends_on = [helm_release.argocd]
}

# Get the ArgoCD server Ingress to retrieve the ALB endpoint
data "kubernetes_ingress_v1" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = var.namespace
  }

  depends_on = [helm_release.argocd]
}

# Install Argo Rollouts controller
resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  version          = var.rollouts_chart_version

  wait = true

  depends_on = [helm_release.argocd]
}
