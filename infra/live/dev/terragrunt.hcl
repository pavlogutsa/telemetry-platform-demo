locals {
  project_name = "telemetry"
  environment  = "dev"

  tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terragrunt"
  }
}

generate "providers" {
  path      = "providers.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOC
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-telemetry"  # TODO: set your kind context
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "kind-telemetry"
  }
}
EOC
}
