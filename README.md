# churn-mlops-prod
# Section 13 — Capstone: Production Readiness Close (Student Pack)

This pack gives you copy‑paste friendly files to finish the course and hand to students.

You will create:

* `docs/runbook.md`
* `docs/rollback.md`
* `docs/final-checklist.md`
* `scripts/happy_path_local.sh`
* `scripts/k8s_smoke.sh`

> Notes based on your latest state:
>
> * You already have working K8s in `churn-mlops` with images around **0.1.4**.
> * Helm will be fixed later.
> * The batch score+proxy CronJob failed earlier because the container tried to run `./scripts/*.sh` that were not inside the image. For Section 13 we won’t change that.

---

## 13.0 Create folders

```bash
mkdir -p docs scripts
```

---

## 13.1 Runbook (setup → train → batch → serve → monitor)

````bash
cat << 'EOF' > docs/runbook.md
# TechITFactory Churn MLOps — Runbook

A single, student-friendly runbook for:
DATA → TRAIN → DEPLOY → MONITOR → RETRAIN

This repo supports two execution modes:
1) Local Python
2) Kubernetes (Minikube)

---

## 1) Prerequisites

- Python 3.10+
- make
- docker
- kubectl
- minikube

---

## 2) Local Python — Happy Path

### 2.1 Create venv + install

```bash
python -m venv .venv
source .venv/bin/activate
pip install -U pip

# Base + dev
pip install -r requirements/base.txt
pip install -r requirements/dev.txt

# API runtime deps
pip install -r requirements/api.txt

# Editable install
pip install -e .
````

### 2.2 Lint + tests

```bash
make lint
make test
```

### 2.3 Train baseline end-to-end

```bash
./scripts/seed_model_local.sh
```

### 2.4 Batch score

```bash
./scripts/batch_score.sh
```

### 2.5 Score proxy (needs batch output)

```bash
./scripts/score_proxy.sh
```

---

## 3) Local API

### 3.1 Run FastAPI locally

```bash
export CHURN_MLOPS_CONFIG=./config/config.yaml
uvicorn churn_mlops.api.app:app --host 0.0.0.0 --port 8000
```

### 3.2 Verify

```bash
curl -s http://localhost:8000/health
curl -s http://localhost:8000/ready
curl -s http://localhost:8000/live
curl -s http://localhost:8000/metrics | head
```

---

## 4) Docker — Stable classroom workflow

**Golden rule:** build BOTH images with SAME version.

```bash
export VER=0.1.4

# ML image
docker build -t techitfactory/churn-ml:$VER -f docker/Dockerfile.ml .

# API image
docker build -t techitfactory/churn-api:$VER -f docker/Dockerfile.api .
```

### 4.1 Run ML seed locally using bind mounts

```bash
docker run --rm \
  -e CHURN_MLOPS_CONFIG=/app/config/config.yaml \
  -v "$(pwd)/config:/app/config" \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/artifacts:/app/artifacts" \
  techitfactory/churn-ml:$VER
```

### 4.2 Run API container

```bash
docker run --rm -p 8000:8000 \
  -e CHURN_MLOPS_CONFIG=/app/config/config.yaml \
  -v "$(pwd)/config:/app/config" \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/artifacts:/app/artifacts" \
  techitfactory/churn-api:$VER
```

---

## 5) Kubernetes (Minikube) — Plain manifests

### 5.1 Apply core manifests

```bash
kubectl apply -f k8s/plain
```

### 5.2 Run seed job (fresh)

```bash
kubectl -n churn-mlops delete job churn-seed-model --ignore-not-found
kubectl -n churn-mlops apply -f k8s/plain/seed-model-job.yaml
kubectl -n churn-mlops logs -f job/churn-seed-model
```

### 5.3 Verify model artifacts

```bash
kubectl -n churn-mlops exec job/churn-seed-model -- ls -l /app/artifacts/models
```

### 5.4 Restart API

```bash
kubectl -n churn-mlops rollout restart deployment/churn-api
kubectl -n churn-mlops get pods -w
```

### 5.5 Port-forward + verify

```bash
kubectl -n churn-mlops port-forward svc/churn-api 8000:8000
```

In another terminal:

```bash
curl -s http://localhost:8000/health
curl -s http://localhost:8000/ready
curl -s http://localhost:8000/live
curl -s http://localhost:8000/metrics | head
```

---

## 6) Troubleshooting quick hits

### A) Readiness probe 500

Usually model/config mismatch.

```bash
kubectl -n churn-mlops exec deploy/churn-api -- ls -l /app/artifacts/models
kubectl -n churn-mlops exec deploy/churn-api -- cat /app/config/config.yaml
kubectl -n churn-mlops logs -f deploy/churn-api
```

### B) Missing python module inside container

Symptom:

* `ModuleNotFoundError: pandas` or `prometheus_client`

Fix:

* ensure dependency exists in `requirements/api.txt`
* rebuild API image with same `VER`
* rollout restart

### C) Batch/cron scripts not found in K8s

If a Job says:

* `./scripts/*.sh: not found`

It means the image does not include the scripts.
Use the **plain K8s approach** you already validated or mount scripts via ConfigMap (we’ll clean this in Helm later).
EOF

````

---

## 13.2 Rollback plan

```bash
cat << 'EOF' > docs/rollback.md
# Rollback Plan — TechITFactory Churn MLOps

This rollback plan covers:
- Model artifacts
- API deployment
- Scheduled jobs

---

## 1) Model rollback (fastest)

We keep:
- versioned models: `baseline_logreg_<timestamp>.joblib`
- stable alias: `production_latest.joblib`

### 1.1 Local

List models:
```bash
ls -1 artifacts/models | sort
````

Pick a known-good model and overwrite alias:

```bash
cp artifacts/models/<GOOD_MODEL>.joblib artifacts/models/production_latest.joblib
```

Restart local API if running.

### 1.2 Kubernetes

Check models inside PVC:

```bash
kubectl -n churn-mlops exec deploy/churn-api -- ls -l /app/artifacts/models
```

If needed, copy a known good model to alias using a one-off debug pod or a tiny helper job (optional for course).

---

## 2) API image rollback (K8s)

```bash
kubectl -n churn-mlops rollout history deployment/churn-api
kubectl -n churn-mlops rollout undo deployment/churn-api
```

---

## 3) Pause automation during incidents

```bash
kubectl -n churn-mlops patch cronjob churn-drift-daily -p '{"spec":{"suspend":true}}'
kubectl -n churn-mlops patch cronjob churn-retrain-weekly -p '{"spec":{"suspend":true}}'
```

Resume:

```bash
kubectl -n churn-mlops patch cronjob churn-drift-daily -p '{"spec":{"suspend":false}}'
kubectl -n churn-mlops patch cronjob churn-retrain-weekly -p '{"spec":{"suspend":false}}'
```

---

## 4) Minikube resilience note

Minikube is a learning target.
If the cluster is recreated, PVC data may be lost.
For classes:

* keep `artifacts/models` backed up locally
* rebuild images with a single version tag across ML + API
  EOF

````

---

## 13.3 Final checklist

```bash
cat << 'EOF' > docs/final-checklist.md
# Final Checklist — Production-Grade Churn MLOps

Use this before recording the final capstone video.

---

## Code & Quality

- [ ] `make lint` passes
- [ ] `make test` passes
- [ ] Imports formatted (ruff)
- [ ] Config contains `app.env` (dev/stage/prod)

---

## Data Pipeline

- [ ] Synthetic generator runs
- [ ] Raw validation passes
- [ ] Processed tables created
- [ ] Features + labels created
- [ ] Training dataset created

---

## Model Registry

- [ ] Timestamped model exists
- [ ] Metrics JSON exists
- [ ] `production_latest.joblib` exists

---

## Batch Scoring

- [ ] Batch output exists in `data/predictions/`
- [ ] Score proxy script can find latest file

---

## API

- [ ] API starts without missing modules
- [ ] `/health` OK
- [ ] `/ready` OK
- [ ] `/live` OK
- [ ] `/metrics` OK

---

## Containers

- [ ] ML + API images built with SAME version
- [ ] Images pushed (if using remote registry)

---

## Kubernetes

- [ ] Seed Job completes
- [ ] API Deployment stable
- [ ] Drift CronJob present
- [ ] Retrain CronJob present
- [ ] Port-forward demo works

---

## Student Experience

- [ ] Runbook is copy-paste ready
- [ ] One happy-path script works
- [ ] Troubleshooting steps validated
EOF
````

---

## 13.4 Helper scripts

### A) Local happy-path

```bash
cat << 'EOF' > scripts/happy_path_local.sh
#!/usr/bin/env bash
set -e

if [ ! -d .venv ]; then
  echo "❌ .venv not found. Create it first."
  exit 1
fi

source .venv/bin/activate

echo "✅ Lint"
make lint

echo "✅ Tests"
make test

echo "✅ Seed + train baseline"
./scripts/seed_model_local.sh

echo "✅ Batch score"
./scripts/batch_score.sh

echo "✅ Score proxy (non-fatal if missing latest alias)"
./scripts/score_proxy.sh || true

echo "🎉 Local happy path done"
EOF

chmod +x scripts/happy_path_local.sh
```

### B) K8s smoke

```bash
cat << 'EOF' > scripts/k8s_smoke.sh
#!/usr/bin/env bash
set -e

NS="${1:-churn-mlops}"

echo "🔎 Namespace: $NS"
kubectl get ns "$NS" >/dev/null

echo "🔎 PVC"
kubectl -n "$NS" get pvc || true

echo "🔎 ConfigMaps"
kubectl -n "$NS" get cm || true

echo "🔎 Jobs"
kubectl -n "$NS" get jobs || true

echo "🔎 CronJobs"
kubectl -n "$NS" get cronjobs || true

echo "🔎 Deployments"
kubectl -n "$NS" get deploy || true

echo "🔎 Pods"
kubectl -n "$NS" get pods || true

echo "✅ K8s smoke check done"
EOF

chmod +x scripts/k8s_smoke.sh
```

---

## 13.5 Quick verify

```bash
ls -l docs
ls -l scripts
```

---

# Where you are now (based on your logs)

You have already proven these in your environment:

* Seed Job can generate data, features, labels, train baseline, and produce:

  * `baseline_logreg_<timestamp>.joblib`
  * `production_latest.joblib`
* API is healthy and exposes:

  * `/health`, `/ready`, `/live`, `/metrics`
* Drift + retrain CronJobs exist in `churn-mlops`




