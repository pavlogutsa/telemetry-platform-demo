#!/usr/bin/env bash
set -euo pipefail

echo "Creating directories..."

mkdir -p infra/live/dev/platform/telemetry-platform
mkdir -p infra/live/prod/network/vpc
mkdir -p infra/live/prod/platform/eks
mkdir -p infra/live/prod/platform/rds
mkdir -p infra/live/prod/platform/ecr
mkdir -p infra/live/prod/platform/telemetry-platform

mkdir -p infra/modules/telemetry-platform-local
mkdir -p infra/modules/telemetry-platform-eks
mkdir -p infra/modules/vpc
mkdir -p infra/modules/eks
mkdir -p infra/modules/rds
mkdir -p infra/modules/ecr

echo "Writing infra/terragrunt.hcl..."
cat > infra/terragrunt.hcl <<'EOF'
locals {
  project_name = "telemetry"
}
EOF

echo "Writing infra/live/dev/terragrunt.hcl..."
cat > infra/live/dev/terragrunt.hcl <<'EOF'
include "root" {
  path = find_in_parent_folders()
}

locals {
  environment = "dev"

  tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terragrunt"
  }
}

# Local state is enough for dev
remote_state {
  backend = "local"
  config = {
    path = "${path_relative_to_include()}/terraform.tfstate"
  }
}

# Providers for local kind cluster
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
  config_context = "kind-telemetry"  # TODO: set your kind context name
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "kind-telemetry"
  }
}
EOC
}
EOF

echo "Writing infra/live/dev/platform/telemetry-platform/terragrunt.hcl..."
cat > infra/live/dev/platform/telemetry-platform/terragrunt.hcl <<'EOF'
include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/telemetry-platform-local"
}

inputs = {
  namespace = "telemetry"

  oracle_user     = "telemetry"
  oracle_password = "telemetry_pw"
  oracle_jdbc_url = "jdbc:oracle:thin:@oracle-db.telemetry.svc.cluster.local:1521/XEPDB1"

  agent_ingest_image    = "agent-ingest-svc:release1"
  agent_ingest_replicas = 2

  device_state_image          = "device-state-svc:release1"
  device_state_replicas       = 1
  device_state_container_port = 8081
  device_state_service_port   = 8080

  ingress_host = "telemetry.internal" # or telemetry.local
}
EOF

echo "Writing infra/live/prod/terragrunt.hcl..."
cat > infra/live/prod/terragrunt.hcl <<'EOF'
include "root" {
  path = find_in_parent_folders()
}

locals {
  environment = "prod"

  tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terragrunt"
  }
}

remote_state {
  backend = "s3"
  config = {
    bucket         = "telemetry-terraform-state"    # TODO: create this bucket
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "telemetry-terraform-locks"    # TODO: create this table
  }
}

generate "providers" {
  path      = "providers.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOC
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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

provider "aws" {
  region = "us-east-1"
}
EOC
}
EOF

echo "Writing infra/live/prod/network/vpc/terragrunt.hcl..."
cat > infra/live/prod/network/vpc/terragrunt.hcl <<'EOF'
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
EOF

echo "Writing infra/live/prod/platform/eks/terragrunt.hcl..."
cat > infra/live/prod/platform/eks/terragrunt.hcl <<'EOF'
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
EOF

echo "Writing infra/live/prod/platform/rds/terragrunt.hcl..."
cat > infra/live/prod/platform/rds/terragrunt.hcl <<'EOF'
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
  }
}

inputs = {
  db_name        = "telemetry_prod"
  instance_class = "db.t4g.medium"
  engine         = "oracle-se2"  # or postgres if you switch
  vpc_id         = dependency.vpc.outputs.vpc_id
  subnet_ids     = dependency.vpc.outputs.private_subnet_ids
  common_tags    = local.tags
}
EOF

echo "Writing infra/live/prod/platform/ecr/terragrunt.hcl..."
cat > infra/live/prod/platform/ecr/terragrunt.hcl <<'EOF'
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
EOF

echo "Writing infra/live/prod/platform/telemetry-platform/terragrunt.hcl..."
cat > infra/live/prod/platform/telemetry-platform/terragrunt.hcl <<'EOF'
include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../../modules/telemetry-platform-eks"
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
EOF

echo "Writing infra/modules/telemetry-platform-local/variables.tf..."
cat > infra/modules/telemetry-platform-local/variables.tf <<'EOF'
variable "namespace" {
  type    = string
  default = "telemetry"
}

variable "oracle_user" {
  type = string
}

variable "oracle_password" {
  type = string
}

variable "oracle_jdbc_url" {
  type = string
}

variable "agent_ingest_image" {
  type = string
}

variable "agent_ingest_replicas" {
  type    = number
  default = 2
}

variable "device_state_image" {
  type = string
}

variable "device_state_replicas" {
  type    = number
  default = 1
}

variable "device_state_container_port" {
  type    = number
  default = 8081
}

variable "device_state_service_port" {
  type    = number
  default = 8080
}

variable "ingress_host" {
  type    = string
  default = "telemetry.internal"
}
EOF

echo "Writing infra/modules/telemetry-platform-local/main.tf..."
cat > infra/modules/telemetry-platform-local/main.tf <<'EOF'
terraform {
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

resource "helm_release" "telemetry_platform" {
  name             = "telemetry-platform"
  namespace        = var.namespace
  create_namespace = true

  # Module path -> repo root -> helm/telemetry-platform
  chart = "${path.module}/../../helm/telemetry-platform"

  values = [
    yamlencode({
      global = {
        namespace = var.namespace
        oracle = {
          password = var.oracle_password
          user     = var.oracle_user
          jdbc_url = var.oracle_jdbc_url
        }
      }
      "agent-ingest-svc" = {
        image    = var.agent_ingest_image
        replicas = var.agent_ingest_replicas
      }
      "device-state-svc" = {
        image         = var.device_state_image
        replicas      = var.device_state_replicas
        containerPort = var.device_state_container_port
        servicePort   = var.device_state_service_port
      }
      ingress = {
        host = var.ingress_host
      }
    })
  ]
}
EOF

echo "Writing infra/modules/telemetry-platform-eks/variables.tf..."
cat > infra/modules/telemetry-platform-eks/variables.tf <<'EOF'
variable "namespace" {
  type    = string
  default = "telemetry"
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_ca_data" {
  type = string
}

variable "oracle_user" {
  type = string
}

variable "oracle_password" {
  type = string
}

variable "oracle_jdbc_url" {
  type = string
}

variable "agent_ingest_image" {
  type = string
}

variable "agent_ingest_replicas" {
  type    = number
  default = 2
}

variable "device_state_image" {
  type = string
}

variable "device_state_replicas" {
  type    = number
  default = 1
}

variable "device_state_container_port" {
  type    = number
  default = 8081
}

variable "device_state_service_port" {
  type    = number
  default = 8080
}

variable "ingress_host" {
  type = string
}
EOF

echo "Writing infra/modules/telemetry-platform-eks/main.tf..."
cat > infra/modules/telemetry-platform-eks/main.tf <<'EOF'
terraform {
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

# TODO: configure auth (IRSA / aws-iam-authenticator / exec)
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_data)
  token                  = "" # TODO
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_data)
    token                  = "" # TODO
  }
}

resource "helm_release" "telemetry_platform" {
  name             = "telemetry-platform"
  namespace        = var.namespace
  create_namespace = true

  chart = "${path.module}/../../helm/telemetry-platform"

  values = [
    yamlencode({
      global = {
        namespace = var.namespace
        oracle = {
          password = var.oracle_password
          user     = var.oracle_user
          jdbc_url = var.oracle_jdbc_url
        }
      }
      "agent-ingest-svc" = {
        image    = var.agent_ingest_image
        replicas = var.agent_ingest_replicas
      }
      "device-state-svc" = {
        image         = var.device_state_image
        replicas      = var.device_state_replicas
        containerPort = var.device_state_container_port
        servicePort   = var.device_state_service_port
      }
      ingress = {
        host = var.ingress_host
      }
    })
  ]
}
EOF

echo "Writing stub AWS modules (vpc, eks, rds, ecr)..."

cat > infra/modules/vpc/variables.tf <<'EOF'
variable "name" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "common_tags" {
  type = map(string)
}
EOF

cat > infra/modules/vpc/main.tf <<'EOF'
# TODO: replace with terraform-aws-modules/vpc/aws or your own implementation
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    { Name = var.name }
  )
}

# TODO: add subnets, igw, nat, routes
EOF

cat > infra/modules/vpc/outputs.tf <<'EOF'
output "vpc_id" {
  value = aws_vpc.this.id
}

# TODO: add public/private subnet outputs
EOF

cat > infra/modules/eks/variables.tf <<'EOF'
variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "common_tags" {
  type = map(string)
}
EOF

cat > infra/modules/eks/main.tf <<'EOF'
# TODO: replace with terraform-aws-modules/eks/aws or your own implementation
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = "arn:aws:iam::123456789012:role/TODO-eks-role" # TODO

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  tags = var.common_tags
}
EOF

cat > infra/modules/eks/outputs.tf <<'EOF'
output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}
EOF

cat > infra/modules/rds/variables.tf <<'EOF'
variable "db_name" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "engine" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "common_tags" {
  type = map(string)
}
EOF

cat > infra/modules/rds/main.tf <<'EOF'
# TODO: implement real RDS (single instance or cluster)
# This is just a placeholder.
resource "aws_db_instance" "this" {
  identifier        = "telemetry-db"
  allocated_storage = 20
  engine            = var.engine
  instance_class    = var.instance_class
  db_name           = var.db_name

  # TODO: subnet group, security groups, credentials

  skip_final_snapshot = true

  tags = var.common_tags
}
EOF

cat > infra/modules/rds/outputs.tf <<'EOF'
output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "jdbc_url" {
  value = "jdbc:${aws_db_instance.this.engine}://${aws_db_instance.this.address}:${aws_db_instance.this.port}/${aws_db_instance.this.db_name}"
}

# TODO: output db_user, db_pass if you manage them here
EOF

cat > infra/modules/ecr/variables.tf <<'EOF'
variable "repositories" {
  type = list(string)
}

variable "common_tags" {
  type = map(string)
}
EOF

cat > infra/modules/ecr/main.tf <<'EOF'
resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name = each.value

  tags = var.common_tags
}
EOF

cat > infra/modules/ecr/outputs.tf <<'EOF'
output "repository_urls" {
  value = {
    for name, repo in aws_ecr_repository.this :
    name => repo.repository_url
  }
}
EOF

echo "Done. Now you can:"
echo "  cd infra/live/dev  && terragrunt run-all apply   # dev to kind"
echo "  cd infra/live/prod && terragrunt run-all plan    # prod to AWS (after filling TODOs)"
