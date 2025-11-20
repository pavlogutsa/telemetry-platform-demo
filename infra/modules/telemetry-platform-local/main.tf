resource "helm_release" "telemetry_platform" {
  name             = "telemetry-platform"
  namespace        = var.namespace
  create_namespace = true

  chart = var.chart_path

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
