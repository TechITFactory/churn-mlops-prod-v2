# V2 Complete Command Reference (From Scratch)

This document contains **every command** to run v2.0 from scratch, including all the new tools (DVC, MLflow, Kubeflow).

---

# PHASE 1: Clone & Setup

```bash
# Clone v2 repository
git clone https://github.com/TechITFactory/churn-mlops-prod-v2.git
cd churn-mlops-prod-v2

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install all dependencies
pip install -r requirements/base.txt
pip install -r requirements/dev.txt
pip install -r requirements/api.txt
pip install -e .

# Verify installation
python -c "from churn_mlops.common.config import load_config; print('OK')"
```

---

# PHASE 2: Run Pipeline with DVC

## Initialize DVC (First Time Only)
```bash
dvc init
```

## Run the Complete Pipeline
```bash
dvc repro
```

**This runs 8 stages:**
1. `generate_data` - Creates synthetic users.csv and events.csv
2. `validate_data` - Runs data quality checks
3. `prepare_data` - Cleans and aggregates data
4. `build_features` - Creates rolling window features
5. `build_labels` - Creates churn labels
6. `build_training_set` - Merges features + labels
7. `train_baseline` - Trains logistic regression model
8. `batch_score` - Scores all users

## Verify Pipeline Ran
```bash
# Check data created
ls -la data/raw/
ls -la data/processed/
ls -la data/features/

# Check models created
ls -la artifacts/models/
ls -la artifacts/metrics/

# Check predictions
ls -la data/predictions/
```

## Run Specific Stage
```bash
dvc repro build_features   # Only this stage + dependencies
```

## View Pipeline DAG
```bash
dvc dag
```

---

# PHASE 3: Experiment Tracking with MLflow

## Start MLflow UI (New Terminal)
```bash
# Open a NEW terminal
cd churn-mlops-prod-v2
source .venv/bin/activate

# Start MLflow UI
mlflow ui
```

**Open browser:** http://127.0.0.1:5000

## What to Check in MLflow
- Click on experiment: `churn` or `churn-prediction`
- See logged runs from training
- Compare PR-AUC and ROC-AUC metrics
- View model artifacts

## Run Another Experiment
```bash
# In first terminal, modify params
nano params.yaml          # Change churn_base_rate or test_size

# Re-run pipeline
dvc repro

# Refresh MLflow UI - see new run!
```

---

# PHASE 4: Run API Locally

```bash
# Set config
export CHURN_MLOPS_CONFIG=./config/config.yaml

# Start API
uvicorn churn_mlops.api.app:app --host 0.0.0.0 --port 8000
```

## Test API Endpoints
```bash
# In another terminal
curl http://localhost:8000/health
curl http://localhost:8000/ready
curl http://localhost:8000/metrics
```

---

# PHASE 5: Build Docker Images

```bash
# Stop API (Ctrl+C)

# Set version
export VER=0.2.0

# Build ML image
docker build -t techitfactory/churn-ml:$VER -f docker/Dockerfile.ml .

# Build API image
docker build -t techitfactory/churn-api:$VER -f docker/Dockerfile.api .

# Verify
docker images | grep churn
```

## Push to Docker Hub
```bash
docker login
docker push techitfactory/churn-ml:$VER
docker push techitfactory/churn-api:$VER
```

---

# PHASE 6: Provision EKS with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply (creates VPC, EKS, S3 bucket, MLflow IRSA)
terraform apply -auto-approve

# Get cluster name
terraform output cluster_name
```

## Configure kubectl
```bash
aws eks --region us-east-1 update-kubeconfig --name churn-mlops
kubectl config set-context --current --namespace=churn-mlops

# Verify connection
kubectl get nodes
```

---

# PHASE 7: Deploy to Kubernetes

## Core Infrastructure
```bash
cd ..   # Back to repo root

kubectl apply -f k8s/plain/namespace.yaml
kubectl apply -f k8s/plain/pvc.yaml
kubectl apply -f k8s/plain/configmap.yaml
```

## Deploy MLflow (V2 Addition!)
```bash
kubectl apply -f k8s/mlflow/
kubectl -n churn-mlops get pods | grep mlflow

# Port forward to access MLflow UI
kubectl -n churn-mlops port-forward svc/mlflow 5000:5000 &
```

## Run Seed Job
```bash
kubectl apply -f k8s/plain/seed-model-job.yaml
kubectl -n churn-mlops wait --for=condition=complete job/churn-seed-model --timeout=900s
kubectl -n churn-mlops logs -f job/churn-seed-model
```

## Deploy API
```bash
kubectl apply -f k8s/plain/api-deployment.yaml
kubectl apply -f k8s/plain/api-service.yaml
kubectl -n churn-mlops wait --for=condition=ready pod -l app=churn-api --timeout=180s
```

## Deploy CronJobs (Including New Drift-Auto-Retrain!)
```bash
kubectl apply -f k8s/batch-cronjob.yaml
kubectl apply -f k8s/drift-cronjob.yaml
kubectl apply -f k8s/drift-auto-retrain-cronjob.yaml    # V2 Addition!
kubectl apply -f k8s/retrain-cronjob.yaml
kubectl -n churn-mlops get cronjobs
```

## Test API
```bash
kubectl -n churn-mlops port-forward svc/churn-api 8000:8000 &
curl http://localhost:8000/ready
```

---

# PHASE 8: Deploy Monitoring (Prometheus + Grafana)

```bash
# Apply monitoring config
kubectl apply -f k8s/monitoring/

# Check ServiceMonitor
kubectl -n churn-mlops get servicemonitor
```

---

# PHASE 9: Compile Kubeflow Pipeline (Optional)

```bash
# Compile pipeline
python pipelines/kfp_pipeline.py

# Output: pipelines/churn_pipeline.yaml
ls -la pipelines/

# Upload to Kubeflow UI if you have a cluster
```

---

# Operations Commands (V2)

## Trigger DVC on Kubernetes
```bash
kubectl -n churn-mlops exec deploy/churn-api -- dvc repro
kubectl -n churn-mlops exec deploy/churn-api -- dvc push
```

## Manual Retrain with MLflow Logging
```bash
kubectl -n churn-mlops create job --from=cronjob/churn-retrain-weekly retrain-manual-$(date +%s)
kubectl -n churn-mlops wait --for=condition=complete job/retrain-manual-* --timeout=600s

# Check MLflow for new run
kubectl -n churn-mlops port-forward svc/mlflow 5000:5000 &
# Open http://localhost:5000
```

## Check Drift Status
```bash
kubectl -n churn-mlops exec deploy/churn-api -- cat /app/artifacts/metrics/data_drift_latest.json
```

## View MLflow on Kubernetes
```bash
kubectl -n churn-mlops port-forward svc/mlflow 5000:5000 &
# Open http://localhost:5000
```

---

# V1 vs V2 Command Comparison

| Action | V1 Command | V2 Command |
|--------|------------|------------|
| Run pipeline | `make all` | `dvc repro` |
| Track experiments | ❌ | `mlflow ui` |
| View pipeline graph | ❌ | `dvc dag` |
| Infra provision | `terraform apply` (EKS only) | `terraform apply` (EKS + S3 + IRSA) |
| Deploy MLflow | ❌ | `kubectl apply -f k8s/mlflow/` |
| Auto-retrain on drift | ❌ | `kubectl apply -f k8s/drift-auto-retrain-cronjob.yaml` |
| Compile Kubeflow | ❌ | `python pipelines/kfp_pipeline.py` |

---

# Quick Reference

| Task | Command |
|------|---------|
| Setup | `pip install -r requirements/dev.txt && pip install -e .` |
| Run pipeline | `dvc repro` |
| View DAG | `dvc dag` |
| Start MLflow | `mlflow ui` |
| Build images | `docker build -t image:tag -f Dockerfile .` |
| Provision infra | `cd terraform && terraform apply` |
| Connect to EKS | `aws eks update-kubeconfig --name churn-mlops` |
| Deploy all | `kubectl apply -f k8s/plain/ && kubectl apply -f k8s/mlflow/` |
| Port forward API | `kubectl -n churn-mlops port-forward svc/churn-api 8000:8000` |
| Port forward MLflow | `kubectl -n churn-mlops port-forward svc/mlflow 5000:5000` |
