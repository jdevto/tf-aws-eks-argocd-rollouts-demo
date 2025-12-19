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
          hostname         = "" # Empty hostname to accept any host header
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

# Bootstrap only the Argo CD Application CR (no Terraform k8s resource).
# Why: the kubernetes provider cannot plan custom resources until the CRD exists.
# We apply the Application via kubectl after Helm installs Argo CD + CRDs.
resource "null_resource" "bootstrap_application" {
  triggers = {
    app_name        = "nginx-demo"
    namespace       = var.namespace
    repo_url        = var.repo_url
    target_revision = var.target_revision
    app_path        = "k8s-app/nginx-demo"
    cluster_name    = var.cluster_name
    aws_region      = var.aws_region
    kubeconfig_path = "${path.root}/.terraform-kubeconfig-${var.cluster_name}"
  }

  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      KCFG="${self.triggers.kubeconfig_path}"
      aws eks update-kubeconfig --region "${self.triggers.aws_region}" --name "${self.triggers.cluster_name}" --kubeconfig "$KCFG" >/dev/null
      export KUBECONFIG="$KCFG"

      # Wait until the Application CRD is established/recognized by the API server
      kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=180s

      cat <<'YAML' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${self.triggers.app_name}
  namespace: ${self.triggers.namespace}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: "${self.triggers.repo_url}"
    targetRevision: "${self.triggers.target_revision}"
    path: "${self.triggers.app_path}"
  destination:
    server: "https://kubernetes.default.svc"
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
YAML
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      KCFG="${self.triggers.kubeconfig_path}"
      aws eks update-kubeconfig --region "${self.triggers.aws_region}" --name "${self.triggers.cluster_name}" --kubeconfig "$KCFG" >/dev/null || exit 0
      export KUBECONFIG="$KCFG"

      kubectl delete -n "${self.triggers.namespace}" application "${self.triggers.app_name}" --ignore-not-found --wait=true || true
    EOT
  }
}

# Bootstrap a second Argo CD Application for go-demo
resource "null_resource" "bootstrap_go_demo_application" {
  triggers = {
    app_name        = "go-demo"
    namespace       = var.namespace
    repo_url        = var.repo_url
    target_revision = var.target_revision
    app_path        = "k8s-app/go-demo"
    cluster_name    = var.cluster_name
    aws_region      = var.aws_region
    kubeconfig_path = "${path.root}/.terraform-kubeconfig-${var.cluster_name}"
  }

  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      KCFG="${self.triggers.kubeconfig_path}"
      aws eks update-kubeconfig --region "${self.triggers.aws_region}" --name "${self.triggers.cluster_name}" --kubeconfig "$KCFG" >/dev/null
      export KUBECONFIG="$KCFG"

      # Wait until the Application CRD is established/recognized by the API server
      kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=180s

      cat <<'YAML' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${self.triggers.app_name}
  namespace: ${self.triggers.namespace}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: "${self.triggers.repo_url}"
    targetRevision: "${self.triggers.target_revision}"
    path: "${self.triggers.app_path}"
  destination:
    server: "https://kubernetes.default.svc"
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
YAML
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      KCFG="${self.triggers.kubeconfig_path}"
      aws eks update-kubeconfig --region "${self.triggers.aws_region}" --name "${self.triggers.cluster_name}" --kubeconfig "$KCFG" >/dev/null || exit 0
      export KUBECONFIG="$KCFG"

      kubectl delete -n "${self.triggers.namespace}" application "${self.triggers.app_name}" --ignore-not-found --wait=true || true
    EOT
  }
}
