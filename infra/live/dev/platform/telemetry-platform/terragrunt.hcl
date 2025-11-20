include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../../modules/telemetry-platform-local"
}

dependencies {
  paths = [
    "../kind-cluster",
    "../ingress-nginx",
  ]
}

inputs = {
  namespace = "telemetry"

  chart_path = "${get_terragrunt_dir()}/../../../../helm/telemetry-platform"
  
  oracle_user     = "telemetry"
  oracle_password = "telemetry_pw"
  oracle_jdbc_url = "jdbc:oracle:thin:@oracle-db.telemetry.svc.cluster.local:1521/XEPDB1"

  agent_ingest_image    = "telemetry/agent-ingest-svc:local"
  agent_ingest_replicas = 2

  device_state_image          = "telemetry/device-state-svc:local"
  device_state_replicas       = 1
  device_state_container_port = 8081
  device_state_service_port   = 8080

  ingress_host = "telemetry.internal" # or telemetry.local
}
