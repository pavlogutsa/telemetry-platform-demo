# Vision & Scope

## Purpose
The Telemetry Platform is a simulated endpoint-monitoring system.  
Its goal is to demonstrate a production-grade cloud backend architecture using **Java 21**, **Spring Boot 3**, **Kafka**, **Redis**, **Oracle**, and **Kubernetes**, packaged with full CI/CD and documentation pipelines.

## Objectives
- Collect and process large volumes of telemetry data from distributed device agents.
- Provide real-time and historical visibility into device health.
- Demonstrate fault-tolerant microservices and event-driven design.
- Showcase modern engineering practices:
  - CI/CD with GitHub Actions
  - Infrastructure as Code (Helm, Terraform)
  - Observability and monitoring
  - Automated testing (JUnit5, AssertJ, Mockito, Testcontainers)
  - Documentation as code (MkDocs + GitHub Pages)

## Out of Scope
- User interfaces or dashboards.
- Authentication federation or user management beyond API keys.
- Billing, tenant management, or analytics.

## Stakeholders
- **Developers / DevOps engineers** – exploring system integration.
- **Hiring managers or reviewers** – validating architectural and coding competence.
- **Learners** – experimenting with distributed Java stacks.

## Success Criteria
- All services deployable locally on Kubernetes or Oracle Cloud.
- Observable, tested, and documented system.
- Each release incrementally adds real functionality and complexity.
