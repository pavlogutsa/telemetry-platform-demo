# Telemetry Platform Config Walkthrough (Infra + Helm)

This document explains the configuration inside your `infra/` (Terragrunt/Terraform) and `helm/` (Helm charts) archives.

Notes:
- Files named `._*` are macOS metadata and are ignored.
- Some `terragrunt.hcl` files in this archive contain a literal `...` placeholder; where that happens, I explain what that block is intended to contain based on the generated files/modules present.


---

## `infra/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
1| locals {
2|   project_name = "telemetry"
3| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Starts a `locals` block - named values you can reuse in this file.


---

## `infra/live/dev/platform/ingress-nginx/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
 1| include "env" {
 2|   path = find_in_parent_folders("terragrunt.hcl")
 3| }
 4| 
 5| terraform {
 6|   source = "../../../../modules/ingress-nginx-local"
 7| }
 8| 
 9| # Make sure cluster exists before installing ingress-nginx
10| dependencies {
11|   paths = ["../kind-cluster"]
12| }
13| 
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Terragrunt `include` - pulls in parent configuration (like common locals, remote_state, provider generation).

- **Line 2:** Searches upward for the named file and includes it - this lets child stacks inherit env-level settings.

- **Line 5:** Terragrunt `terraform` block - tells Terragrunt where the Terraform module source is.

- **Line 6:** Terraform module source path (relative here) that Terragrunt will run.


---

## `infra/live/dev/platform/kind-cluster/kind-config.yaml`

### What this file is for

- Supporting YAML (e.g., kind cluster config).


### File contents (numbered)

```
 1| kind: Cluster
 2| apiVersion: kind.x-k8s.io/v1alpha4
 3| name: telemetry
 4| nodes:
 5|   - role: control-plane
 6|     labels:
 7|       ingress-ready: "true"
 8|     extraPortMappings:
 9|       - containerPort: 80
10|         hostPort: 80
11|         protocol: TCP
12|       - containerPort: 443
13|         hostPort: 443
14|         protocol: TCP
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** The type of Kubernetes object (Deployment, Service, Ingress, etc.).

- **Line 2:** Kubernetes API group/version for this object.


---

## `infra/live/dev/platform/kind-cluster/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
 1| include "env" {
 2|   path = find_in_parent_folders("terragrunt.hcl")
 3| }
 4| 
 5| terraform {
 6|   source = "../../../../modules/kind-cluster-local"
 7| }
 8| 
 9| inputs = {
10|   cluster_name     = "telemetry"
11|   kind_config_path = "${get_terragrunt_dir()}/kind-config.yaml"
12| }
13| 
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Terragrunt `include` - pulls in parent configuration (like common locals, remote_state, provider generation).

- **Line 2:** Searches upward for the named file and includes it - this lets child stacks inherit env-level settings.

- **Line 5:** Terragrunt `terraform` block - tells Terragrunt where the Terraform module source is.

- **Line 6:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 9:** Inputs map passed to the Terraform module as variables.


---

## `infra/live/dev/platform/telemetry-platform/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
 1| include "env" {
 2|   path = find_in_parent_folders("terragrunt.hcl")
 3| }
 4| 
 5| terraform {
 6|   source = "../../../../modules/telemetry-platform-local"
 7| }
 8| 
 9| dependencies {
10|   paths = [
11|     "../kind-cluster",
12|     "../ingress-nginx",
13|   ]
14| }
15| 
16| inputs = {
17|   namespace = "telemetry"
18| 
19|   chart_path = "${get_terragrunt_dir()}/../../../../helm/telemetry-platform"
20|   
21|   oracle_user     = "telemetry"
22|   oracle_password = "telemetry_pw"
23|   oracle_jdbc_url = "jdbc:oracle:thin:@oracle-db.telemetry.svc.cluster.local:1521/XEPDB1"
24| 
25|   agent_ingest_image    = "telemetry/agent-ingest-svc:local"
26|   agent_ingest_replicas = 2
27| 
28|   device_state_image          = "telemetry/device-state-svc:local"
29|   device_state_replicas       = 1
30|   device_state_container_port = 8081
31|   device_state_service_port   = 8080
32| 
33|   ingress_host = "telemetry.internal" # or telemetry.local
34| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Terragrunt `include` - pulls in parent configuration (like common locals, remote_state, provider generation).

- **Line 2:** Searches upward for the named file and includes it - this lets child stacks inherit env-level settings.

- **Line 5:** Terragrunt `terraform` block - tells Terragrunt where the Terraform module source is.

- **Line 6:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 16:** Inputs map passed to the Terraform module as variables.


---

## `infra/live/dev/providers.generated.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| # Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
 2| terraform {
 3|   required_version = ">= 1.8.0"
 4| 
 5|   required_providers {
 6|     helm = {
 7|       source  = "hashicorp/helm"
 8|       version = "~> 2.0"
 9|     }
10|     kubernetes = {
11|       source  = "hashicorp/kubernetes"
12|       version = "~> 2.0"
13|     }
14|   }
15| }
16| 
17| provider "kubernetes" {
18|   config_path    = "~/.kube/config"
19|   config_context = "kind-telemetry" # TODO: set your kind context
20| }
21| 
22| provider "helm" {
23|   kubernetes {
24|     config_path    = "~/.kube/config"
25|     config_context = "kind-telemetry"
26|   }
27| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 2:** Terraform settings block (required versions, provider requirements).

- **Line 5:** Declares which providers (AWS/Kubernetes/Helm/etc.) this module needs.

- **Line 17:** Configures a provider instance (how Terraform authenticates/talks to that API).

- **Line 22:** Configures a provider instance (how Terraform authenticates/talks to that API).


---

## `infra/live/dev/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
 1| locals {
 2|   project_name = "telemetry"
 3|   environment  = "dev"
 4| 
 5|   tags = {
 6|     Project     = local.project_name
 7|     Environment = local.environment
 8|     ManagedBy   = "terragrunt"
 9|   }
10| }
11| 
12| generate "providers" {
13|   path      = "providers.generated.tf"
14|   if_exists = "overwrite_terragrunt"
15|   contents  = <<EOC
16| terraform {
17|   required_version = ">= 1.8.0"
18| 
19|   required_providers {
20|     helm = {
21|       source  = "hashicorp/helm"
22|       version = "~> 2.0"
23|     }
24|     kubernetes = {
25|       source  = "hashicorp/kubernetes"
26|       version = "~> 2.0"
27|     }
28|   }
29| }
30| 
31| provider "kubernetes" {
32|   config_path    = "~/.kube/config"
33|   config_context = "kind-telemetry"  # TODO: set your kind context
34| }
35| 
36| provider "helm" {
37|   kubernetes {
38|     config_path    = "~/.kube/config"
39|     config_context = "kind-telemetry"
40|   }
41| }
42| EOC
43| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Starts a `locals` block - named values you can reuse in this file.

- **Line 12:** Terragrunt generate - writes a file into the working dir before running Terraform (commonly providers).

- **Line 16:** Terragrunt `terraform` block - tells Terragrunt where the Terraform module source is.

- **Line 21:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 25:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 32:** Backend configuration map.

- **Line 33:** Backend configuration map.

- **Line 38:** Backend configuration map.

- **Line 39:** Backend configuration map.


---

## `infra/live/prod/network/vpc/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
 1| include "env" {
 2|   path = find_in_parent_folders("terragrunt.hcl")
 3| }
 4| 
 5| terraform {
 6|   source = "../../../modules/vpc"
 7| }
 8| 
 9| inputs = {
10|   name       = "telemetry-vpc-prod"
11|   cidr_block = "10.0.0.0/16"
12| 
13|   azs = [
14|     "us-east-1a",
15|     "us-east-1b",
16|   ]
17| 
18|   private_subnets = [
19|     "10.0.1.0/24",
20|     "10.0.2.0/24",
21|   ]
22| 
23|   public_subnets = [
24|     "10.0.101.0/24",
25|     "10.0.102.0/24",
26|   ]
27| 
28|   common_tags = local.tags
29| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Terragrunt `include` - pulls in parent configuration (like common locals, remote_state, provider generation).

- **Line 2:** Searches upward for the named file and includes it - this lets child stacks inherit env-level settings.

- **Line 5:** Terragrunt `terraform` block - tells Terragrunt where the Terraform module source is.

- **Line 6:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 9:** Inputs map passed to the Terraform module as variables.


---

## `infra/live/prod/platform/ecr/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
 1| include "env" {
 2|   path = find_in_parent_folders("terragrunt.hcl")
 3| }
 4| 
 5| terraform {
 6|   source = "../../../modules/ecr"
 7| }
 8| 
 9| inputs = {
10|   repositories = [
11|     "telemetry/agent-ingest-svc",
12|     "telemetry/device-state-svc",
13|   ]
14|   common_tags = local.tags
15| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Terragrunt `include` - pulls in parent configuration (like common locals, remote_state, provider generation).

- **Line 2:** Searches upward for the named file and includes it - this lets child stacks inherit env-level settings.

- **Line 5:** Terragrunt `terraform` block - tells Terragrunt where the Terraform module source is.

- **Line 6:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 9:** Inputs map passed to the Terraform module as variables.


---

## `infra/live/prod/platform/eks/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
 1| include "env" {
 2|   path = find_in_parent_folders("terragrunt.hcl")
 3| }
 4| 
 5| terraform {
 6|   source = "../../../modules/eks"
 7| }
 8| 
 9| dependency "vpc" {
10|   config_path = "../../network/vpc"
11| 
12|   mock_outputs_allowed_terraform_commands = ["validate", "plan"]
13|   mock_outputs = {
14|     vpc_id             = "vpc-00000000000000000"
15|     private_subnet_ids = []
16|   }
17| }
18| 
19| inputs = {
20|   cluster_name    = "telemetry-eks-prod"
21|   cluster_version = "1.29"
22| 
23|   vpc_id             = dependency.vpc.outputs.vpc_id
24|   private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
25| 
26|   node_instance_type = "t3.large"
27| 
28|   common_tags = local.tags
29| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Terragrunt `include` - pulls in parent configuration (like common locals, remote_state, provider generation).

- **Line 2:** Searches upward for the named file and includes it - this lets child stacks inherit env-level settings.

- **Line 5:** Terragrunt `terraform` block - tells Terragrunt where the Terraform module source is.

- **Line 6:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 9:** Terragrunt dependency block - reads outputs from another stack so you can wire values without copy/paste.

- **Line 10:** Backend configuration map.

- **Line 19:** Inputs map passed to the Terraform module as variables.


### How dependencies work here

- A `dependency` block runs Terragrunt in the referenced folder, reads its Terraform outputs, and exposes them as `dependency.<name>.outputs.<output_name>`.

- That lets you wire, for example, `vpc_id` from the VPC stack into the EKS/RDS stacks without hardcoding.


---

## `infra/live/prod/platform/rds/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
 1| include "env" {
 2|   path = find_in_parent_folders("terragrunt.hcl")
 3| }
 4| 
 5| terraform {
 6|   source = "../../../modules/rds"
 7| }
 8| 
 9| dependency "vpc" {
10|   config_path = "../../network/vpc"
11| 
12|   mock_outputs_allowed_terraform_commands = ["validate", "plan"]
13|   mock_outputs = {
14|     vpc_id             = "vpc-00000000000000000"
15|     private_subnet_ids = []
16|     vpc_cidr_block     = "10.0.0.0/16"
17|   }
18| }
19| 
20| inputs = {
21|   identifier = "telemetry-db-prod"
22| 
23|   db_name        = "telemetry_prod"
24|   instance_class = "db.t4g.medium"
25|   engine         = "oracle-se2"  # or "postgres" etc
26|   # engine_version = "..."       # optionally override for non-Oracle engines
27| 
28|   username = "telemetry"
29|   password = "CHANGE_ME_STRONG_SECRET"
30| 
31|   vpc_id         = dependency.vpc.outputs.vpc_id
32|   vpc_cidr_block = dependency.vpc.outputs.vpc_cidr_block
33|   subnet_ids     = dependency.vpc.outputs.private_subnet_ids
34| 
35|   common_tags = local.tags
36| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Terragrunt `include` - pulls in parent configuration (like common locals, remote_state, provider generation).

- **Line 2:** Searches upward for the named file and includes it - this lets child stacks inherit env-level settings.

- **Line 5:** Terragrunt `terraform` block - tells Terragrunt where the Terraform module source is.

- **Line 6:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 9:** Terragrunt dependency block - reads outputs from another stack so you can wire values without copy/paste.

- **Line 10:** Backend configuration map.

- **Line 20:** Inputs map passed to the Terraform module as variables.


### How dependencies work here

- A `dependency` block runs Terragrunt in the referenced folder, reads its Terraform outputs, and exposes them as `dependency.<name>.outputs.<output_name>`.

- That lets you wire, for example, `vpc_id` from the VPC stack into the EKS/RDS stacks without hardcoding.


---

## `infra/live/prod/platform/telemetry-platform/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
 1| include "env" {
 2|   path = find_in_parent_folders("terragrunt.hcl")
 3| }
 4| 
 5| terraform {
 6|   source = "../../../../modules/telemetry-platform-eks"
 7| }
 8| 
 9| dependency "eks" {
10|   config_path = "../eks"
11| 
12|   mock_outputs_allowed_terraform_commands = ["validate", "plan"]
13|   mock_outputs = {
14|     cluster_name     = "mock"
15|     cluster_endpoint = "https://example.com"
16|     cluster_ca_data  = ""
17|   }
18| }
19| 
20| dependency "rds" {
21|   config_path = "../rds"
22| 
23|   mock_outputs_allowed_terraform_commands = ["validate", "plan"]
24|   mock_outputs = {
25|     jdbc_url = "jdbc:oracle:thin:@oracle-prod.example.com:1521/XEPDB1"
26|     db_user  = "telemetry"
27|     db_pass  = "telemetry_pw"
28|   }
29| }
30| 
31| dependency "ecr" {
32|   config_path = "../ecr"
33| 
34|   mock_outputs_allowed_terraform_commands = ["validate", "plan"]
35|   mock_outputs = {
36|     repository_urls = {
37|       "telemetry/agent-ingest-svc" = "000000000000.dkr.ecr.us-east-1.amazonaws.com/telemetry/agent-ingest-svc"
38|       "telemetry/device-state-svc" = "000000000000.dkr.ecr.us-east-1.amazonaws.com/telemetry/device-state-svc"
39|     }
40|   }
41| }
42| 
43| inputs = {
44|   namespace = "telemetry"
45| 
46|   cluster_name     = dependency.eks.outputs.cluster_name
47|   cluster_endpoint = dependency.eks.outputs.cluster_endpoint
48|   cluster_ca_data  = dependency.eks.outputs.cluster_ca_data
49| 
50|   oracle_user     = dependency.rds.outputs.db_user
51|   oracle_password = dependency.rds.outputs.db_pass
52|   oracle_jdbc_url = dependency.rds.outputs.jdbc_url
53| 
54|   agent_ingest_image = "${dependency.ecr.outputs.repository_urls["telemetry/agent-ingest-svc"]}:release1"
55|   device_state_image = "${dependency.ecr.outputs.repository_urls["telemetry/device-state-svc"]}:release1"
56| 
57|   agent_ingest_replicas = 2
58| 
59|   device_state_replicas       = 2
60|   device_state_container_port = 8081
61|   device_state_service_port   = 8080
62| 
63|   ingress_host = "telemetry.internal"
64| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Terragrunt `include` - pulls in parent configuration (like common locals, remote_state, provider generation).

- **Line 2:** Searches upward for the named file and includes it - this lets child stacks inherit env-level settings.

- **Line 5:** Terragrunt `terraform` block - tells Terragrunt where the Terraform module source is.

- **Line 6:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 9:** Terragrunt dependency block - reads outputs from another stack so you can wire values without copy/paste.

- **Line 10:** Backend configuration map.

- **Line 20:** Terragrunt dependency block - reads outputs from another stack so you can wire values without copy/paste.

- **Line 21:** Backend configuration map.

- **Line 31:** Terragrunt dependency block - reads outputs from another stack so you can wire values without copy/paste.

- **Line 32:** Backend configuration map.

- **Line 43:** Inputs map passed to the Terraform module as variables.


### How dependencies work here

- A `dependency` block runs Terragrunt in the referenced folder, reads its Terraform outputs, and exposes them as `dependency.<name>.outputs.<output_name>`.

- That lets you wire, for example, `vpc_id` from the VPC stack into the EKS/RDS stacks without hardcoding.


---

## `infra/live/prod/terragrunt.hcl`

### What this file is for

- Terragrunt configuration. Terragrunt wraps Terraform: it wires modules together, handles remote state, and injects providers.


### File contents (numbered)

```
 1| locals {
 2|   environment = "prod"
 3| 
 4|   tags = {
 5|     Project     = local.project_name
 6|     Environment = local.environment
 7|     ManagedBy   = "terragrunt"
 8|   }
 9| }
10| 
11| remote_state {
12|   backend = "s3"
13|   config = {
14|     bucket         = "telemetry-terraform-state"    # TODO: create this bucket
15|     key            = "${path_relative_to_include()}/terraform.tfstate"
16|     region         = "us-east-1"
17|     encrypt        = true
18|     dynamodb_table = "telemetry-terraform-locks"    # TODO: create this table
19|   }
20| }
21| 
22| generate "providers" {
23|   path      = "providers.generated.tf"
24|   if_exists = "overwrite_terragrunt"
25|   contents  = <<EOC
26| terraform {
27|   required_version = ">= 1.8.0"
28| 
29|   required_providers {
30|     aws = {
31|       source  = "hashicorp/aws"
32|       version = "~> 5.0"
33|     }
34|     helm = {
35|       source  = "hashicorp/helm"
36|       version = "~> 2.0"
37|     }
38|     kubernetes = {
39|       source  = "hashicorp/kubernetes"
40|       version = "~> 2.0"
41|     }
42|   }
43| }
44| 
45| provider "aws" {
46|   region = "us-east-1"
47| }
48| EOC
49| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Starts a `locals` block - named values you can reuse in this file.

- **Line 11:** Terragrunt remote_state - configures Terraform backend so state is stored remotely (S3) instead of locally.

- **Line 12:** Selects Terraform backend type.

- **Line 13:** Backend configuration map.

- **Line 15:** Computes a unique state key per stack based on its folder path.

- **Line 22:** Terragrunt generate - writes a file into the working dir before running Terraform (commonly providers).

- **Line 26:** Terragrunt `terraform` block - tells Terragrunt where the Terraform module source is.

- **Line 31:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 35:** Terraform module source path (relative here) that Terragrunt will run.

- **Line 39:** Terraform module source path (relative here) that Terragrunt will run.


---

## `infra/modules/ecr/main.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
1| resource "aws_ecr_repository" "this" {
2|   for_each = toset(var.repositories)
3| 
4|   name = each.value
5| 
6|   tags = var.common_tags
7| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Declares a real infrastructure object to create/update (e.g., AWS VPC, EKS, IAM, etc.).


---

## `infra/modules/ecr/outputs.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
1| output "repository_urls" {
2|   value = {
3|     for name, repo in aws_ecr_repository.this :
4|     name => repo.repository_url
5|   }
6| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an output value this module exports to callers (Terragrunt dependencies read these).


---

## `infra/modules/ecr/variables.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
1| variable "repositories" {
2|   type = list(string)
3| }
4| 
5| variable "common_tags" {
6|   type = map(string)
7| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an input variable (must be provided by caller or has a default).

- **Line 5:** Defines an input variable (must be provided by caller or has a default).


---

## `infra/modules/eks/main.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| module "eks" {
 2|   source  = "terraform-aws-modules/eks/aws"
 3|   version = "~> 20.0"
 4| 
 5|   cluster_name    = var.cluster_name
 6|   cluster_version = var.cluster_version
 7| 
 8|   vpc_id     = var.vpc_id
 9|   subnet_ids = var.private_subnet_ids
10| 
11|   eks_managed_node_groups = {
12|     default = {
13|       desired_size = 2
14|       min_size     = 1
15|       max_size     = 3
16| 
17|       instance_types = [var.node_instance_type]
18|     }
19|   }
20| 
21|   tags = var.common_tags
22| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Calls another Terraform module (a reusable chunk of infra).


---

## `infra/modules/eks/outputs.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| output "cluster_name" {
 2|   value = module.eks.cluster_name
 3| }
 4| 
 5| output "cluster_arn" {
 6|   value = module.eks.cluster_arn
 7| }
 8| 
 9| output "cluster_endpoint" {
10|   value = module.eks.cluster_endpoint
11| }
12| 
13| output "cluster_certificate_authority_data" {
14|   value = module.eks.cluster_certificate_authority_data
15| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an output value this module exports to callers (Terragrunt dependencies read these).

- **Line 5:** Defines an output value this module exports to callers (Terragrunt dependencies read these).

- **Line 9:** Defines an output value this module exports to callers (Terragrunt dependencies read these).

- **Line 13:** Defines an output value this module exports to callers (Terragrunt dependencies read these).


---

## `infra/modules/eks/variables.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| variable "cluster_name" {
 2|   type = string
 3| }
 4| 
 5| variable "cluster_version" {
 6|   type    = string
 7|   default = "1.29"
 8| }
 9| 
10| variable "vpc_id" {
11|   type = string
12| }
13| 
14| variable "private_subnet_ids" {
15|   type = list(string)
16| }
17| 
18| variable "node_instance_type" {
19|   type    = string
20|   default = "t3.large"
21| }
22| 
23| variable "common_tags" {
24|   type = map(string)
25| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an input variable (must be provided by caller or has a default).

- **Line 5:** Defines an input variable (must be provided by caller or has a default).

- **Line 10:** Defines an input variable (must be provided by caller or has a default).

- **Line 14:** Defines an input variable (must be provided by caller or has a default).

- **Line 18:** Defines an input variable (must be provided by caller or has a default).

- **Line 23:** Defines an input variable (must be provided by caller or has a default).


---

## `infra/modules/ingress-nginx-local/main.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| resource "null_resource" "ingress_nginx" {
 2|   provisioner "local-exec" {
 3|     command = <<EOT
 4| set -euo pipefail
 5| 
 6| # Install ingress-nginx for kind
 7| kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/kind/deploy.yaml
 8| 
 9| # Wait for controller to be ready
10| kubectl wait --namespace ingress-nginx \
11|   --for=condition=ready pod \
12|   --selector=app.kubernetes.io/component=controller \
13|   --timeout=180s
14| EOT
15|   }
16| }
17| 
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Declares a real infrastructure object to create/update (e.g., AWS VPC, EKS, IAM, etc.).


---

## `infra/modules/kind-cluster-local/main.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| resource "null_resource" "kind_cluster" {
 2|   provisioner "local-exec" {
 3|     command = <<EOT
 4| set -euo pipefail
 5| 
 6| # Write kind config with ingress label + host port mappings
 7| cat > ${var.kind_config_path} <<EOF
 8| kind: Cluster
 9| apiVersion: kind.x-k8s.io/v1alpha4
10| name: ${var.cluster_name}
11| nodes:
12|   - role: control-plane
13|     labels:
14|       ingress-ready: "true"
15|     extraPortMappings:
16|       - containerPort: 80
17|         hostPort: 80
18|         protocol: TCP
19|       - containerPort: 443
20|         hostPort: 443
21|         protocol: TCP
22| EOF
23| 
24| # Recreate cluster
25| kind delete cluster --name ${var.cluster_name} || true
26| kind create cluster --name ${var.cluster_name} --config ${var.kind_config_path}
27| EOT
28|   }
29| }
30| 
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Declares a real infrastructure object to create/update (e.g., AWS VPC, EKS, IAM, etc.).


---

## `infra/modules/kind-cluster-local/variables.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| variable "cluster_name" {
 2|   type    = string
 3|   default = "telemetry"
 4| }
 5| 
 6| variable "kind_config_path" {
 7|   type    = string
 8|   default = "kind-config.yaml"
 9| }
10| 
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an input variable (must be provided by caller or has a default).

- **Line 6:** Defines an input variable (must be provided by caller or has a default).


---

## `infra/modules/rds/main.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| resource "aws_security_group" "rds" {
 2|   name        = "${var.identifier}-sg"
 3|   description = "Security group for ${var.identifier} RDS instance"
 4|   vpc_id      = var.vpc_id
 5| 
 6|   # For demo: allow DB access from within the VPC
 7|   ingress {
 8|     from_port   = 1521
 9|     to_port     = 1521
10|     protocol    = "tcp"
11|     cidr_blocks = [var.vpc_cidr_block]
12|   }
13| 
14|   egress {
15|     from_port   = 0
16|     to_port     = 0
17|     protocol    = "-1"
18|     cidr_blocks = ["0.0.0.0/0"]
19|   }
20| 
21|   tags = var.common_tags
22| }
23| 
24| resource "aws_db_subnet_group" "this" {
25|   name       = "${var.identifier}-subnets"
26|   subnet_ids = var.subnet_ids
27| 
28|   tags = var.common_tags
29| }
30| 
31| resource "aws_db_instance" "this" {
32|   identifier        = var.identifier
33|   allocated_storage = var.allocated_storage
34| 
35|   engine         = var.engine
36|   engine_version = var.engine_version
37|   instance_class = var.instance_class
38| 
39|   db_name  = var.db_name
40|   username = var.username
41|   password = var.password
42| 
43|   db_subnet_group_name   = aws_db_subnet_group.this.name
44|   vpc_security_group_ids = [aws_security_group.rds.id]
45| 
46|   publicly_accessible = false
47|   skip_final_snapshot = true
48| 
49|   tags = var.common_tags
50| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Declares a real infrastructure object to create/update (e.g., AWS VPC, EKS, IAM, etc.).

- **Line 24:** Declares a real infrastructure object to create/update (e.g., AWS VPC, EKS, IAM, etc.).

- **Line 31:** Declares a real infrastructure object to create/update (e.g., AWS VPC, EKS, IAM, etc.).


---

## `infra/modules/rds/outputs.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| output "endpoint" {
 2|   value = aws_db_instance.this.address
 3| }
 4| 
 5| output "port" {
 6|   value = aws_db_instance.this.port
 7| }
 8| 
 9| output "db_name" {
10|   value = aws_db_instance.this.db_name
11| }
12| 
13| output "username" {
14|   value = aws_db_instance.this.username
15| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an output value this module exports to callers (Terragrunt dependencies read these).

- **Line 5:** Defines an output value this module exports to callers (Terragrunt dependencies read these).

- **Line 9:** Defines an output value this module exports to callers (Terragrunt dependencies read these).

- **Line 13:** Defines an output value this module exports to callers (Terragrunt dependencies read these).


---

## `infra/modules/rds/variables.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| variable "identifier" {
 2|   type    = string
 3|   default = "telemetry-db"
 4| }
 5| 
 6| variable "db_name" {
 7|   type = string
 8| }
 9| 
10| variable "instance_class" {
11|   type = string
12| }
13| 
14| variable "engine" {
15|   type = string
16| }
17| 
18| variable "engine_version" {
19|   type    = string
20|   default = "19.0.0.0.ru-2024-01.rur-2024-01.r1" # example for Oracle; change if using Postgres
21| }
22| 
23| variable "allocated_storage" {
24|   type    = number
25|   default = 20
26| }
27| 
28| variable "username" {
29|   type = string
30| }
31| 
32| variable "password" {
33|   type      = string
34|   sensitive = true
35| }
36| 
37| variable "vpc_id" {
38|   type = string
39| }
40| 
41| variable "vpc_cidr_block" {
42|   type = string
43| }
44| 
45| variable "subnet_ids" {
46|   type = list(string)
47| }
48| 
49| variable "common_tags" {
50|   type = map(string)
51| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an input variable (must be provided by caller or has a default).

- **Line 6:** Defines an input variable (must be provided by caller or has a default).

- **Line 10:** Defines an input variable (must be provided by caller or has a default).

- **Line 14:** Defines an input variable (must be provided by caller or has a default).

- **Line 18:** Defines an input variable (must be provided by caller or has a default).

- **Line 23:** Defines an input variable (must be provided by caller or has a default).

- **Line 28:** Defines an input variable (must be provided by caller or has a default).

- **Line 32:** Defines an input variable (must be provided by caller or has a default).

- **Line 34:** Marks a value as sensitive so Terraform hides it in CLI output (still stored in state).

- **Line 37:** Defines an input variable (must be provided by caller or has a default).

- **Line 41:** Defines an input variable (must be provided by caller or has a default).

- **Line 45:** Defines an input variable (must be provided by caller or has a default).

- **Line 49:** Defines an input variable (must be provided by caller or has a default).


---

## `infra/modules/telemetry-platform-eks/main.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| # TODO: configure auth (IRSA / aws-iam-authenticator / exec)
 2| provider "kubernetes" {
 3|   host                   = var.cluster_endpoint
 4|   cluster_ca_certificate = base64decode(var.cluster_ca_data)
 5|   token                  = "" # TODO
 6| }
 7| 
 8| provider "helm" {
 9|   kubernetes {
10|     host                   = var.cluster_endpoint
11|     cluster_ca_certificate = base64decode(var.cluster_ca_data)
12|     token                  = "" # TODO
13|   }
14| }
15| 
16| resource "helm_release" "telemetry_platform" {
17|   name             = "telemetry-platform"
18|   namespace        = var.namespace
19|   create_namespace = true
20| 
21|   chart = "${path.module}/../../helm/telemetry-platform"
22| 
23|   values = [
24|     yamlencode({
25|       global = {
26|         namespace = var.namespace
27|         oracle = {
28|           password = var.oracle_password
29|           user     = var.oracle_user
30|           jdbc_url = var.oracle_jdbc_url
31|         }
32|       }
33|       "agent-ingest-svc" = {
34|         image    = var.agent_ingest_image
35|         replicas = var.agent_ingest_replicas
36|       }
37|       "device-state-svc" = {
38|         image         = var.device_state_image
39|         replicas      = var.device_state_replicas
40|         containerPort = var.device_state_container_port
41|         servicePort   = var.device_state_service_port
42|       }
43|       ingress = {
44|         host = var.ingress_host
45|       }
46|     })
47|   ]
48| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 2:** Configures a provider instance (how Terraform authenticates/talks to that API).

- **Line 8:** Configures a provider instance (how Terraform authenticates/talks to that API).

- **Line 16:** Declares a real infrastructure object to create/update (e.g., AWS VPC, EKS, IAM, etc.).


---

## `infra/modules/telemetry-platform-eks/variables.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| variable "namespace" {
 2|   type    = string
 3|   default = "telemetry"
 4| }
 5| 
 6| variable "cluster_name" {
 7|   type = string
 8| }
 9| 
10| variable "cluster_endpoint" {
11|   type = string
12| }
13| 
14| variable "cluster_ca_data" {
15|   type = string
16| }
17| 
18| variable "oracle_user" {
19|   type = string
20| }
21| 
22| variable "oracle_password" {
23|   type = string
24| }
25| 
26| variable "oracle_jdbc_url" {
27|   type = string
28| }
29| 
30| variable "agent_ingest_image" {
31|   type = string
32| }
33| 
34| variable "agent_ingest_replicas" {
35|   type    = number
36|   default = 2
37| }
38| 
39| variable "device_state_image" {
40|   type = string
41| }
42| 
43| variable "device_state_replicas" {
44|   type    = number
45|   default = 1
46| }
47| 
48| variable "device_state_container_port" {
49|   type    = number
50|   default = 8081
51| }
52| 
53| variable "device_state_service_port" {
54|   type    = number
55|   default = 8080
56| }
57| 
58| variable "ingress_host" {
59|   type = string
60| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an input variable (must be provided by caller or has a default).

- **Line 6:** Defines an input variable (must be provided by caller or has a default).

- **Line 10:** Defines an input variable (must be provided by caller or has a default).

- **Line 14:** Defines an input variable (must be provided by caller or has a default).

- **Line 18:** Defines an input variable (must be provided by caller or has a default).

- **Line 22:** Defines an input variable (must be provided by caller or has a default).

- **Line 26:** Defines an input variable (must be provided by caller or has a default).

- **Line 30:** Defines an input variable (must be provided by caller or has a default).

- **Line 34:** Defines an input variable (must be provided by caller or has a default).

- **Line 39:** Defines an input variable (must be provided by caller or has a default).

- **Line 43:** Defines an input variable (must be provided by caller or has a default).

- **Line 48:** Defines an input variable (must be provided by caller or has a default).

- **Line 53:** Defines an input variable (must be provided by caller or has a default).

- **Line 58:** Defines an input variable (must be provided by caller or has a default).


---

## `infra/modules/telemetry-platform-local/main.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| resource "helm_release" "telemetry_platform" {
 2|   name             = "telemetry-platform"
 3|   namespace        = var.namespace
 4|   create_namespace = true
 5| 
 6|   chart = var.chart_path
 7| 
 8|   values = [
 9|     yamlencode({
10|       global = {
11|         namespace = var.namespace
12|         oracle = {
13|           password = var.oracle_password
14|           user     = var.oracle_user
15|           jdbc_url = var.oracle_jdbc_url
16|         }
17|       }
18|       "agent-ingest-svc" = {
19|         image    = var.agent_ingest_image
20|         replicas = var.agent_ingest_replicas
21|       }
22|       "device-state-svc" = {
23|         image         = var.device_state_image
24|         replicas      = var.device_state_replicas
25|         containerPort = var.device_state_container_port
26|         servicePort   = var.device_state_service_port
27|       }
28|       ingress = {
29|         host = var.ingress_host
30|       }
31|     })
32|   ]
33| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Declares a real infrastructure object to create/update (e.g., AWS VPC, EKS, IAM, etc.).


---

## `infra/modules/telemetry-platform-local/variables.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| variable "chart_path" {
 2|   type = string
 3| }
 4| 
 5| variable "namespace" {
 6|   type    = string
 7|   default = "telemetry"
 8| }
 9| 
10| variable "oracle_user" {
11|   type = string
12| }
13| 
14| variable "oracle_password" {
15|   type = string
16| }
17| 
18| variable "oracle_jdbc_url" {
19|   type = string
20| }
21| 
22| variable "agent_ingest_image" {
23|   type = string
24| }
25| 
26| variable "agent_ingest_replicas" {
27|   type    = number
28|   default = 2
29| }
30| 
31| variable "device_state_image" {
32|   type = string
33| }
34| 
35| variable "device_state_replicas" {
36|   type    = number
37|   default = 1
38| }
39| 
40| variable "device_state_container_port" {
41|   type    = number
42|   default = 8081
43| }
44| 
45| variable "device_state_service_port" {
46|   type    = number
47|   default = 8080
48| }
49| 
50| variable "ingress_host" {
51|   type    = string
52|   default = "telemetry.internal"
53| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an input variable (must be provided by caller or has a default).

- **Line 5:** Defines an input variable (must be provided by caller or has a default).

- **Line 10:** Defines an input variable (must be provided by caller or has a default).

- **Line 14:** Defines an input variable (must be provided by caller or has a default).

- **Line 18:** Defines an input variable (must be provided by caller or has a default).

- **Line 22:** Defines an input variable (must be provided by caller or has a default).

- **Line 26:** Defines an input variable (must be provided by caller or has a default).

- **Line 31:** Defines an input variable (must be provided by caller or has a default).

- **Line 35:** Defines an input variable (must be provided by caller or has a default).

- **Line 40:** Defines an input variable (must be provided by caller or has a default).

- **Line 45:** Defines an input variable (must be provided by caller or has a default).

- **Line 50:** Defines an input variable (must be provided by caller or has a default).


---

## `infra/modules/vpc/main.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| module "vpc" {
 2|   source  = "terraform-aws-modules/vpc/aws"
 3|   version = "~> 5.0"
 4| 
 5|   name = var.name
 6|   cidr = var.cidr_block
 7| 
 8|   azs             = var.azs
 9|   private_subnets = var.private_subnets
10|   public_subnets  = var.public_subnets
11| 
12|   enable_nat_gateway   = true
13|   single_nat_gateway   = true
14|   enable_dns_hostnames = true
15|   enable_dns_support   = true
16| 
17|   tags = var.common_tags
18| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Calls another Terraform module (a reusable chunk of infra).


---

## `infra/modules/vpc/outputs.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| output "vpc_id" {
 2|   value = module.vpc.vpc_id
 3| }
 4| 
 5| output "private_subnet_ids" {
 6|   value = module.vpc.private_subnets
 7| }
 8| 
 9| output "public_subnet_ids" {
10|   value = module.vpc.public_subnets
11| }
12| 
13| output "vpc_cidr_block" {
14|   value = module.vpc.vpc_cidr_block
15| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an output value this module exports to callers (Terragrunt dependencies read these).

- **Line 5:** Defines an output value this module exports to callers (Terragrunt dependencies read these).

- **Line 9:** Defines an output value this module exports to callers (Terragrunt dependencies read these).

- **Line 13:** Defines an output value this module exports to callers (Terragrunt dependencies read these).


---

## `infra/modules/vpc/variables.tf`

### What this file is for

- Terraform module code (resources, variables, outputs).


### File contents (numbered)

```
 1| variable "name" {
 2|   type = string
 3| }
 4| 
 5| variable "cidr_block" {
 6|   type = string
 7| }
 8| 
 9| variable "azs" {
10|   type = list(string)
11| }
12| 
13| variable "private_subnets" {
14|   type = list(string)
15| }
16| 
17| variable "public_subnets" {
18|   type = list(string)
19| }
20| 
21| variable "common_tags" {
22|   type = map(string)
23| }
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Defines an input variable (must be provided by caller or has a default).

- **Line 5:** Defines an input variable (must be provided by caller or has a default).

- **Line 9:** Defines an input variable (must be provided by caller or has a default).

- **Line 13:** Defines an input variable (must be provided by caller or has a default).

- **Line 17:** Defines an input variable (must be provided by caller or has a default).

- **Line 21:** Defines an input variable (must be provided by caller or has a default).


---

## `helm/telemetry-platform/Chart.yaml`

### What this file is for

- Helm chart metadata.


### File contents (numbered)

```
 1| apiVersion: v2
 2| name: telemetry-platform
 3| description: Telemetry Platform full stack
 4| version: 0.1.0
 5| dependencies:
 6|   - name: oracle
 7|     version: 0.1.0
 8|     repository: file://charts/oracle
 9|   - name: agent-ingest-svc
10|     version: 0.1.0
11|     repository: file://charts/agent-ingest-svc
12|   - name: device-state-svc
13|     version: 0.1.0
14|     repository: file://charts/device-state-svc
15|   - name: ingress
16|     version: 0.1.0
17|     repository: file://charts/ingress
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Helm chart API version (v2 is modern Helm 3).

- **Line 2:** Chart name.

- **Line 4:** Chart package version (changes when chart structure changes).

- **Line 5:** Lists sub-charts this chart depends on.

- **Line 7:** Chart package version (changes when chart structure changes).

- **Line 10:** Chart package version (changes when chart structure changes).

- **Line 13:** Chart package version (changes when chart structure changes).

- **Line 16:** Chart package version (changes when chart structure changes).


---

## `helm/telemetry-platform/charts/agent-ingest-svc/Chart.yaml`

### What this file is for

- Helm chart metadata.


### File contents (numbered)

```
1| apiVersion: v2
2| name: agent-ingest-svc
3| description: Agent ingest microservice for telemetry platform
4| type: application
5| version: 0.1.0
6| appVersion: "release1"
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Helm chart API version (v2 is modern Helm 3).

- **Line 2:** Chart name.

- **Line 5:** Chart package version (changes when chart structure changes).

- **Line 6:** Application version (the app the chart deploys).


---

## `helm/telemetry-platform/charts/agent-ingest-svc/templates/deployment.yaml`

### What this file is for

- Kubernetes manifest template rendered by Helm.


### File contents (numbered)

```
 1| apiVersion: apps/v1
 2| kind: Deployment
 3| metadata:
 4|   name: agent-ingest-svc
 5|   namespace: {{ .Values.global.namespace }}
 6| spec:
 7|   replicas: {{ .Values.replicas }}
 8|   selector:
 9|     matchLabels:
10|       app: agent-ingest-svc
11|   template:
12|     metadata:
13|       labels:
14|         app: agent-ingest-svc
15|     spec:
16|       containers:
17|         - name: agent-ingest-svc
18|           image: {{ .Values.image }}
19|           imagePullPolicy: IfNotPresent
20|           envFrom:
21|             - secretRef:
22|                 name: oracle-credentials
23|           ports:
24|             - containerPort: 8080
25|           readinessProbe:
26|             httpGet:
27|               path: /actuator/health
28|               port: 8080
29|             initialDelaySeconds: 5
30|             periodSeconds: 5
31| ---
32| apiVersion: v1
33| kind: Service
34| metadata:
35|   name: agent-ingest-svc
36|   namespace: {{ .Values.global.namespace }}
37|   annotations:
38|     prometheus.io/scrape: "true"
39|     prometheus.io/path: "/actuator/prometheus"
40|     prometheus.io/port: "8080"
41| spec:
42|   selector:
43|     app: agent-ingest-svc
44|   ports:
45|     - port: 8080
46|       targetPort: 8080
47|       name: http
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Kubernetes API group/version for this object.

- **Line 2:** The type of Kubernetes object (Deployment, Service, Ingress, etc.).

- **Line 3:** Object metadata (name, namespace, labels, annotations).

- **Line 6:** Desired state/specification for the object.

- **Line 12:** Object metadata (name, namespace, labels, annotations).

- **Line 15:** Desired state/specification for the object.

- **Line 16:** List of containers that will run in the Pod.

- **Line 18:** Container image reference to pull/run (repo/name:tag).

- **Line 23:** Ports exposed by the container or service.

- **Line 32:** Kubernetes API group/version for this object.

- **Line 33:** The type of Kubernetes object (Deployment, Service, Ingress, etc.).

- **Line 34:** Object metadata (name, namespace, labels, annotations).

- **Line 41:** Desired state/specification for the object.

- **Line 44:** Ports exposed by the container or service.


---

## `helm/telemetry-platform/charts/agent-ingest-svc/values.yaml`

### What this file is for

- Helm default values (your knobs).


### File contents (numbered)

```
1| # Default values for agent-ingest-svc
2| image: agent-ingest-svc:release1
3| replicas: 2
4| resources: {}
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 4:** Default CPU/memory requests/limits for the chart.


---

## `helm/telemetry-platform/charts/device-state-svc/Chart.yaml`

### What this file is for

- Helm chart metadata.


### File contents (numbered)

```
1| apiVersion: v2
2| name: device-state-svc
3| description: Device status/read API
4| type: application
5| version: 0.1.0
6| appVersion: "release1"
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Helm chart API version (v2 is modern Helm 3).

- **Line 2:** Chart name.

- **Line 5:** Chart package version (changes when chart structure changes).

- **Line 6:** Application version (the app the chart deploys).


---

## `helm/telemetry-platform/charts/device-state-svc/templates/deployment.yaml`

### What this file is for

- Kubernetes manifest template rendered by Helm.


### File contents (numbered)

```
 1| apiVersion: apps/v1
 2| kind: Deployment
 3| metadata:
 4|   name: device-state-svc
 5|   namespace: {{ .Values.global.namespace }}
 6| spec:
 7|   replicas: {{ .Values.replicas }}
 8|   selector:
 9|     matchLabels:
10|       app: device-state-svc
11|   template:
12|     metadata:
13|       labels:
14|         app: device-state-svc
15|     spec:
16|       containers:
17|         - name: device-state-svc
18|           image: {{ .Values.image }}
19|           imagePullPolicy: IfNotPresent
20|           envFrom:
21|             - secretRef:
22|                 name: oracle-credentials
23|           ports:
24|             - containerPort: {{ .Values.containerPort }}
25|           readinessProbe:
26|             httpGet:
27|               path: /actuator/health
28|               port: {{ .Values.containerPort }}
29|             initialDelaySeconds: 5
30|             periodSeconds: 5
31| ---
32| apiVersion: v1
33| kind: Service
34| metadata:
35|   name: device-state-svc
36|   namespace: {{ .Values.global.namespace }}
37|   annotations:
38|     prometheus.io/scrape: "true"
39|     prometheus.io/path: "/actuator/prometheus"
40|     prometheus.io/port: "8080"
41| spec:
42|   selector:
43|     app: device-state-svc
44|   ports:
45|     - port: {{ .Values.servicePort }}
46|       targetPort: {{ .Values.containerPort }}
47|       name: http
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Kubernetes API group/version for this object.

- **Line 2:** The type of Kubernetes object (Deployment, Service, Ingress, etc.).

- **Line 3:** Object metadata (name, namespace, labels, annotations).

- **Line 6:** Desired state/specification for the object.

- **Line 12:** Object metadata (name, namespace, labels, annotations).

- **Line 15:** Desired state/specification for the object.

- **Line 16:** List of containers that will run in the Pod.

- **Line 18:** Container image reference to pull/run (repo/name:tag).

- **Line 23:** Ports exposed by the container or service.

- **Line 32:** Kubernetes API group/version for this object.

- **Line 33:** The type of Kubernetes object (Deployment, Service, Ingress, etc.).

- **Line 34:** Object metadata (name, namespace, labels, annotations).

- **Line 41:** Desired state/specification for the object.

- **Line 44:** Ports exposed by the container or service.


---

## `helm/telemetry-platform/charts/device-state-svc/values.yaml`

### What this file is for

- Helm default values (your knobs).


### File contents (numbered)

```
1| image: device-state-svc:release1
2| replicas: 1
3| containerPort: 8081
4| servicePort: 8080
5| resources: {}
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 5:** Default CPU/memory requests/limits for the chart.


---

## `helm/telemetry-platform/charts/ingress/Chart.yaml`

### What this file is for

- Helm chart metadata.


### File contents (numbered)

```
1| apiVersion: v2
2| name: ingress
3| description: A Helm chart for Kubernetes
4| type: application
5| version: 0.1.0
6| appVersion: "release1"
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Helm chart API version (v2 is modern Helm 3).

- **Line 2:** Chart name.

- **Line 5:** Chart package version (changes when chart structure changes).

- **Line 6:** Application version (the app the chart deploys).


---

## `helm/telemetry-platform/charts/ingress/templates/ingress.yaml`

### What this file is for

- Kubernetes manifest template rendered by Helm.


### File contents (numbered)

```
 1| apiVersion: networking.k8s.io/v1
 2| kind: Ingress
 3| metadata:
 4|   name: telemetry-gateway
 5|   namespace: {{ .Release.Namespace }}
 6| spec:
 7|   ingressClassName: nginx
 8|   rules:
 9|     - host: {{ .Values.host | default "telemetry.internal" }}
10|       http:
11|         paths:
12|           - path: /telemetry
13|             pathType: Prefix
14|             backend:
15|               service:
16|                 name: agent-ingest-svc
17|                 port:
18|                   number: 8080
19|           - path: /devices
20|             pathType: Prefix
21|             backend:
22|               service:
23|                 name: device-state-svc
24|                 port:
25|                   number: 8080
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Kubernetes API group/version for this object.

- **Line 2:** The type of Kubernetes object (Deployment, Service, Ingress, etc.).

- **Line 3:** Object metadata (name, namespace, labels, annotations).

- **Line 6:** Desired state/specification for the object.

- **Line 7:** Which Ingress controller should handle this Ingress.


---

## `helm/telemetry-platform/charts/ingress/values.yaml`

### What this file is for

- Helm default values (your knobs).


### File contents (numbered)

```
1| host: telemetry.internal
```

### Line-by-line explanation (only lines that introduce a concept)

- (No special constructs detected - this is mostly data/values.)


---

## `helm/telemetry-platform/charts/oracle/Chart.yaml`

### What this file is for

- Helm chart metadata.


### File contents (numbered)

```
 1| apiVersion: v2
 2| name: oracle
 3| description: A Helm chart for Kubernetes
 4| 
 5| # A chart can be either an 'application' or a 'library' chart.
 6| #
 7| # Application charts are a collection of templates that can be packaged into versioned archives
 8| # to be deployed.
 9| #
10| # Library charts provide useful utilities or functions for the chart developer. They're included as
11| # a dependency of application charts to inject those utilities and functions into the rendering
12| # pipeline. Library charts do not define any templates and therefore cannot be deployed.
13| type: application
14| 
15| # This is the chart version. This version number should be incremented each time you make changes
16| # to the chart and its templates, including the app version.
17| # Versions are expected to follow Semantic Versioning (https://semver.org/)
18| version: 0.1.0
19| 
20| # This is the version number of the application being deployed. This version number should be
21| # incremented each time you make changes to the application. Versions are not expected to
22| # follow Semantic Versioning. They should reflect the version the application is using.
23| # It is recommended to use it with quotes.
24| appVersion: "1.16.0"
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 1:** Helm chart API version (v2 is modern Helm 3).

- **Line 2:** Chart name.

- **Line 18:** Chart package version (changes when chart structure changes).

- **Line 24:** Application version (the app the chart deploys).


---

## `helm/telemetry-platform/charts/oracle/templates/oracle.yml`

### What this file is for

- Kubernetes manifest template rendered by Helm.


### File contents (numbered)

```
  1| {{- $fullName := "oracle-db" -}}
  2| 
  3| # ---------------------------------------------------------------------------
  4| # Secret for credentials
  5| # ---------------------------------------------------------------------------
  6| apiVersion: v1
  7| kind: Secret
  8| metadata:
  9|   name: oracle-credentials
 10|   namespace: {{ .Values.global.namespace }}
 11| type: Opaque
 12| stringData:
 13|   ORACLE_PASSWORD: {{ default .Values.env.password .Values.global.oracle.password }}
 14|   ORACLE_USER: {{ default .Values.env.user .Values.global.oracle.user }}
 15|   ORACLE_JDBC_URL: {{ default .Values.env.jdbcUrl .Values.global.oracle.jdbc_url }}
 16| 
 17| ---
 18| 
 19| # ---------------------------------------------------------------------------
 20| # StatefulSet for Oracle XE
 21| # ---------------------------------------------------------------------------
 22| apiVersion: apps/v1
 23| kind: StatefulSet
 24| metadata:
 25|   name: {{ $fullName }}
 26|   namespace: {{ .Values.global.namespace }}
 27|   labels:
 28|     app: {{ $fullName }}
 29| spec:
 30|   serviceName: {{ $fullName }}
 31|   replicas: {{ .Values.replicaCount }}
 32|   selector:
 33|     matchLabels:
 34|       app: {{ $fullName }}
 35|   template:
 36|     metadata:
 37|       labels:
 38|         app: {{ $fullName }}
 39|     spec:
 40|       volumes:
 41|         - name: dshm
 42|           emptyDir:
 43|             medium: Memory
 44|             sizeLimit: 1Gi
 45|       containers:
 46|         - name: oracle
 47|           image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
 48|           imagePullPolicy: {{ .Values.image.pullPolicy }}
 49|           env:
 50|             - name: ORACLE_PASSWORD
 51|               valueFrom:
 52|                 secretKeyRef:
 53|                   name: oracle-credentials
 54|                   key: ORACLE_PASSWORD
 55|             - name: APP_USER
 56|               valueFrom:
 57|                 secretKeyRef:
 58|                   name: oracle-credentials
 59|                   key: ORACLE_USER
 60|             - name: APP_USER_PASSWORD
 61|               valueFrom:
 62|                 secretKeyRef:
 63|                   name: oracle-credentials
 64|                   key: ORACLE_PASSWORD
 65|           ports:
 66|             - containerPort: {{ .Values.service.port }}
 67|               name: sql
 68|           resources:
 69|             {{- toYaml .Values.resources | nindent 12 }}
 70|           volumeMounts:
 71|             - name: oracle-data
 72|               mountPath: /opt/oracle/oradata
 73|             - name: dshm
 74|               mountPath: /dev/shm
 75|           
 76|           {{- if .Values.startupProbe.enabled }}
 77|           startupProbe:
 78|             tcpSocket:
 79|               port: {{ .Values.startupProbe.tcpSocket.port }}
 80|             initialDelaySeconds: {{ .Values.startupProbe.initialDelaySeconds }}
 81|             periodSeconds: {{ .Values.startupProbe.periodSeconds }}
 82|             failureThreshold: {{ .Values.startupProbe.failureThreshold }}
 83|           {{- end }}
 84| 
 85|           {{- if .Values.livenessProbe.enabled }}
 86|           livenessProbe:
 87|             tcpSocket:
 88|               port: {{ .Values.livenessProbe.tcpSocket.port }}
 89|             initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
 90|             periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
 91|             failureThreshold: {{ .Values.livenessProbe.failureThreshold }}
 92|           {{- end }}
 93|   volumeClaimTemplates:
 94|     {{- if .Values.persistence.enabled }}
 95|     - metadata:
 96|         name: oracle-data
 97|       spec:
 98|         accessModes: {{ toYaml .Values.persistence.accessModes | nindent 8 }}
 99|         resources:
100|           requests:
101|             storage: {{ .Values.persistence.size }}
102|         {{- if .Values.persistence.storageClass }}
103|         storageClassName: {{ .Values.persistence.storageClass }}
104|         {{- end }}
105|     {{- else }}
106|     - metadata:
107|         name: oracle-data
108|       spec:
109|         accessModes: ["ReadWriteOnce"]
110|         storageClassName: ""
111|         resources:
112|           requests:
113|             storage: 1Gi
114|     {{- end }}
115| 
116| ---
117| 
118| # ---------------------------------------------------------------------------
119| # Service exposing Oracle port
120| # ---------------------------------------------------------------------------
121| apiVersion: v1
122| kind: Service
123| metadata:
124|   name: {{ $fullName }}
125|   namespace: {{ .Values.global.namespace }}
126|   labels:
127|     app: {{ $fullName }}
128| spec:
129|   type: {{ .Values.service.type }}
130|   selector:
131|     app: {{ $fullName }}
132|   ports:
133|     - name: sql
134|       port: {{ .Values.service.port }}
135|       targetPort: {{ .Values.service.port }}
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 6:** Kubernetes API group/version for this object.

- **Line 7:** The type of Kubernetes object (Deployment, Service, Ingress, etc.).

- **Line 8:** Object metadata (name, namespace, labels, annotations).

- **Line 11:** For Service/Secret/etc - specifies subtype (e.g., ClusterIP, LoadBalancer).

- **Line 22:** Kubernetes API group/version for this object.

- **Line 23:** The type of Kubernetes object (Deployment, Service, Ingress, etc.).

- **Line 24:** Object metadata (name, namespace, labels, annotations).

- **Line 29:** Desired state/specification for the object.

- **Line 36:** Object metadata (name, namespace, labels, annotations).

- **Line 39:** Desired state/specification for the object.

- **Line 40:** Defines storage attached to the Pod (PVCs, config, secrets, etc.).

- **Line 45:** List of containers that will run in the Pod.

- **Line 47:** Container image reference to pull/run (repo/name:tag).

- **Line 49:** Environment variables injected into the container.

- **Line 65:** Ports exposed by the container or service.

- **Line 68:** CPU/memory requests/limits for scheduling and isolation.

- **Line 70:** Defines storage attached to the Pod (PVCs, config, secrets, etc.).

- **Line 97:** Desired state/specification for the object.

- **Line 99:** CPU/memory requests/limits for scheduling and isolation.

- **Line 108:** Desired state/specification for the object.

- **Line 111:** CPU/memory requests/limits for scheduling and isolation.

- **Line 121:** Kubernetes API group/version for this object.

- **Line 122:** The type of Kubernetes object (Deployment, Service, Ingress, etc.).

- **Line 123:** Object metadata (name, namespace, labels, annotations).

- **Line 128:** Desired state/specification for the object.

- **Line 129:** For Service/Secret/etc - specifies subtype (e.g., ClusterIP, LoadBalancer).

- **Line 132:** Ports exposed by the container or service.


---

## `helm/telemetry-platform/charts/oracle/values.yaml`

### What this file is for

- Helm default values (your knobs).


### File contents (numbered)

```
 1| # Oracle subchart values (optimized and persistence-enabled)
 2| # These can be overridden by the parent telemetry-platform chart via .Values.global.oracle.*
 3| 
 4| replicaCount: 1
 5| 
 6| image:
 7|   repository: gvenzl/oracle-xe
 8|   tag: "21-slim"
 9|   pullPolicy: IfNotPresent
10| 
11| resources:
12|   requests:
13|     cpu: 500m
14|     memory: 2Gi
15|   limits:
16|     cpu: 2
17|     memory: 4Gi
18| 
19| service:
20|   type: ClusterIP
21|   port: 1521
22| 
23| persistence:
24|   enabled: true               # persistence ON by default
25|   size: 10Gi
26|   storageClass: ""            # leave empty to use the cluster default
27|   accessModes:
28|     - ReadWriteOnce
29|   existingClaim: ""           # reuse an existing PVC if provided
30| 
31| env:
32|   # Mirrors global.oracle but allows local overrides for standalone use
33|   user: telemetry
34|   password: telemetry_pw
35|   jdbcUrl: jdbc:oracle:thin:@oracle-db.telemetry.svc.cluster.local:1521/XEPDB1
36| 
37| labels: {}
38| annotations: {}
39| 
40| livenessProbe:
41|   enabled: true
42|   tcpSocket:
43|     port: 1521
44|   initialDelaySeconds: 240      # give it 4 minutes on first start
45|   periodSeconds: 15
46|   failureThreshold: 10
47| 
48| startupProbe:
49|   enabled: true
50|   tcpSocket:
51|     port: 1521
52|   initialDelaySeconds: 60
53|   periodSeconds: 15
54|   failureThreshold: 40          # 60 + 15*40 = ~660s max, plenty for cold start
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 4:** How many Pod replicas to run (Deployment replicas).

- **Line 6:** Image configuration block (repository/name/tag/pullPolicy, depending on your chart).

- **Line 11:** Default CPU/memory requests/limits for the chart.

- **Line 19:** Kubernetes Service configuration (type, ports).


---

## `helm/telemetry-platform/values.yaml`

### What this file is for

- Helm default values (your knobs).


### File contents (numbered)

```
 1| global:
 2|   namespace: telemetry
 3|   oracle:
 4|     password: telemetry_pw
 5|     user: telemetry
 6|     jdbc_url: jdbc:oracle:thin:@oracle-db.telemetry.svc.cluster.local:1521/XEPDB1
 7| 
 8| agent-ingest-svc:
 9|   image: agent-ingest-svc:release1
10|   replicas: 2
11| 
12| device-state-svc:
13|   image: device-state-svc:release1
14|   replicas: 1
15|   containerPort: 8081
16|   servicePort: 8080
17| 
18| ingress:
19|   host: telemetry.internal
```

### Line-by-line explanation (only lines that introduce a concept)

- **Line 18:** Ingress configuration (host/path/TLS/annotations).
