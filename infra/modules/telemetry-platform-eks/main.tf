# TODO: configure auth (IRSA / aws-iam-authenticator / exec)
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_data)
  token                  = "" # TODO
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_data)
    token                  = "" # TODO
  }
}

resource "helm_release" "telemetry_platform" {
  name             = "telemetry-platform"
  namespace        = var.namespace
  create_namespace = true

  chart = "${path.module}/../../helm/telemetry-platform"

  values = [
    yamlencode({
      global = {
        namespace = var.namespace
        oracle = {
          password = var.oracle_password
          user     = var.oracle_user
          jdbc_url = var.oracle_jdbc_url
        }
      }
      "agent-ingest-svc" = {
        image    = var.agent_ingest_image
        replicas = var.agent_ingest_replicas
      }
      "device-state-svc" = {
        image         = var.device_state_image
        replicas      = var.device_state_replicas
        containerPort = var.device_state_container_port
        servicePort   = var.device_state_service_port
      }
      ingress = {
        host = var.ingress_host
      }
    })
  ]
}
