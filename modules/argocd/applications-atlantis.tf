# Bootstrap Argo CD Application for atlantis-demo (Blue-Green deployment)
# Why: the kubernetes provider cannot plan custom resources until the CRD exists.
# We apply the Application via kubectl after Helm installs Argo CD + CRDs.
resource "null_resource" "bootstrap_atlantis_demo_application" {
  triggers = {
    app_name        = "atlantis-demo"
    namespace       = var.namespace
    repo_url        = var.repo_url
    target_revision = var.target_revision
    app_path        = "k8s-app/atlantis-demo"
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
  ignoreDifferences:
    - group: argoproj.io
      kind: Rollout
      jsonPointers:
        - /status/conditions
    - group: networking.k8s.io
      kind: Ingress
      jsonPointers:
        - /status
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
