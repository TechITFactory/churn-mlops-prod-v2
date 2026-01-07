# Production v2.0 Enhancement Guide (Spoon-Fed)

This guide explains the **evolution** from v1.0 (student project) → v2.0 (professional product) → v3.0 (enterprise scale).

---

# Part 1: v2.0 Upgrades (Implemented in This Repo)

## 1. DVC (Data Version Control)
### **The "Git for Data"**

*   **The Problem in v1.0:** You manage data by saving local CSV files. If you overwrite a file, the old version is gone. You can't prove which dataset trained the model.
*   **The Solution in v2.0:** **DVC** tracks large data files effectively. It stores the actual data in cloud storage (S3) and keeps a lightweight reference in Git.
*   **In Plain English:** *"I can 'checkout' a specific version of my 10GB dataset just like I checkout code."*

### What's in This Repo
- `dvc.yaml` - 8-stage pipeline (generate → validate → prepare → features → labels → train → batch_score)
- `dvc.lock` - Locks the pipeline state
- `.dvc/` - DVC configuration

### How to Run
```bash
dvc repro                    # Run entire pipeline
dvc repro train_baseline     # Run specific stage
dvc dag                      # See pipeline graph
```

---

## 2. MLflow
### **The "Automated Lab Notebook"**

*   **The Problem in v1.0:** You run `python train.py` and see `Accuracy: 0.85` in your terminal. Two weeks later, you ask: *"What learning rate did I use?"*
*   **The Solution in v2.0:** **MLflow** automatically records parameters, metrics, and model files during training. It provides a UI to compare runs.
*   **In Plain English:** *"I don't have to remember my experiment results. The dashboard remembers for me."*

### What's in This Repo
- `k8s/mlflow/` - 7 K8s manifests (deployment, service, PVC, ServiceAccount)
- `terraform/main.tf` - S3 bucket + IRSA role for MLflow S3 access

### How to Run Locally
```bash
mlflow ui  # Open http://127.0.0.1:5000
```

### How to Deploy on EKS
```bash
kubectl apply -f k8s/mlflow/
```

---

## 3. Kubeflow Pipelines (KFP)
### **The "Automated Assembly Line"**

*   **The Problem in v1.0:** Workflows are manual checklists ("First run X, then run Y"). If you forget a step, it breaks.
*   **The Solution in v2.0:** **Kubeflow** defines the workflow as a graph where each step runs in an isolated container.
*   **In Plain English:** *"I push one button, and the factory line runs itself. If Step 3 breaks, I fix it and resume from Step 3."*

### What's in This Repo
- `pipelines/kfp_pipeline.py` - Full pipeline definition

### How to Compile
```bash
python pipelines/kfp_pipeline.py
# Outputs: pipelines/churn_pipeline.yaml
```

---

## 4. Infrastructure (Terraform)
### **The "One-Click Cluster"**

*   **The Problem in v1.0:** Manual AWS Console clicking to create EKS.
*   **The Solution in v2.0:** **Terraform** provisions everything with one command.

### What's in This Repo (`terraform/`)
| Resource | Purpose |
|----------|---------|
| VPC + Subnets | Network for EKS |
| EKS Cluster | Kubernetes v1.29 |
| EBS CSI Driver | Persistent volumes |
| **S3 Bucket** | Model/data artifacts (versioned + encrypted) |
| **MLflow IRSA** | IAM role for MLflow S3 access |

### How to Deploy
```bash
cd terraform
terraform init
terraform apply
aws eks update-kubeconfig --name churn-mlops
```

---

## 5. Monitoring (Prometheus + Grafana)
### **The "Cockpit Dashboard"**

*   **The Problem in v1.0:** You know the server is "up" but not if it's slow or drifting.
*   **The Solution in v2.0:** **Prometheus** collects metrics, **Grafana** visualizes them.

### What's in This Repo
- `monitoring/prometheus.yml` - Scrape configuration
- `monitoring/grafana-provisioning/` - Dashboard provisioning
- `k8s/monitoring/` - ServiceMonitor manifests

---

## 6. Advanced CronJobs
### **The "Self-Healing System"**

| CronJob | Purpose |
|---------|---------|
| `drift-cronjob.yaml` | Daily drift check |
| `drift-auto-retrain-cronjob.yaml` | **Auto-retrain when drift detected** |
| `high-drift-cronjob.yaml` | Alert on high drift |
| `batch-cronjob.yaml` | Daily batch scoring |

---

# Part 2: v3.0 Enhancements (Future Roadmap)

These are recommended additions to reach "Enterprise/Bank Grade" standards.

## 7. DevSecOps (Trivy + SonarQube)
### **The "Automated Bodyguard"**

*   **Problem:** A developer accidentally installs a Python library with a known vulnerability.
*   **Solution:** **Trivy** scans Docker containers for CVEs *before* deployment. **SonarQube** scans code for security bugs.
*   **In Plain English:** *"The security guard checks every package at the door."*

---

## 8. Great Expectations
### **The "Unit Tests for Data"**

*   **Problem:** Manual `validate.py` is fragile. Stakeholders can't "see" the quality rules.
*   **Solution:** **Great Expectations** runs test suites on data and generates HTML reports.
*   **In Plain English:** *"It generates a 'report card' for every batch of data."*

---

## 9. Feature Store (Feast)
### **The "Data Vending Machine"**

*   **Problem:** Training calculates "Average Spend" differently than Production (**Training-Serving Skew**).
*   **Solution:** **Feast** is a centralized store. Both Training and API serve from the exact same definition.
*   **In Plain English:** *"One vending machine where everyone gets the exact same snack."*

---

# Part 3: Real-World Scale (Handling Terabytes)

## 10. Big Data Processing (Spark)
### **The "Heavy Lifter"**

*   **Reality:** You don't have `users.csv` on your laptop. You have **50 TB** in a Data Lake.
*   **Problem:** `pandas.read_csv("50TB_file.csv")` explodes your RAM.
*   **Solution:** **Apache Spark** breaks data into chunks, distributes across 100 servers.
*   **In Plain English:** *"Instead of one person carrying 1,000 bricks, 1,000 people carry one brick each."*

---

## 11. Streaming Data (Kafka)
### **The "Firehose"**

*   **Reality:** Data arrives *continuously* (clicks, payments) every millisecond.
*   **Problem:** Batch job at midnight = 24 hours late to catch fraud.
*   **Solution:** **Kafka** streams events. The model reacts instantly.
*   **In Plain English:** *"Batch = yesterday's newspaper. Streaming = live Twitter feed."*

---

## 12. Feature Store Online/Offline
### **The "Bridge"**

| Store | Technology | Size | Speed | Use Case |
|-------|------------|------|-------|----------|
| **Offline** | S3/Snowflake | Petabytes | Minutes | Training |
| **Online** | Redis/DynamoDB | Gigabytes | Milliseconds | Serving |

*   **Connection:** Every night, a job copies computed values from Offline → Online.
*   **API Call:** Doesn't calculate from raw logs. Asks Redis: *"User 123's average spend?"* → 2ms response.

---

# Summary Table

| Version | What You Get |
|---------|--------------|
| **v1.0** | Shell scripts, manual deploys, no tracking |
| **v2.0** | DVC, MLflow, Kubeflow, Terraform, Monitoring |
| **v3.0** | DevSecOps, Data Quality, Feature Store, Spark/Kafka |
