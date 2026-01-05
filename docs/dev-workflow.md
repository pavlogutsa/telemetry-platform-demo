# Development Workflow

## Typical inner loop
- Services often run locally for fast iteration
- Cluster dependencies are accessed via port-forward (DB, Kafka, etc.)
- Kubernetes is used for integration testing and parity checks

## Debugging Java in Kubernetes (VS Code)
- Enable JDWP in the pod (port 5005)
- `kubectl port-forward` to localhost
- Attach VS Code Java debugger (request=attach, host=localhost, port=5005)

## Kubernetes images (dev)
- Build image
- Tag it exactly as referenced by Helm values
- Load it into kind
- Ensure Helm values match the full image name
