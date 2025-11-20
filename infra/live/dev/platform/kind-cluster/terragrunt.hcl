include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../../modules/kind-cluster-local"
}

inputs = {
  cluster_name     = "telemetry"
  kind_config_path = "${get_terragrunt_dir()}/kind-config.yaml"
}

