# Security & Authentication

## 1. Overview

Security is introduced progressively through releases:

| Release | Security Feature |
|----------|------------------|
| R1–R2 | Internal only, no authentication |
| R3 | TLS via NGINX Ingress |
| R4 | Secure secrets handling in Kubernetes |
| R5 | API-key authentication and role-based access |

---

## 2. API Gateway Authentication (Release 5)

### Flow

1. Client sends requests with an API key header:

```
X-API-Key: <token>
```

2. NGINX Ingress validates the key against a ConfigMap or Redis store.  
3. The ingress injects role metadata as headers:
   - `X-Caller-Role: ingest`
   - `X-Caller-Role: read`
4. Downstream services authorize based on the header.

### Roles

| Role | Permissions |
|------|--------------|
| **ingest** | Access `/telemetry` |
| **read** | Access `/devices/**` |
| **admin** | Access metrics and config endpoints |

API keys can be rotated via ConfigMap update or REST management endpoint.

---

## 3. Service-to-Service Security

- **Kafka**: SASL/SSL authentication for producers and consumers.  
- **Redis**: password-protected, limited network access via K8s NetworkPolicy.  
- **Oracle**: JDBC SSL enabled; credentials from Secrets.  
- Each service uses least-privilege principle in its connection configuration.

---

## 4. Secrets Management

- All credentials (DB, Kafka, Redis, API-keys) stored in Kubernetes Secrets.  
- Gradle builds inject environment variables via CI pipeline.  
- Example secret manifest:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: oracle-credentials
type: Opaque
data:
  username: b3JhY2xlX3VzZXI=
  password: c2VjdXJlcGFzcw==
```

---

## 5. Transport Security

- NGINX Ingress terminates HTTPS using Let's Encrypt or self-signed TLS.
- Internal pod-to-pod communication restricted to cluster network.
- Future: mutual TLS between internal microservices.

---

## 6. Logging & Audit

- All API calls logged with request ID, user, and role.
- Audit log shipped to centralized storage (Elastic / Loki).
- Suspicious or repeated failed requests trigger alerts.

---

## 7. Future Enhancements

- OIDC / JWT token-based authentication.
- Fine-grained RBAC at service level.
- Integration with Vault for dynamic secret rotation.
- Signed telemetry payloads using public/private key pairs on agents.
- NetworkPolicy hardening for zero-trust deployment.
