terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "config_path" {
  type = string
}

variable "config_context" {
  type = string
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
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
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
    ingress_class_name = "public-iks-k8s-nginx"
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
    ingress_class_name = "public-iks-k8s-nginx"
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