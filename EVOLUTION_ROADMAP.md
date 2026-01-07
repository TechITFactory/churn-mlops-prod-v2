# MLOps Evolution Roadmap: V1 → V2 → V3 → V4

This document shows the complete journey from a student project to an enterprise-scale ML platform.

---

## Visual Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MLOps Maturity Journey                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  V1.0 (Delivered)          V2.0 (Delivered)         V3.0 (Next)             │
│  ═══════════════          ═══════════════          ═══════════             │
│                                                                              │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐          │
│  │ Shell       │    →     │ DVC         │    →     │ Great       │          │
│  │ Scripts     │          │ Pipelines   │          │ Expectations│          │
│  └─────────────┘          └─────────────┘          └─────────────┘          │
│                                                                              │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐          │
│  │ Terminal    │    →     │ MLflow      │    →     │ Feature     │          │
│  │ Logs        │          │ Tracking    │          │ Store       │          │
│  └─────────────┘          └─────────────┘          └─────────────┘          │
│                                                                              │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐          │
│  │ Manual      │    →     │ Terraform   │    →     │ Trivy +     │          │
│  │ AWS Console │          │ IaC         │          │ SonarQube   │          │
│  └─────────────┘          └─────────────┘          └─────────────┘          │
│                                                                              │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐          │
│  │ K8s         │    →     │ Kubeflow    │    →     │ Spark /     │          │
│  │ CronJobs    │          │ Pipelines   │          │ Kafka       │          │
│  └─────────────┘          └─────────────┘          └─────────────┘          │
│                                                                              │
│                                                     V4.0 (Future)            │
│                                                     ═══════════             │
│                                                    ┌─────────────┐          │
│                                                    │ Multi-Region│          │
│                                                    │ + A/B Tests │          │
│                                                    └─────────────┘          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# V1.0 — The Student Project (Delivered ✅)

**Repo**: `churn-mlops-prod`

## What We Built
| Component | Implementation |
|-----------|----------------|
| **Data Pipeline** | Shell scripts (`./scripts/generate_data.sh`) |
| **Training** | `python -m churn_mlops.training.train_baseline` |
| **Serving** | FastAPI on Kubernetes |
| **CI/CD** | GitHub Actions (lint, test, build) |
| **GitOps** | ArgoCD for deployments |
| **Infra** | Terraform (VPC + EKS) |

## Workflow
```bash
make data        # Generate synthetic data
make train       # Train model
docker build     # Build images
kubectl apply    # Deploy to K8s
```

## Limitations
- ❌ No data versioning
- ❌ No experiment tracking
- ❌ Manual script execution
- ❌ No monitoring dashboards

---

# V2.0 — The Professional Product (Delivered ✅)

**Repo**: `churn-mlops-prod-v2`

## What We Added
| Component | V1.0 | V2.0 |
|-----------|------|------|
| **Pipeline** | Shell scripts | **DVC** (`dvc repro`) |
| **Experiments** | Terminal logs | **MLflow** (UI + S3 artifacts) |
| **Orchestration** | CronJobs | **Kubeflow Pipelines** |
| **Monitoring** | ServiceMonitor only | **Prometheus + Grafana** |
| **Infra** | EKS only | EKS + **S3 bucket** + **IRSA** |
| **Drift** | Manual check | **Auto-retrain on drift** |

## New Files
```
dvc.yaml                          # 8-stage pipeline
k8s/mlflow/                       # MLflow K8s deployment
pipelines/kfp_pipeline.py         # Kubeflow Pipeline
monitoring/prometheus.yml         # Prometheus config
terraform/main.tf                 # S3 + MLflow IRSA
```

## Workflow
```bash
dvc repro              # Run entire ML pipeline
mlflow ui              # View experiments
terraform apply        # Provision infra
kubectl apply -f k8s/  # Deploy everything
```

---

# V3.0 — Enterprise Grade (Next Phase)

## What to Add
| Component | Purpose |
|-----------|---------|
| **Great Expectations** | Data quality tests with HTML reports |
| **Feast** | Feature Store (online + offline) |
| **Trivy** | Container security scanning |
| **SonarQube** | Code security scanning |
| **OpenTelemetry** | Distributed tracing |

## Workflow Changes
```bash
# Data Quality Gate
great_expectations checkpoint run churn_suite

# Feature Store
feast apply                    # Define features
feast materialize              # Sync to online store

# Security Scan
trivy image techitfactory/churn-api:$VER
```

## New Files (To Create)
```
great_expectations/
├── expectations/
│   └── churn_data_suite.json
└── checkpoints/
    └── churn_checkpoint.yml

feature_repo/
├── feature_store.yaml
├── features.py
└── entities.py

.github/workflows/security.yml    # Trivy + SonarQube
```

---

# V4.0 — Scale & Experimentation (Future)

## What to Add
| Component | Purpose |
|-----------|---------|
| **Spark/Databricks** | Process TB-scale data |
| **Kafka/Flink** | Real-time streaming |
| **A/B Testing** | Compare model variants in production |
| **Multi-Region** | Disaster recovery, global latency |
| **Canary Deployments** | Gradual rollouts with Argo Rollouts |

## Architecture Change
```
                    ┌─────────────┐
                    │   Kafka     │
                    │  (Events)   │
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │  Flink      │ │  Spark      │ │  API        │
    │  (Realtime) │ │  (Batch)    │ │  (Serving)  │
    └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
           │               │               │
           └───────────────┼───────────────┘
                           ▼
                    ┌─────────────┐
                    │   Feast     │
                    │  (Features) │
                    └─────────────┘
```

## Workflow
```bash
# Submit Spark job
spark-submit --master k8s://... feature_pipeline.py

# Deploy with canary
kubectl argo rollouts set image churn-api=churn-api:v3
kubectl argo rollouts promote churn-api
```

---

# Summary: The Evolution

| Version | Focus | Key Tech | Status |
|---------|-------|----------|--------|
| **V1.0** | Make it work | Shell, K8s, ArgoCD | ✅ Delivered |
| **V2.0** | Make it reproducible | DVC, MLflow, Kubeflow | ✅ Delivered |
| **V3.0** | Make it reliable | GX, Feast, Security | 🔜 Next |
| **V4.0** | Make it scale | Spark, Kafka, A/B | 📋 Future |

---

# Quick Reference: Commands by Version

| Action | V1 | V2 | V3 | V4 |
|--------|-----|-----|-----|-----|
| Run Pipeline | `make all` | `dvc repro` | `dvc repro` | `spark-submit` |
| Track Experiments | ❌ | `mlflow ui` | `mlflow ui` | `mlflow ui` |
| Validate Data | `python validate.py` | `dvc repro validate` | `great_expectations` | `great_expectations` |
| Get Features | Load CSV | Load CSV | `feast get-features` | `feast get-features` |
| Security Scan | ❌ | ❌ | `trivy image` | `trivy image` |
| Deploy | `kubectl apply` | `kubectl apply` | `argo rollouts` | `argo rollouts` |
