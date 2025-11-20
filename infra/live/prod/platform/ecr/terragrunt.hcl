include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/ecr"
}

inputs = {
  repositories = [
    "telemetry/agent-ingest-svc",
    "telemetry/device-state-svc",
  ]
  common_tags = local.tags
}
