terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

module "ingress" {
  source = "./modules/nginx-ingress"
  config_path = var.config_path
  config_context = var.config_context
}

provider "kubernetes" {
  config_path    = var.config_path
  config_context = var.config_context
}

locals {
    apps_data = jsondecode(file("${path.module}/application.json"))
    apps = { for record in local.apps_data.applications : record.name => record }
    port = 80
}

resource "kubernetes_deployment" "blue_green" {
  for_each = local.apps
  metadata {
    name = "${each.value.name}-deployment"
    labels = {
      app = "${each.value.name}-app"
    }
  }

  spec {
    replicas = each.value.replicas
    selector {
      match_labels = {
        app = "${each.value.name}-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "${each.value.name}-app"
        }
      }
      spec {
        container {
          image = each.value.image
          name  = "${each.value.name}"
          args = ["-listen=:${each.value.port}", "-text=${each.value.text}"]

          port {
            container_port = each.value.port
          }

          resources {
            limits = {
              cpu    = each.value.resources.limits.cpu
              memory = each.value.resources.limits.memory
            }
            requests = {
              cpu    = each.value.resources.requests.cpu
              memory = each.value.resources.requests.memory
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "blue_green_service" {
  for_each = local.apps
  metadata {
    name = "${each.value.name}-svc"
  }
  spec {
    selector = {
      app = "${each.value.name}-app"
    }
    port {
      port        = local.port
      target_port = each.value.port
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "blue_green_ingress" {
  for_each = { for record in local.apps : record.name => record if lookup(record, "weight", null) == null }
  metadata {
    name = "${each.value.name}-ingress"
  }

  spec {
    rule {
      host = each.value.host
      http {
        path {
            backend {
                service {
                    name = "${each.value.name}-svc"
                    port {
                        number = local.port
                    }
                } 
            }   
            path = "/"
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "blue_green_ingress_canary" {
  for_each = { for record in local.apps : record.name => record if lookup(record, "weight", null) != null }
  metadata {
    name = "${each.value.name}-ingress"
    annotations = {
        "nginx.ingress.kubernetes.io/canary" = "true"
        "nginx.ingress.kubernetes.io/canary-weight" = each.value.weight
    }
  }

  spec {
    rule {
      host = each.value.host
      http {
        path {
            backend {
                service {
                    name = "${each.value.name}-svc"
                    port {
                        number = local.port
                    }
                } 
            }   
            path = "/"
        }
      }
    }
  }
}