include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  name        = "telemetry-vpc-prod"
  cidr_block  = "10.0.0.0/16"
  common_tags = local.tags
}
