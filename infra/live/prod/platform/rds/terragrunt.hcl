include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/rds"
}

dependency "vpc" {
  config_path = "../../network/vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = []
    vpc_cidr_block     = "10.0.0.0/16"
  }
}

inputs = {
  identifier = "telemetry-db-prod"

  db_name        = "telemetry_prod"
  instance_class = "db.t4g.medium"
  engine         = "oracle-se2"  # or "postgres" etc
  # engine_version = "..."       # optionally override for non-Oracle engines

  username = "telemetry"
  password = "CHANGE_ME_STRONG_SECRET"

  vpc_id         = dependency.vpc.outputs.vpc_id
  vpc_cidr_block = dependency.vpc.outputs.vpc_cidr_block
  subnet_ids     = dependency.vpc.outputs.private_subnet_ids

  common_tags = local.tags
}
