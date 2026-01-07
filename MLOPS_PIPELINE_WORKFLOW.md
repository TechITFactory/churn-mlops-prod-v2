# V2 MLOps Pipeline Workflow

This document shows the complete MLOps pipeline for V2 (`churn-mlops-prod-v2`) and what we implemented at each phase.

---

## Visual Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        V2.0 MLOps Pipeline Workflow                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│                              ┌──────────────────┐                               │
│                              │     DVC REPRO    │ ← Single command runs all     │
│                              └────────┬─────────┘                               │
│                                       │                                          │
│    ┌──────────┬──────────┬───────────┼───────────┬──────────┬──────────┐       │
│    ▼          ▼          ▼           ▼           ▼          ▼          ▼       │
│ ┌──────┐  ┌──────┐  ┌──────┐  ┌──────────┐  ┌──────┐  ┌──────┐  ┌──────┐      │
│ │ DATA │─▶│VALID │─▶│PREP  │─▶│ FEATURES │─▶│LABELS│─▶│TRAIN │─▶│SCORE │      │
│ └──────┘  └──────┘  └──────┘  └──────────┘  └──────┘  └──────┘  └──────┘      │
│                                                              │                   │
│                                                              ▼                   │
│                                                      ┌──────────────┐           │
│                                                      │    MLFLOW    │           │
│                                                      │  (Tracking)  │           │
│                                                      └──────────────┘           │
│                                                                                  │
│ ┌─────────────────────────────────────────────────────────────────────────────┐ │
│ │                            KUBERNETES LAYER                                  │ │
│ ├─────────────────────────────────────────────────────────────────────────────┤ │
│ │                                                                              │ │
│ │  ┌─────────┐  ┌─────────┐  ┌───────────┐  ┌─────────────────────┐          │ │
│ │  │  API    │  │ MLflow  │  │ Prometheus│  │    CronJobs         │          │ │
│ │  │ Service │  │ Server  │  │ + Grafana │  │ ├─ Batch Score      │          │ │
│ │  └─────────┘  └─────────┘  └───────────┘  │ ├─ Drift Check      │          │ │
│ │                                            │ ├─ Drift Auto-Retrain│ ← NEW! │ │
│ │                                            │ └─ Weekly Retrain   │          │ │
│ │                                            └─────────────────────┘          │ │
│ └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│ ┌─────────────────────────────────────────────────────────────────────────────┐ │
│ │                         TERRAFORM (INFRA)                                    │ │
│ │  VPC → EKS → S3 Bucket → MLflow IRSA Role                                    │ │
│ └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: DATA (DVC Managed)

### What We Built
| Component | File | Purpose |
|-----------|------|---------|
| DVC Stage | `dvc.yaml` → `generate_data` | Tracked by DVC |
| Script | `scripts/generate_data.sh` | Same as V1 |

### Commands (V2 Way)
```bash
dvc repro generate_data
# Or run all:
dvc repro
```

### V1 → V2 Change
| V1 | V2 |
|----|-----|
| `make data` | `dvc repro generate_data` |
| Manual tracking | DVC tracks outputs in `data/raw/` |

---

## Phase 2: VALIDATE (DVC Managed)

### What We Built
| Component | File | Purpose |
|-----------|------|---------|
| DVC Stage | `dvc.yaml` → `validate_data` | Depends on `generate_data` |

### Commands
```bash
dvc repro validate_data
```

### V1 → V2 Change
| V1 | V2 |
|----|-----|
| `./scripts/validate_data.sh` | DVC manages dependency chain |

---

## Phase 3: PREPARE (DVC Managed)

### What We Built
| Component | File | Purpose |
|-----------|------|---------|
| DVC Stage | `dvc.yaml` → `prepare_data` | Clean + aggregate |
| Outputs | `data/processed/*.csv` | Tracked by DVC |

### V2 Addition
- DVC tracks `data/processed/users_clean.csv`, `events_clean.csv`, `user_daily.csv`

---

## Phase 4: FEATURES (DVC Managed)

### What We Built
| Component | File | Purpose |
|-----------|------|---------|
| DVC Stage | `dvc.yaml` → `build_features` | Rolling windows |
| DVC Stage | `dvc.yaml` → `build_labels` | Churn labels |
| DVC Stage | `dvc.yaml` → `build_training_set` | Merge features+labels |

### Commands
```bash
dvc repro build_training_set
# DVC automatically runs dependencies first
```

---

## Phase 5: TRAIN (DVC + MLflow)

### What We Built
| Component | File | Purpose |
|-----------|------|---------|
| DVC Stage | `dvc.yaml` → `train_baseline` | Training step |
| MLflow Logging | `src/churn_mlops/training/train_baseline.py` | Logs params, metrics, model |
| MLflow K8s | `k8s/mlflow/` | 7 manifests for MLflow server |

### Commands
```bash
# Local
dvc repro train_baseline
mlflow ui   # View at http://127.0.0.1:5000

# Kubernetes
kubectl apply -f k8s/mlflow/
```

### V1 → V2 Change
| V1 | V2 |
|----|-----|
| `make train` | `dvc repro train_baseline` |
| Terminal logs only | **MLflow tracks every run** |
| No experiment history | Compare runs in UI |

### What MLflow Logs
- **Params**: `test_size`, `class_weight`, feature windows
- **Metrics**: `pr_auc`, `roc_auc`, `accuracy`
- **Artifacts**: Model file, metrics JSON

---

## Phase 6: DEPLOY (Enhanced)

### What We Built
| Component | File | Purpose |
|-----------|------|---------|
| API | Same as V1 | FastAPI |
| MLflow Server | `k8s/mlflow/*.yaml` | Experiment tracking in K8s |
| Monitoring | `k8s/monitoring/` | Prometheus ServiceMonitor |
| Grafana Config | `monitoring/grafana-provisioning/` | Dashboard provisioning |

### Commands
```bash
kubectl apply -f k8s/plain/
kubectl apply -f k8s/mlflow/
kubectl apply -f k8s/monitoring/
```

### V1 → V2 Change
| V1 | V2 |
|----|-----|
| API only | API + **MLflow Server** |
| ServiceMonitor only | **Prometheus + Grafana configs** |

---

## Phase 7: SCORE (DVC Managed)

### What We Built
| Component | File | Purpose |
|-----------|------|---------|
| DVC Stage | `dvc.yaml` → `batch_score` | Final pipeline stage |

### Commands
```bash
dvc repro batch_score
# Runs entire pipeline if needed, outputs to data/predictions/
```

---

## Phase 8: MONITOR (Enhanced)

### What We Built
| Component | File | Purpose |
|-----------|------|---------|
| Drift Check | Same as V1 | PSI calculation |
| Prometheus | `monitoring/prometheus.yml` | Scrape configuration |
| Grafana | `monitoring/grafana-provisioning/` | Dashboard setup |
| ServiceMonitor | `k8s/monitoring/servicemonitor.yaml` | Prometheus operator |

### V1 → V2 Change
| V1 | V2 |
|----|-----|
| PSI drift only | PSI + **Prometheus metrics** |
| No dashboards | **Grafana dashboards** |

---

## Phase 9: RETRAIN (Auto on Drift!)

### What We Built
| Component | File | Purpose |
|-----------|------|---------|
| Auto-Retrain | `k8s/drift-auto-retrain-cronjob.yaml` | **NEW!** Retrain when drift detected |
| High Drift Alert | `k8s/high-drift-cronjob.yaml` | **NEW!** Alert on extreme drift |

### Commands
```bash
kubectl apply -f k8s/drift-auto-retrain-cronjob.yaml
kubectl apply -f k8s/high-drift-cronjob.yaml
```

### V1 → V2 Change
| V1 | V2 |
|----|-----|
| Weekly retrain only | Weekly + **Auto-retrain on drift** |
| Manual drift response | **Automated response** |

---

## Infrastructure (Enhanced)

### What We Built (Terraform)
| Component | V1 | V2 |
|-----------|-----|-----|
| VPC | ✅ | ✅ |
| EKS | ✅ | ✅ |
| EBS CSI | ✅ | ✅ |
| **S3 Bucket** | ❌ | ✅ (versioned, encrypted) |
| **MLflow IRSA** | ❌ | ✅ (S3 access for MLflow) |

### Commands
```bash
cd terraform
terraform init
terraform apply
```

---

## Kubeflow Pipeline (Optional)

### What We Built
| Component | File | Purpose |
|-----------|------|---------|
| Pipeline Definition | `pipelines/kfp_pipeline.py` | Full ML workflow as DAG |

### Commands
```bash
python pipelines/kfp_pipeline.py
# Outputs: pipelines/churn_pipeline.yaml
# Upload to Kubeflow UI
```

---

## V2 Complete Command Flow

```bash
# 1. Setup
git clone https://github.com/TechITFactory/churn-mlops-prod-v2.git
cd churn-mlops-prod-v2
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements/dev.txt && pip install -e .

# 2. Run pipeline (ONE COMMAND!)
dvc repro

# 3. View experiments
mlflow ui   # http://127.0.0.1:5000

# 4. Provision infra
cd terraform && terraform apply
aws eks update-kubeconfig --name churn-mlops

# 5. Deploy
kubectl apply -f k8s/plain/
kubectl apply -f k8s/mlflow/
kubectl apply -f k8s/drift-auto-retrain-cronjob.yaml

# 6. Test
kubectl -n churn-mlops port-forward svc/churn-api 8000:8000
curl http://localhost:8000/ready
```

---

## Summary: V1 vs V2 at Each Phase

| Phase | V1 | V2 |
|-------|-----|-----|
| **DATA** | `make data` | `dvc repro generate_data` |
| **VALIDATE** | Shell script | DVC dependency chain |
| **FEATURES** | `make features` | `dvc repro build_features` |
| **TRAIN** | `make train` | `dvc repro train_baseline` + **MLflow** |
| **DEPLOY** | API only | API + **MLflow Server** + **Grafana** |
| **SCORE** | `make batch` | `dvc repro batch_score` |
| **MONITOR** | PSI only | PSI + **Prometheus + Grafana** |
| **RETRAIN** | Weekly CronJob | Weekly + **Auto on Drift** |
| **INFRA** | EKS only | EKS + **S3 + MLflow IRSA** |
| **ORCHESTRATION** | CronJobs | CronJobs + **Kubeflow Pipeline** |

---

## Key Takeaways

1. **DVC** replaces `make all` with `dvc repro` - reproducible, cached, versioned
2. **MLflow** logs every training run - compare experiments, audit history
3. **Terraform** provisions S3 + IRSA for MLflow artifacts
4. **Auto-retrain** responds to drift automatically
5. **Monitoring stack** provides visibility into API and model performance
