resource "null_resource" "kind_cluster" {
  provisioner "local-exec" {
    command = <<EOT
set -euo pipefail

# Write kind config with ingress label + host port mappings
cat > ${var.kind_config_path} <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${var.cluster_name}
nodes:
  - role: control-plane
    labels:
      ingress-ready: "true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
EOF

# Recreate cluster
kind delete cluster --name ${var.cluster_name} || true
kind create cluster --name ${var.cluster_name} --config ${var.kind_config_path}
EOT
  }
}

