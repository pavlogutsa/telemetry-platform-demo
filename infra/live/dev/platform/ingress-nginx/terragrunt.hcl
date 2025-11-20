include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../../modules/ingress-nginx-local"
}

# Make sure cluster exists before installing ingress-nginx
dependencies {
  paths = ["../kind-cluster"]
}

