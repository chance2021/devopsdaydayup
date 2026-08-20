resource "helm_release" "argocd" {
  name = "argocd"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"

  namespace        = "argocd"
  create_namespace = true
}

resource "helm_release" "argo_rollouts" {
  name = "argo-rollouts"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"

  namespace        = "argo-rollouts"
  create_namespace = true
}
