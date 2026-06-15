markdown# ☁️ CloudAura — Production-Grade Microservices Platform on AWS EKS

![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)
![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes-326CE5?logo=kubernetes)
![GitHub Actions](https://img.shields.io/badge/CI/CD-GitHub_Actions-2088FF?logo=github-actions)
![Istio](https://img.shields.io/badge/Service_Mesh-Istio-466BB0?logo=istio)

> A fully automated, production-grade e-commerce microservices platform — built from scratch using industry best practices in infrastructure automation, GitOps, Kubernetes workload isolation, and cost-optimized compute.

---

## 🧠 Why I Built This

Most DevOps projects stop at "deploy a container." This project goes further — every architectural decision has a real-world reason behind it: node isolation to prevent noisy-neighbor problems, Karpenter for cost-optimized autoscaling, External Secrets so credentials never touch Git, and a shared Helm chart so new services take minutes to onboard.

---

## 🏗️ High-Level Architecture
Developer Push

│

▼

GitHub Actions (CI)

├── Detects changed service via git diff

├── Builds Docker image

├── Tags with semver (v1.0.<run_number>)

└── Pushes to AWS ECR

│

▼

ArgoCD Image Updater

└── Detects new ECR tag → updates Helm values in Git

│

▼

ArgoCD (GitOps)

└── Auto-syncs Helm chart to EKS

│

▼

AWS EKS Cluster

├── System Nodes    → CoreDNS, kube-proxy, EBS CSI

├── Infra Nodes     → ArgoCD, Nginx, Prometheus, Grafana, Istio

└── App Nodes       → Microservices (Karpenter Spot)

│

▼

AWS Managed Services

├── RDS PostgreSQL  (per-service DB isolation)

├── ElastiCache Redis (TLS + auth token)

└── Secrets Manager (synced via External Secrets)

---

## 🚀 Tech Stack

| Category | Technology | Purpose |
|----------|-----------|---------|
| Cloud | AWS | EKS, RDS, ElastiCache, ECR, Secrets Manager, Route53, NLB |
| IaC | Terraform | Full infrastructure automation |
| Orchestration | Kubernetes 1.35 | Container orchestration |
| GitOps | ArgoCD + Image Updater | Declarative, automated deployments |
| CI/CD | GitHub Actions | Build, tag, push pipeline |
| Service Mesh | Istio | mTLS, traffic management |
| Ingress | NGINX Ingress Controller | TLS termination, routing |
| TLS | cert-manager + Let's Encrypt | Automated certificate management |
| Secrets | External Secrets Operator | AWS Secrets Manager → K8s Secrets |
| Node Autoscaling | Karpenter | Spot-first, cost-optimized provisioning |
| Pod Autoscaling | HPA + Metrics Server | CPU-based horizontal scaling |
| Monitoring | Kube Prometheus Stack + Grafana | Full observability |
| Packaging | Helm (shared chart) | One chart serves all microservices |
| Canary | Argo Rollouts | Progressive delivery support |

---

## 🗂️ Repository Structure
├── Terraform/

│   ├── eks.tf              # EKS cluster, node groups, taints

│   ├── eks-addons.tf       # NGINX, External Secrets, LB Controller

│   ├── helm-releases.tf    # ArgoCD, Prometheus, Istio, Karpenter

│   ├── secrets.tf          # RDS, Redis, Secrets Manager

│   ├── networking.tf       # VPC, subnets, Route53, NLB

│   ├── security.tf         # IAM, Pod Identity, Security Groups

│   └── templates/          # Karpenter NodePool, NodeClass

├── k8s-manifest/

│   └── helm/microservice/  # Shared Helm chart for all services

├── argocd/                 # ArgoCD Application manifests

└── services/               # Per-service Helm values

├── auth-values.yaml

├── product-values.yaml

├── order-values.yaml

├── notif-values.yaml

└── frontend-values.yaml

---

## 🔧 Infrastructure Deep Dive

### Node Isolation Strategy (3-Tier)

One of the most important architectural decisions — workloads are separated across 3 dedicated node groups with taints and tolerations so they never interfere with each other:

| Node Group | Taint | Runs | Instance Type |
|-----------|-------|------|--------------|
| `system` | `CriticalAddonsOnly=true:NoSchedule` | CoreDNS, kube-proxy, EBS CSI | c7i-flex.large (On-Demand) |
| `infra` | `InfraOnly=true:NoSchedule` | ArgoCD, Prometheus, Grafana, Nginx, Istio | c7i-flex.large (On-Demand) |
| `app` | none | Microservices | Karpenter Spot |

Only components with matching tolerations can schedule on system/infra nodes — microservices cannot accidentally land on infra nodes and starve critical tooling.

### Karpenter — Cost-Optimized App Nodes

Microservices run on Karpenter-provisioned **Spot instances**, cutting compute costs significantly. Karpenter provisions nodes on-demand based on pending pods — no over-provisioning, no wasted capacity.

### Automated Secret Management

All secrets are generated and managed entirely by Terraform — zero manual intervention:

- `random_password` generates unique passwords for master DB, per-service DB users, JWT secret, and Redis auth token
- Per-service database users and databases are provisioned via `null_resource` with `local-exec` running psql — executed on a **self-hosted GitHub Actions runner** (only runner with VPC access to RDS)
- Secrets stored in AWS Secrets Manager, synced to Kubernetes via External Secrets Operator
- Secrets never appear in Git or CI logs

### Database Isolation

Each microservice gets its own PostgreSQL database and user with scoped permissions — a compromise of one service cannot access another service's data.

### ElastiCache Redis

Production-grade Redis replication group with:
- TLS in-transit encryption (`transit_encryption_enabled = true`)
- Token-based authentication (`auth_token`)
- 2-node replication for availability

### DNS & Networking

- Route53 hosted zone with wildcard `*.cloudaura.online` A record aliased to NLB
- NLB in IP target mode — traffic goes directly to pod IPs, no double NAT
- Custom Security Group allows NLB → pod traffic, node-to-node communication, and Kubelet API access

---

## 🔐 Security Practices

- **Zero static AWS credentials** — GitHub Actions authenticates via OIDC (`sts:AssumeRoleWithWebIdentity`)
- **EKS Pod Identity** for in-cluster AWS access (EBS CSI, ArgoCD Image Updater) — no service account annotations needed
- **Secrets never in Git** — all credentials generated by Terraform, stored in Secrets Manager
- **Per-service DB isolation** — scoped users and databases
- **Network Policies** — inter-service traffic restricted to allowed services only
- **mTLS** via Istio for service-to-service encryption
- **TLS on all endpoints** via cert-manager + Let's Encrypt
- **ECR image scanning** enabled on push for all repositories

---

## 💰 Cost Optimization

- **Karpenter Spot instances** for all microservice workloads
- **Single NAT Gateway** (staging environment)
- **t4g.micro** for ElastiCache (ARM-based, cheaper)
- **t3.micro** for RDS (right-sized for staging)
- Karpenter consolidates underutilized nodes automatically — no idle capacity

---

## 🔄 CI/CD Pipeline

```yaml
On push to main:
  1. git diff detects which service changed
  2. Docker image built from service Dockerfile
  3. Tagged as v1.0.<github.run_number>
  4. Pushed to service-specific ECR repo
  5. ArgoCD Image Updater detects new semver tag
  6. Updates image.tag in Helm values.yaml in Git
  7. ArgoCD auto-syncs → rolling update on EKS
```

- Matrix strategy builds all 5 services in parallel
- DB initialization runs on self-hosted runner (VPC access required for psql)
- OIDC — no AWS_ACCESS_KEY_ID ever stored in GitHub secrets

---

## 📊 Observability

- **Prometheus** scrapes metrics from all services, ArgoCD, NGINX, and Kubernetes components
- **Grafana** dashboards at `https://grafana.cloudaura.online`
- **ServiceMonitors** configured for ArgoCD server, controller, and repo-server
- **ArgoCD UI** at `https://argocd.cloudaura.online` for deployment visibility

---

## 🌐 Live Endpoints

| Service | URL |
|---------|-----|
| Frontend | https://cloudaura.online |
| ArgoCD | https://argocd.cloudaura.online |
| Grafana | https://grafana.cloudaura.online |
| Auth API | https://auth.cloudaura.online/auth/docs |
| Product API | https://product.cloudaura.online/products/docs |
| Order API | https://order.cloudaura.online/orders/docs |

---

## 🧩 Microservices

| Service | Language | Database | Cache | Auth |
|---------|----------|----------|-------|------|
| Auth | FastAPI (Python) | PostgreSQL | — | JWT |
| Product | FastAPI (Python) | PostgreSQL | Redis | JWT (via Auth) |
| Order | FastAPI (Python) | PostgreSQL | Redis pub/sub | JWT (via Auth) |
| Notification | Node.js | — | Redis subscriber | — |
| Frontend | React + Vite + Nginx | — | — | JWT (localStorage) |

---

## 🏛️ Key Architectural Decisions

| Decision | Reason |
|----------|--------|
| Shared Helm chart | One chart, per-service values — new service onboarding in minutes |
| Node taints per workload tier | Prevent noisy-neighbor, protect critical infra from app workloads |
| Karpenter over Cluster Autoscaler | Faster, smarter, Spot-aware provisioning |
| External Secrets over sealed-secrets | Native AWS integration, no key rotation overhead |
| ArgoCD Image Updater | Fully automated image promotion without manual PR merges |
| Self-hosted runner for DB init | Only runner with private VPC access to RDS — security by design |
| EKS Pod Identity over IRSA | Simpler, no annotation required, AWS recommended approach |You said: ye image kaha se ae giye image kaha se
