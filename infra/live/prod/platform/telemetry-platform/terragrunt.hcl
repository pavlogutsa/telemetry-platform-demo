include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../../modules/telemetry-platform-eks"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    cluster_name     = "mock"
    cluster_endpoint = "https://example.com"
    cluster_ca_data  = ""
  }
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    jdbc_url = "jdbc:oracle:thin:@oracle-prod.example.com:1521/XEPDB1"
    db_user  = "telemetry"
    db_pass  = "telemetry_pw"
  }
}

dependency "ecr" {
  config_path = "../ecr"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    repository_urls = {
      "telemetry/agent-ingest-svc" = "000000000000.dkr.ecr.us-east-1.amazonaws.com/telemetry/agent-ingest-svc"
      "telemetry/device-state-svc" = "000000000000.dkr.ecr.us-east-1.amazonaws.com/telemetry/device-state-svc"
    }
  }
}

inputs = {
  namespace = "telemetry"

  cluster_name     = dependency.eks.outputs.cluster_name
  cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  cluster_ca_data  = dependency.eks.outputs.cluster_ca_data

  oracle_user     = dependency.rds.outputs.db_user
  oracle_password = dependency.rds.outputs.db_pass
  oracle_jdbc_url = dependency.rds.outputs.jdbc_url

  agent_ingest_image = "${dependency.ecr.outputs.repository_urls["telemetry/agent-ingest-svc"]}:release1"
  device_state_image = "${dependency.ecr.outputs.repository_urls["telemetry/device-state-svc"]}:release1"

  agent_ingest_replicas = 2

  device_state_replicas       = 2
  device_state_container_port = 8081
  device_state_service_port   = 8080

  ingress_host = "telemetry.internal"
}
