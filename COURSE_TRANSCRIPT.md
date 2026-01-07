# Course Transcript: MLOps Journey

*This is an instructor-style narration explaining what we built, why, and what comes next.*

---

## Introduction

> "Welcome back! In this course, we've been building a production-grade MLOps system for churn prediction. Let me walk you through exactly what we did and where we're heading."

---

# What We Did: V1.0 (The Foundation)

> "In the first phase, we built the **foundation**. Think of it as building a house - we laid the groundwork."

## The Problem We Solved
> "Imagine you're a data scientist. You train a model on your laptop. It works great. But then what? How do you get it to production? How do you make it run every day? That's what V1.0 solved."

## What We Built

### 1. The ML Pipeline (Scripts)
> "We created shell scripts that run our pipeline: generate data, validate it, build features, train, and score. Simple, but it works."

```bash
./scripts/generate_data.sh
./scripts/train_baseline.sh
./scripts/batch_score.sh
```

### 2. The API (FastAPI)
> "We wrapped our model in a REST API. Now anyone can call `/predict` and get a churn probability."

### 3. Kubernetes Deployment
> "We containerized everything and deployed to Kubernetes. We have Jobs for training, Deployments for the API, and CronJobs for scheduled tasks."

### 4. CI/CD (GitHub Actions)
> "Every push triggers linting, testing, and building Docker images. No more 'works on my machine' problems."

### 5. GitOps (ArgoCD)
> "We set up ArgoCD to watch our Git repo. Push a change, and it automatically deploys. No manual `kubectl apply` needed."

### 6. Infrastructure (Terraform)
> "We wrote Terraform to provision our EKS cluster. One `terraform apply` and we have a production Kubernetes cluster."

## The Limitations
> "But V1.0 had problems. If I asked you: 'What data did you use to train model version 3?' - you couldn't tell me. If I asked 'Which hyperparameters gave 85% accuracy?' - you'd have to dig through terminal logs. That's not production-grade."

---

# What We Did: V2.0 (The Upgrade)

> "In V2.0, we fixed those problems. We made the system **reproducible** and **observable**."

## The Problems We Solved
> "Three big questions we couldn't answer before:
> 1. What exact data trained this model?
> 2. What parameters gave the best results?
> 3. Did the model drift since last week?"

## What We Added

### 1. DVC (Data Version Control)
> "Remember Git? It tracks code changes. DVC does the same for data. Now I can say: 'Checkout data version abc123' and get exactly the data I used 6 months ago."

```bash
dvc repro  # Runs the entire pipeline, cached and reproducible
```

> "The magic is in `dvc.yaml`. It defines our pipeline as a graph. DVC knows what depends on what. If I change the feature code, it only re-runs features and downstream - not data generation."

### 2. MLflow (Experiment Tracking)
> "Every time we train, MLflow logs the parameters, metrics, and model file. We have a dashboard showing all experiments. I can compare Run 15 vs Run 23 with one click."

```bash
mlflow ui  # Open the dashboard
```

> "We also deployed MLflow to Kubernetes. The artifacts go to S3. Everyone on the team sees the same experiments."

### 3. Kubeflow Pipelines
> "DVC is great for local development. But for production orchestration, we have Kubeflow. It runs each step in a container, handles retries, and creates a visual DAG."

```bash
python pipelines/kfp_pipeline.py  # Compile the pipeline
```

### 4. Prometheus + Grafana
> "We added observability. Prometheus scrapes metrics from our API - latency, error rates, prediction distributions. Grafana makes dashboards."

### 5. Auto-Retrain on Drift
> "Here's the cool part. We have a CronJob that checks for drift every day. If drift exceeds a threshold, it automatically triggers retraining. Self-healing ML."

### 6. Terraform Enhancements
> "We added an S3 bucket for artifacts and an IRSA role so MLflow can access S3 securely. All in code, all reproducible."

---

# What We're Doing Next: V3.0 (Enterprise Grade)

> "V2.0 is solid for a startup. But for a bank? A hospital? We need more. V3.0 is about **reliability** and **security**."

## What We'll Add

### 1. Great Expectations (Data Quality)
> "Right now, our `validate.py` does basic checks. But stakeholders can't see the rules. Great Expectations generates HTML reports: 'Column age: 99.8% passed the range check.' Visible, auditable data quality."

### 2. Feast (Feature Store)
> "Here's a common bug: Training team calculates 'average_spend' one way. Production calculates it differently. Model performs great in training, terrible in production. A Feature Store guarantees both use the exact same calculation."

### 3. Trivy (Container Security)
> "Before we deploy any image, Trivy scans it for known vulnerabilities. If there's a critical CVE, the pipeline fails. We don't ship insecure code."

### 4. SonarQube (Code Security)
> "Same for code. SonarQube checks for SQL injection, hardcoded secrets, and other security bugs. Catches problems before they reach production."

### 5. OpenTelemetry (Tracing)
> "When a request is slow, which service caused it? Tracing follows a request through every service and shows exactly where time was spent."

---

# What's Coming: V4.0 (Scale)

> "Finally, V4.0 is about **scale**. What happens when you have 50TB of data? 1 million predictions per second?"

## What We'll Add

### 1. Spark / Databricks
> "Pandas can't handle terabytes. Spark distributes the work across a cluster. Same feature code, 100x more data."

### 2. Kafka + Flink (Streaming)
> "Batch scoring runs once a day. But fraud detection needs real-time. Kafka streams events, Flink processes them, predictions happen in milliseconds."

### 3. A/B Testing
> "We have Model A in production. Model B looks better in offline tests. But will users behave differently? A/B testing splits traffic: 90% to A, 10% to B. We measure real outcomes."

### 4. Canary Deployments
> "Instead of big-bang deploys, we roll out gradually. 1% of traffic sees the new version. If errors spike, we roll back automatically."

### 5. Multi-Region
> "For global scale, we deploy to multiple AWS regions. If us-east-1 goes down, eu-west-1 takes over. Zero downtime."

---

# Summary

> "Let's recap the journey:"

| Version | Focus | One-Liner |
|---------|-------|-----------|
| **V1.0** | Foundation | "Make it work" |
| **V2.0** | Reproducibility | "Make it trackable" |
| **V3.0** | Reliability | "Make it trustworthy" |
| **V4.0** | Scale | "Make it global" |

> "We started with scripts and manual deploys. We're ending with a self-healing, auto-scaling, globally distributed ML platform. That's the MLOps journey."

---

# Next Steps for Students

1. **Clone the repos**: `churn-mlops-prod` (V1) and `churn-mlops-prod-v2` (V2)
2. **Run locally**: `dvc repro` + `mlflow ui`
3. **Deploy to EKS**: `terraform apply` + `kubectl apply`
4. **Break things**: Change data, see DVC cache in action
5. **Explore MLflow**: Compare experiments, register models
