#!/usr/bin/env bash
set -euo pipefail

# Detect repo root (script is expected in scripts/ under root)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${ROOT_DIR}/infra"
MODULES_DIR="${INFRA_DIR}/modules"

echo "ROOT_DIR=${ROOT_DIR}"
echo "INFRA_DIR=${INFRA_DIR}"
echo "MODULES_DIR=${MODULES_DIR}"
echo

###############################################################################
# 1) VPC MODULE: infra/modules/vpc
###############################################################################
VPC_MODULE_DIR="${MODULES_DIR}/vpc"
mkdir -p "${VPC_MODULE_DIR}"

cat > "${VPC_MODULE_DIR}/variables.tf" <<'EOF'
variable "name" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "common_tags" {
  type = map(string)
}
EOF

cat > "${VPC_MODULE_DIR}/main.tf" <<'EOF'
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.cidr_block

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.common_tags
}
EOF

cat > "${VPC_MODULE_DIR}/outputs.tf" <<'EOF'
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}
EOF

echo "✅ Wrote VPC module in ${VPC_MODULE_DIR}"
echo

###############################################################################
# 2) EKS MODULE: infra/modules/eks
###############################################################################
EKS_MODULE_DIR="${MODULES_DIR}/eks"
mkdir -p "${EKS_MODULE_DIR}"

cat > "${EKS_MODULE_DIR}/variables.tf" <<'EOF'
variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "node_instance_type" {
  type    = string
  default = "t3.large"
}

variable "common_tags" {
  type = map(string)
}
EOF

cat > "${EKS_MODULE_DIR}/main.tf" <<'EOF'
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  eks_managed_node_groups = {
    default = {
      desired_size = 2
      min_size     = 1
      max_size     = 3

      instance_types = [var.node_instance_type]
    }
  }

  tags = var.common_tags
}
EOF

cat > "${EKS_MODULE_DIR}/outputs.tf" <<'EOF'
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}
EOF

echo "✅ Wrote EKS module in ${EKS_MODULE_DIR}"
echo

###############################################################################
# 3) RDS MODULE: infra/modules/rds
###############################################################################
RDS_MODULE_DIR="${MODULES_DIR}/rds"
mkdir -p "${RDS_MODULE_DIR}"

cat > "${RDS_MODULE_DIR}/variables.tf" <<'EOF'
variable "identifier" {
  type    = string
  default = "telemetry-db"
}

variable "db_name" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "engine" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "19.0.0.0.ru-2024-01.rur-2024-01.r1" # example for Oracle; change if using Postgres
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "common_tags" {
  type = map(string)
}
EOF

cat > "${RDS_MODULE_DIR}/main.tf" <<'EOF'
resource "aws_security_group" "rds" {
  name        = "${var.identifier}-sg"
  description = "Security group for ${var.identifier} RDS instance"
  vpc_id      = var.vpc_id

  # For demo: allow DB access from within the VPC
  ingress {
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.common_tags
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnets"
  subnet_ids = var.subnet_ids

  tags = var.common_tags
}

resource "aws_db_instance" "this" {
  identifier        = var.identifier
  allocated_storage = var.allocated_storage

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.username
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  skip_final_snapshot = true

  tags = var.common_tags
}
EOF

cat > "${RDS_MODULE_DIR}/outputs.tf" <<'EOF'
output "endpoint" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "username" {
  value = aws_db_instance.this.username
}
EOF

echo "✅ Wrote RDS module in ${RDS_MODULE_DIR}"
echo

###############################################################################
# 4) PROD TERRAGRUNT: VPC (infra/live/prod/network/vpc/terragrunt.hcl)
###############################################################################
PROD_ROOT="${INFRA_DIR}/live/prod"
PROD_NET_VPC_DIR="${PROD_ROOT}/network/vpc"
mkdir -p "${PROD_NET_VPC_DIR}"

cat > "${PROD_NET_VPC_DIR}/terragrunt.hcl" <<'EOF'
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
EOF

echo "✅ Wrote prod VPC terragrunt in ${PROD_NET_VPC_DIR}/terragrunt.hcl"
echo

###############################################################################
# 5) PROD TERRAGRUNT: EKS (infra/live/prod/platform/eks/terragrunt.hcl)
###############################################################################
PROD_PLATFORM_DIR="${PROD_ROOT}/platform"
PROD_EKS_DIR="${PROD_PLATFORM_DIR}/eks"
mkdir -p "${PROD_EKS_DIR}"

cat > "${PROD_EKS_DIR}/terragrunt.hcl" <<'EOF'
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
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = []
  }
}

inputs = {
  cluster_name    = "telemetry-eks-prod"
  cluster_version = "1.29"

  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  node_instance_type = "t3.large"

  common_tags = local.tags
}
EOF

echo "✅ Wrote prod EKS terragrunt in ${PROD_EKS_DIR}/terragrunt.hcl"
echo

###############################################################################
# 6) PROD TERRAGRUNT: RDS (infra/live/prod/platform/rds/terragrunt.hcl)
###############################################################################
PROD_RDS_DIR="${PROD_PLATFORM_DIR}/rds"
mkdir -p "${PROD_RDS_DIR}"

cat > "${PROD_RDS_DIR}/terragrunt.hcl" <<'EOF'
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
EOF

echo "✅ Wrote prod RDS terragrunt in ${PROD_RDS_DIR}/terragrunt.hcl"
echo

echo "🎉 Done. AWS infra modules and prod Terragrunt configs (VPC/EKS/RDS) are in place."
echo
echo "Apply order example:"
echo "  cd ${PROD_NET_VPC_DIR}      && terragrunt apply   # VPC"
echo "  cd ${PROD_EKS_DIR}          && terragrunt apply   # EKS"
echo "  aws eks update-kubeconfig --name telemetry-eks-prod --region us-east-1"
echo "  cd ${PROD_RDS_DIR}          && terragrunt apply   # RDS"
echo

