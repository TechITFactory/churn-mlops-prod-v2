# Section 16 — Enhancements & Improvements (DVC, MLflow, KServe, Kubeflow)

This project already covers a strong “production-ready” baseline:
**DATA → VALIDATE → FEATURES → TRAIN → PROMOTE → SCORE → SERVE → MONITOR → RETRAIN**.

The tools below (DVC, MLflow, KServe, Kubeflow) become important when you want the same workflow to be:
- repeatable across laptops/CI/Kubernetes
- auditable (who trained what, with which data/code)
- scalable (bigger data, more frequent retraining, more models)
- safer to deploy (controlled rollouts and rollback)

---

## 16.1 DVC — what it does here

### The problem DVC solves
Git is great for code, but **not** for large or frequently changing datasets/models.
DVC adds:
- a pipeline graph (`dvc.yaml` + `dvc.lock`) so runs are reproducible
- artifact versioning for folders like `data/` and `artifacts/` without putting them in Git
- remote storage support (S3/MinIO/GCS/Azure/SSH/local)

### In this repo
Your DVC pipeline stages map to the existing scripts:
- generate/validate/prepare
- build features/labels/training set
- train baseline
- batch score

DVC tracks the *outputs* (e.g., `data/raw`, `data/features`, `artifacts/models`) and stores their content in the DVC cache/remote.

### “Manual vs automated” in the real world
Both exist, but production is typically automated:

**Common real-world pattern**
- Developer runs locally for iteration: `dvc repro`
- CI runs on every PR to validate reproducibility (often with smaller sample data)
- A scheduled Kubernetes CronJob retrains weekly/daily
- A drift detector triggers retrain (event-driven)
- After training, the job runs `dvc push` to the remote so artifacts are persisted outside the cluster

**Key detail**: Kubernetes Pods are ephemeral.
So the source-of-truth for data/models is usually:
- DVC remote (S3) for pipeline artifacts
- MLflow artifact store (also usually S3)

This is how you avoid “it worked on my cluster yesterday, but the Pod is gone now”.

---

## 16.2 MLflow — what to track for churn, and why

### The problem MLflow solves
Once you have more than one training run, you need:
- experiment history (params, metrics, artifacts)
- comparison (which run is best?)
- lineage (what code/data produced the production model?)
- a registry / promotion workflow (candidate → production)

### What you should log for churn (minimum useful set)
For each training run, log:
- **Params**: training window, label window, feature windows, split strategy, model hyperparams
- **Metrics**:
  - PR-AUC (primary in churn; good for imbalance)
  - ROC-AUC (secondary)
  - churn rate in train/test
  - optional: precision@k / recall@k for business actions
- **Artifacts**:
  - the serialized model (`.joblib`)
  - metrics JSON
  - optional: feature list / schema signature

### How it connects to your current design
You already have a lightweight “registry” concept: `production_latest.joblib`.
MLflow complements that by keeping a permanent history:
- run X produced model A with PR-AUC 0.91
- run Y produced model B with PR-AUC 0.93
- production moved from A → B at a known time

### What to actually check in MLflow UI for your churn project

In the MLflow UI, treat each run as a “model candidate”. For this churn project, check:

- **Experiment**: keep runs grouped under a single experiment (recommended: `churn`).
- **Compare runs**: sort by `pr_auc` (primary) then sanity-check `roc_auc`.
- **Drift retrains**: confirm you see a new run created when drift triggers retraining.
- **Params**: confirm split settings and windows match expectations (label window, feature windows, `test_size`).
- **Artifacts**: open the run and confirm it has the model + metrics JSON.

If you later add a “promotion gate”, the workflow becomes:
1) drift/schedule triggers training
2) training logs run to MLflow
3) a promotion step registers/aliases the best run’s model for serving

---

## 16.3 KServe — what it would add (and what it replaces)

### The problem KServe solves
When you serve ML models at scale, you want:
- a standard serving interface (REST/gRPC)
- autoscaling for inference
- safe rollouts (canary, traffic splitting)
- model loading from object storage (S3)
- consistent operational features (metrics, logging)

### In your repo context
You already have a FastAPI service.
KServe becomes useful if you want to:
- serve the promoted model directly from S3 (or MLflow model artifacts)
- do canary deploys of a new model version
- standardize serving across multiple models/projects

**Typical setup**
- Training job promotes a model and uploads it to S3
- KServe `InferenceService` points to `s3://.../model`
- Traffic can be split between “old” and “new” model versions

If you keep FastAPI, KServe is optional. Many teams either:
- use KServe for raw model serving and keep FastAPI as a thin gateway, or
- skip KServe and run FastAPI only

---

## 16.4 Kubeflow Pipelines — what it adds over scripts/CronJobs

### The problem Kubeflow solves
CronJobs can run steps, but as complexity grows you want:
- DAG orchestration with retries and clear step boundaries
- parameterized runs
- UI for run history and metadata
- better integration with artifact stores

### In your repo context
You already have the logical pipeline. Kubeflow can:
- execute your steps as a pipeline (components)
- track each run and artifact lineage
- schedule retraining and run ad-hoc experiments

**Typical real-world setup**
- A Kubeflow Pipeline defines: ingest → validate → features → train → evaluate → promote
- Drift job triggers a pipeline run (or schedules it)
- Promotion updates a registry entry (MLflow Model Registry and/or `production_latest` alias)
- Serving (KServe) updates automatically to the new production model

---

## 16.5 How they fit together (recommended mental model)

- **DVC** = reproducible pipeline + dataset/artifact versioning
- **MLflow** = experiment tracking + model registry/history
- **Kubeflow** = orchestration platform to run the pipeline in Kubernetes
- **KServe** = standardized serving and rollout of the promoted model

You don’t need all four to be “production-ready”.
But you adopt them when you need more automation, governance, and scaling.

---

## 16.6 Suggested next steps for *your* repo

1) Decide the source of truth for model promotion:
- keep `production_latest.joblib` as the serving contract, and optionally also register in MLflow

2) Make it automated:
- in Kubernetes retrain CronJob: run `dvc repro` then `dvc push`
- set `MLFLOW_TRACKING_URI` so training logs runs to MLflow

3) If you adopt KServe later:
- save model artifacts in a KServe-friendly layout (often S3 path)
- create an `InferenceService` referencing the model location
