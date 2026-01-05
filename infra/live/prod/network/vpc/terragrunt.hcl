include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  name       = "telemetry-vpc-prod"
  cidr_block = "10.0.0.0/16"

  azs = [
    "us-east-1a",
    "us-east-1b",
  ]

  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]

  public_subnets = [
    "10.0.101.0/24",
    "10.0.102.0/24",
  ]

  common_tags = local.tags
}
