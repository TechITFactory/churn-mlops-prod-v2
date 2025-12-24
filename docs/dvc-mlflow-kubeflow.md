# Add-ons: DVC, MLflow, Kubeflow (EKS-first)

This repo copy (`churn-mlops-prod-v2`) keeps the original code and adds scaffolding for:
- **DVC**: data/model versioning to S3.
- **MLflow**: experiment tracking + artifact store.
- **Kubeflow Pipelines**: orchestrate the existing scripts on EKS.
- **KServe**: optional; you already have FastAPI serving.

## 1) DVC (S3 remote)
1. Install DVC with the S3 extra (e.g., `pip install "dvc[s3]"`).
2. Configure the remote (edit `.dvc/config` with your bucket/prefix):
   ```bash
   dvc remote modify s3 url s3://YOUR_BUCKET/churn-mlops-prod-v2
   dvc remote modify s3 region us-east-1
   ```
3. Track data/artifacts (one-time, from repo root):
   ```bash
   dvc add data/raw data/processed data/features data/predictions artifacts/models artifacts/metrics
   git add *.dvc dvc.yaml .dvc/config .gitignore
   dvc push  # uploads to S3 (ensure AWS creds/IRSA)
   ```
4. Reproduce full pipeline:
   ```bash
   dvc repro
   ```
   Stages map directly to existing scripts (see `dvc.yaml`).

## 2) MLflow (tracking + artifacts)
- Server: run MLflow on EKS (Deployment + Service). Backend store: Postgres/RDS. Artifact store: S3.
- Env vars: copy `mlflow/.env.example`, set `MLFLOW_TRACKING_URI`, `MLFLOW_S3_ENDPOINT_URL`, `MLFLOW_ARTIFACT_URI`, and DB URI.
- Training jobs: add these env vars in k8s Jobs/CronJobs so runs log to MLflow. Optionally add minimal `mlflow.log_params/log_metrics/log_artifact` in training scripts; otherwise wrap commands via MLflow CLI (`mlflow run`).
- Registry: keep `production_latest.joblib` for serving, but also register the promoted model in MLflow for lineage.

## 3) Kubeflow Pipelines (KFP) on EKS
- Install KFP (or the lightweight standalone) into the cluster.
- Use `pipelines/kfp_pipeline.py` as a template: it wires your existing container image (churn-ml) to run the scripts in order.
- Artifacts flow through S3 (preferred) or the PVC. Pass `MLFLOW_*` env vars for tracking.
- Compile and upload the pipeline in the KFP UI; trigger on schedule or drift events.

## 4) Optional: KServe
- If you want managed serving, package the promoted model to S3 (MLflow sklearn flavor works) and create an `InferenceService` pointing to it. Your FastAPI can stay in place; KServe provides an additional managed endpoint.

## 5) EKS wiring (high level)
- **Images**: push `churn-ml` and `churn-api` to ECR; update k8s manifests to those tags.
- **IAM/IRSA**: grant Jobs/CronJobs/MLflow/KServe access to S3 (and RDS if used).
- **Storage**: keep PVC for scratch; treat S3 as the source of truth for data/artifacts (DVC, MLflow, KServe).
- **Secrets**: store DB creds and any tokens in Kubernetes Secrets; mount or env-inject to MLflow and jobs.
- **Ingress**: expose FastAPI and MLflow via ALB if needed; keep MLflow private if possible.

## Quick command cheatsheet
```bash
# DVC once
dvc remote modify s3 url s3://YOUR_BUCKET/churn-mlops-prod-v2
dvc add data/raw data/processed data/features data/predictions artifacts/models artifacts/metrics
dvc push

# MLflow server (local test)
mlflow server --backend-store-uri sqlite:///mlflow.db \
              --default-artifact-root s3://YOUR_BUCKET/mlflow-artifacts \
              --host 0.0.0.0 --port 5000

# KFP compile (after editing pipeline template)
python pipelines/kfp_pipeline.py --compile
```
