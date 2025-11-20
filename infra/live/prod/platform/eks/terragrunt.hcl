include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/eks"
}

dependency "vpc" {
  config_path = "../../network/vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id     = "vpc-00000000000000000"
    subnet_ids = []
  }
}

inputs = {
  cluster_name = "telemetry-eks-prod"
  vpc_id       = dependency.vpc.outputs.vpc_id
  subnet_ids   = dependency.vpc.outputs.subnet_ids
  common_tags  = local.tags
}
