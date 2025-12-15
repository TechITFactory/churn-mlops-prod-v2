# Section 01: Introduction to MLOps

**Duration**: 2 hours  
**Level**: Beginner  
**Prerequisites**: None

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand what MLOps is and why it exists
- ✅ Identify the challenges of deploying ML models to production
- ✅ Learn the MLOps maturity model
- ✅ Understand the architecture of a production ML system
- ✅ Grasp the difference between ML in notebooks vs production

---

## 📚 Table of Contents

1. [What is MLOps?](#what-is-mlops)
2. [The ML Deployment Challenge](#the-ml-deployment-challenge)
3. [MLOps Maturity Levels](#mlops-maturity-levels)
4. [MLOps Lifecycle](#mlops-lifecycle)
5. [Architecture Overview](#architecture-overview)
6. [Real-World Example: TechITFactory](#real-world-example)
7. [Key Takeaways](#key-takeaways)
8. [Hands-On Exercise](#hands-on-exercise)
9. [Assessment Questions](#assessment-questions)

---

## What is MLOps?

### Definition

**MLOps** (Machine Learning Operations) is a set of practices that combines:
- **Machine Learning** (building predictive models)
- **DevOps** (software engineering and operations)
- **Data Engineering** (managing data pipelines)

> **Goal**: Deploy and maintain ML models in production reliably and efficiently

### Why MLOps Emerged

```
Traditional Software Development:
Code → Build → Test → Deploy → Monitor
         ↓
    Predictable, repeatable, versioned

ML Model Development:
Data + Code + Config → Train → Evaluate → ???
         ↓
    Data changes, models drift, performance degrades
```

**Problem**: ML models are different from traditional software:
- **Data dependency**: Models depend on training data quality
- **Experimental nature**: Many experiments before finding best model
- **Drift**: Model performance degrades over time as real-world changes
- **Versioning complexity**: Need to version data + code + model + config
- **Reproducibility**: Hard to recreate exact model months later

---

## The ML Deployment Challenge

### Notebook vs Production

#### In Jupyter Notebook (Research):
```python
# Load data
df = pd.read_csv('churn_data.csv')

# Train model
from sklearn.linear_model import LogisticRegression
model = LogisticRegression()
model.fit(X_train, y_train)

# Evaluate
print(f"Accuracy: {model.score(X_test, y_test)}")
```

**✅ Works great for experimentation!**

#### In Production (Reality):
```python
# Questions that arise:
# 1. Where is churn_data.csv? How do we update it?
# 2. What if data schema changes?
# 3. How do we version this model?
# 4. How do we serve predictions at scale?
# 5. How do we monitor model performance?
# 6. How do we retrain when performance drops?
# 7. How do we roll back to previous model?
# 8. How do we ensure reproducibility?
```

**❌ Many unanswered questions!**

### The 87% Problem

> **"87% of data science projects never make it to production"**  
> — VentureBeat Research

**Why?**
- ❌ No clear path from notebook to deployment
- ❌ Data quality issues in production
- ❌ Model drift not monitored
- ❌ No CI/CD for ML
- ❌ Lack of collaboration between data scientists and engineers
- ❌ No automated retraining

**MLOps solves these problems!**

---

## MLOps Maturity Levels

### Level 0: Manual Process

```
┌─────────────┐
│ Data        │
│ Scientist   │
│             │
│ 1. Jupyter  │───→ train.ipynb
│ 2. Train    │───→ model.pkl
│ 3. Email    │───→ "Here's the model!"
│    Engineer │
└─────────────┘

Problems:
❌ Manual steps
❌ Not reproducible
❌ No versioning
❌ No monitoring
```

**Characteristics**:
- All steps manual
- Jupyter notebooks
- Ad-hoc scripts
- Email-based deployment
- No automation

**Use case**: POC, research projects

---

### Level 1: ML Pipeline Automation

```
┌──────────────────────────────────────┐
│         Automated ML Pipeline        │
├──────────────────────────────────────┤
│ Data → Features → Train → Evaluate  │
│  ↓        ↓          ↓         ↓     │
│ Auto     Auto      Auto      Auto    │
└──────────────────────────────────────┘

Improvements:
✅ Automated training pipeline
✅ Version control for code
✅ Reproducible training
⚠️  Still manual deployment
⚠️  No continuous training
```

**Characteristics**:
- Automated feature engineering
- Automated training scripts
- Model versioning
- Manual deployment

**Use case**: Small teams, low update frequency

---

### Level 2: CI/CD Pipeline Automation

```
┌────────────────────────────────────────────┐
│          Continuous Integration            │
├────────────────────────────────────────────┤
│  Code Push → Test → Build → Deploy        │
│                                            │
│  ┌──────────┐    ┌──────────┐            │
│  │ GitHub   │───→│ GitHub   │───→ Deploy │
│  │ Push     │    │ Actions  │            │
│  └──────────┘    └──────────┘            │
└────────────────────────────────────────────┘

Improvements:
✅ Automated testing
✅ Automated deployment
✅ Version control for models
⚠️  Still no automated retraining
⚠️  No drift detection
```

**Characteristics**:
- Automated testing (unit, integration)
- Automated deployment (containers)
- Model registry
- Still manual retraining

**Use case**: Production systems with scheduled updates

---

### Level 3: Full MLOps Automation

```
┌────────────────────────────────────────────────┐
│           Continuous ML Pipeline               │
├────────────────────────────────────────────────┤
│  Data → Features → Train → Deploy → Monitor   │
│   ↓        ↓         ↓        ↓         ↓      │
│  Auto    Auto      Auto     Auto      Auto     │
│                                        ↓        │
│                              Drift Detected?    │
│                                        ↓        │
│                              Auto Retrain ←────┘│
└────────────────────────────────────────────────┘

Full Automation:
✅ Automated data validation
✅ Automated feature engineering
✅ Automated training & evaluation
✅ Automated deployment (CI/CD)
✅ Automated monitoring
✅ Automated retraining (when drift detected)
✅ Automated rollback
```

**Characteristics**:
- End-to-end automation
- Continuous training
- Drift detection
- Auto-retraining triggers
- A/B testing
- Shadow deployment

**Use case**: Large-scale production systems

---

## MLOps Lifecycle

### The Complete Loop

```
┌─────────────────────────────────────────────────────┐
│                   MLOps Lifecycle                   │
└─────────────────────────────────────────────────────┘

1. DATA
   ├── Collect
   ├── Validate
   ├── Version
   └── Store

2. DEVELOP
   ├── Explore
   ├── Feature Engineering
   ├── Model Training
   └── Evaluation

3. DEPLOY
   ├── Package (Container)
   ├── Test
   ├── Release
   └── Serve (Batch/API)

4. MONITOR
   ├── Model Performance
   ├── Data Drift
   ├── System Health
   └── Business Metrics

5. RETRAIN (if needed)
   └── Triggers:
       ├── Performance drop
       ├── Data drift
       └── Schedule

   Loop back to DEVELOP
```

---

## Architecture Overview

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     MLOps Architecture                       │
└──────────────────────────────────────────────────────────────┘

┌─────────────────┐
│   Data Sources  │
│  - Databases    │
│  - APIs         │
│  - Files        │
└────────┬────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────────┐
│                   DATA LAYER                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Raw Data     │→ │ Validation   │→ │ Processed    │     │
│  │ Storage      │  │ Gates        │  │ Data         │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└───────────────────────────────┬─────────────────────────────┘
                                │
                                ↓
┌─────────────────────────────────────────────────────────────┐
│                   FEATURE LAYER                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Feature      │→ │ Feature      │→ │ Feature      │     │
│  │ Engineering  │  │ Store        │  │ Serving      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└───────────────────────────────┬─────────────────────────────┘
                                │
                                ↓
┌─────────────────────────────────────────────────────────────┐
│                   TRAINING LAYER                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Experiment   │→ │ Model        │→ │ Model        │     │
│  │ Tracking     │  │ Training     │  │ Registry     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└───────────────────────────────┬─────────────────────────────┘
                                │
                                ↓
┌─────────────────────────────────────────────────────────────┐
│                   SERVING LAYER                             │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │ Batch        │  │ Real-time    │                        │
│  │ Predictions  │  │ API          │                        │
│  └──────────────┘  └──────────────┘                        │
└───────────────────────────────┬─────────────────────────────┘
                                │
                                ↓
┌─────────────────────────────────────────────────────────────┐
│                   MONITORING LAYER                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Data Drift   │  │ Model        │  │ System       │     │
│  │ Detection    │  │ Performance  │  │ Metrics      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└───────────────────────────────┬─────────────────────────────┘
                                │
                                ↓ (if drift/degradation)
                     [Auto-Retrain Pipeline]
```

### Technology Stack (What We'll Use)

```
┌────────────────────────────────────────────────┐
│              Technology Stack                  │
├────────────────────────────────────────────────┤
│ Language:      Python 3.10+                    │
│ ML Library:    scikit-learn                    │
│ API:           FastAPI                         │
│ Container:     Docker                          │
│ Orchestration: Kubernetes                      │
│ Package Mgmt:  Helm                            │
│ CI/CD:         GitHub Actions                  │
│ GitOps:        ArgoCD                          │
│ Monitoring:    Prometheus + Grafana            │
│ Storage:       PersistentVolumes               │
└────────────────────────────────────────────────┘
```

---

## Real-World Example: TechITFactory

### The Business Problem

**TechITFactory** is an e-learning platform (like Udemy) facing:
- ❌ **High churn rate**: 25% of users stop engaging after signup
- ❌ **Revenue loss**: $500K/year from churned paid users
- ❌ **Manual intervention**: Support team reaches out randomly
- ❌ **No prediction**: Can't identify at-risk users proactively

### The ML Solution

**Build a churn prediction system that:**
1. **Predicts** which users are likely to churn in next 30 days
2. **Scores** users daily to identify high-risk individuals
3. **Automates** intervention (email campaigns, discounts, support)
4. **Monitors** model performance and retrains automatically
5. **Scales** to handle millions of users

### Success Metrics

| Metric | Target | Impact |
|--------|--------|--------|
| Churn Rate Reduction | 25% → 15% | Save $200K/year |
| Prediction Accuracy | >75% | Efficient targeting |
| API Latency | <100ms | Real-time decisions |
| Model Freshness | <7 days old | Always relevant |
| System Uptime | 99.5%+ | Business continuity |

### What We'll Build

```
┌─────────────────────────────────────────────────────────┐
│           TechITFactory Churn MLOps System              │
└─────────────────────────────────────────────────────────┘

1. DATA PIPELINE
   - Generate synthetic user and event data
   - Validate data quality
   - Process into daily user aggregation

2. FEATURE ENGINEERING
   - Rolling 7/14/30-day engagement metrics
   - Recency features (days since last activity)
   - Payment behavior patterns

3. MODEL TRAINING
   - Time-aware train/test split
   - Logistic Regression baseline
   - Automated evaluation

4. MODEL REGISTRY
   - Version all models with timestamps
   - Track metrics (accuracy, precision, recall)
   - Promote best model to production

5. BATCH SCORING
   - Daily CronJob to score all active users
   - Output: CSV with churn_probability per user
   - Store in /app/data/predictions/

6. REAL-TIME API
   - FastAPI endpoint: POST /predict
   - Health checks: /health, /live, /ready
   - Prometheus metrics: /metrics

7. CONTAINERIZATION
   - docker/Dockerfile.ml for training & batch
   - docker/Dockerfile.api for serving
   - Multi-stage builds for optimization

8. KUBERNETES DEPLOYMENT
   - Job: One-time model training (seed)
   - CronJob: Daily batch scoring
   - Deployment: API with replicas & autoscaling
   - PVC: Shared storage for data & models

9. CI/CD
   - GitHub Actions: Lint → Test → Build → Push
   - Automated image tagging (staging, production)
   - Release workflow for production deployments

10. GITOPS
    - ArgoCD: Sync K8s manifests from Git
    - Staging & Production environments
    - Automated rollout & rollback

11. MONITORING
    - Prometheus: API metrics, prediction counts
    - Drift Detection: PSI for feature distributions
    - Automated Retraining: Trigger on drift or schedule
```

---

## Key Takeaways

### ✅ What You Learned

1. **MLOps = ML + DevOps + Data Engineering**
   - It's not just ML, it's about production systems

2. **87% of ML projects fail to reach production**
   - MLOps practices solve the deployment gap

3. **MLOps Maturity Levels**
   - Level 0: Manual
   - Level 1: Automated training
   - Level 2: CI/CD
   - Level 3: Full automation

4. **Complete MLOps Lifecycle**
   - Data → Develop → Deploy → Monitor → Retrain

5. **TechITFactory Use Case**
   - Real business problem (churn prediction)
   - Clear success metrics
   - End-to-end solution

---

## Hands-On Exercise

### Exercise 1: Identify MLOps Maturity

For each scenario, identify the MLOps maturity level (0-3):

**Scenario A**:
- Data scientist trains model in Jupyter
- Emails pickle file to engineer
- Engineer manually deploys to server
- No monitoring

**Answer**: Level 0 (Manual)

---

**Scenario B**:
- Automated training pipeline (Python scripts)
- Model artifacts stored in S3
- Manual deployment via kubectl
- Basic monitoring (system metrics only)

**Answer**: Level 1 (Automated training, manual deployment)

---

**Scenario C**:
- Code push triggers GitHub Actions
- Automated tests, builds, deployment
- Models versioned in registry
- Manual retraining monthly

**Answer**: Level 2 (CI/CD, but no automated retraining)

---

**Scenario D**:
- Full CI/CD pipeline
- Drift detection monitors data
- Auto-retraining when drift detected
- A/B testing for model comparison

**Answer**: Level 3 (Full MLOps)

---

### Exercise 2: Map Your Current State

Think about your current ML projects:
1. What level are you at?
2. What's missing to reach the next level?
3. What are the biggest challenges?

---

## Assessment Questions

### Question 1: Multiple Choice
What is the main reason ML projects fail to reach production?

A) Lack of data  
B) Poor model accuracy  
C) **No clear path from notebook to production** ✅  
D) Expensive cloud costs  

---

### Question 2: True/False
**Statement**: In production ML, versioning only the code is sufficient.

**Answer**: False ❌  
**Explanation**: You need to version data, code, model, and configuration together.

---

### Question 3: Fill in the Blank
The complete MLOps lifecycle is:
Data → ______ → Deploy → ______ → Retrain

**Answer**: Develop, Monitor

---

### Question 4: Short Answer
Why is automated retraining important in production ML systems?

**Answer**:
- Model performance degrades over time (drift)
- Real-world patterns change (seasonality, trends)
- Manual retraining is slow and error-prone
- Automated retraining ensures model stays relevant

---

### Question 5: Scenario Analysis
A company deploys an ML model in production but doesn't monitor it. After 6 months, they notice predictions are wrong.

**Questions**:
1. What likely happened?
2. How could MLOps practices have prevented this?
3. What should they do now?

**Answer**:
1. **Data drift** or **model drift** - real-world changed, model didn't
2. **Monitoring + drift detection** would have caught it early
3. Implement monitoring, retrain model, set up automated retraining

---

## Next Steps

You now understand **what MLOps is** and **why it matters**.

**Next Section**: [Section 02: Project Setup & Environment](./section-02-project-setup.md)

In the next section, we'll:
- Set up the development environment
- Understand the project structure
- Configure dependencies
- Run your first ML pipeline

---

## Additional Resources

### Reading:
- [Google: MLOps: Continuous delivery and automation pipelines in machine learning](https://cloud.google.com/architecture/mlops-continuous-delivery-and-automation-pipelines-in-machine-learning)
- [AWS: MLOps Maturity Model](https://aws.amazon.com/blogs/machine-learning/mlops-foundation-roadmap-for-enterprises-with-amazon-sagemaker/)
- [Microsoft: MLOps Principles](https://learn.microsoft.com/en-us/azure/machine-learning/concept-model-management-and-deployment)

### Videos:
- [Introduction to MLOps (YouTube)](https://www.youtube.com/results?search_query=introduction+to+mlops)
- [ML in Production Conference Talks](https://mlops.community/)

---

**🎉 Congratulations!** You've completed Section 01!

Next: **[Section 02: Project Setup & Environment](./section-02-project-setup.md)** →
