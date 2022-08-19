provider "helm" {
  kubernetes {
    config_path = var.config_path
    config_context = var.config_context
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
}