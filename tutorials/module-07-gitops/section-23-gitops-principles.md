# Section 23: GitOps Principles and Architecture

**Duration**: 2 hours  
**Level**: Intermediate  
**Prerequisites**: Modules 5-6 (Kubernetes, CI/CD)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand GitOps principles and benefits
- ✅ Compare GitOps vs traditional deployment
- ✅ Learn GitOps workflow patterns
- ✅ Understand declarative vs imperative infrastructure
- ✅ Identify GitOps tools and ecosystem
- ✅ Design GitOps architecture for MLOps
- ✅ Implement Git as source of truth

---

## 📚 Table of Contents

1. [What is GitOps?](#what-is-gitops)
2. [GitOps Principles](#gitops-principles)
3. [Traditional vs GitOps Deployment](#traditional-vs-gitops-deployment)
4. [GitOps Workflow](#gitops-workflow)
5. [GitOps Tools Ecosystem](#gitops-tools-ecosystem)
6. [GitOps for MLOps](#gitops-for-mlops)
7. [Benefits and Challenges](#benefits-and-challenges)
8. [Code Walkthrough](#code-walkthrough)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## What is GitOps?

> **GitOps**: Operational framework using Git as single source of truth for infrastructure and applications

```
Traditional Operations:
Operator → kubectl apply → Kubernetes
           (manual, error-prone)

GitOps:
Developer → Git commit → GitOps Controller → Kubernetes
            ↑                                    ↓
            └────── Continuous reconciliation ───┘
            (automated, auditable, versioned)
```

### Core Concept

**Git = Source of Truth**

```
Everything in Git:
├── Application code (src/)
├── Docker images (Dockerfile)
├── Kubernetes manifests (k8s/)
├── Helm charts (helm/)
└── Configuration (values.yaml)

Kubernetes Cluster = Reflection of Git
- Desired state in Git
- Actual state in cluster
- Controller ensures they match
```

---

## GitOps Principles

### The Four Principles

#### 1. Declarative

> **Declarative**: Describe the **desired state**, not the steps to achieve it

```yaml
# Declarative (GitOps)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-api
spec:
  replicas: 3  # Desired state: 3 replicas

# vs Imperative
kubectl scale deployment churn-api --replicas=3  # Steps to achieve
```

#### 2. Versioned and Immutable

> **Versioned**: All changes tracked in Git history

```
Git History = Audit Trail

commit abc123 (HEAD -> main)
Author: Alice <alice@example.com>
Date:   2023-12-15 10:30:00
    
    feat: scale API to 5 replicas for Black Friday

commit def456
Author: Bob <bob@example.com>
Date:   2023-12-14 14:00:00
    
    fix: update image tag to v1.2.3

Benefits:
✅ Who changed what, when, why
✅ Rollback to any previous state
✅ Review changes before deployment
```

#### 3. Pulled Automatically

> **Pull-based**: Controller **pulls** changes from Git (vs push)

```
Push Model (Traditional CI/CD):
CI/CD Server → kubectl apply → Kubernetes
(CI/CD has cluster credentials - security risk)

Pull Model (GitOps):
GitOps Controller (in cluster) → polls Git → kubectl apply → Kubernetes
(No external credentials needed - more secure)
```

#### 4. Continuously Reconciled

> **Reconciliation**: Controller continuously compares Git (desired) with cluster (actual)

```
Reconciliation Loop:

1. Read desired state from Git
   ↓
2. Read actual state from cluster
   ↓
3. Compare: Git == Cluster?
   ├─ Yes → Do nothing
   └─ No  → Apply changes to match Git
   ↓
4. Wait (e.g., 3 minutes)
   ↓
5. Repeat from step 1

Benefits:
✅ Self-healing (manual changes reverted)
✅ Drift detection
✅ Always in sync
```

---

## Traditional vs GitOps Deployment

### Traditional Deployment

```
┌─────────────────────────────────────────────────┐
│  Traditional CI/CD                               │
├─────────────────────────────────────────────────┤
│                                                  │
│  Developer                                       │
│    ↓ git push                                   │
│  GitHub                                          │
│    ↓ webhook                                    │
│  CI/CD Server (Jenkins, GitLab CI)             │
│    ├─ Build Docker image                        │
│    ├─ Push to registry                          │
│    └─ kubectl apply (direct access)             │
│         ↓                                        │
│  Kubernetes Cluster                              │
│                                                  │
│  Problems:                                       │
│  ❌ CI/CD has cluster credentials (security)     │
│  ❌ No audit trail of deployed state             │
│  ❌ Drift not detected                           │
│  ❌ Rollback = run CI/CD again                  │
│                                                  │
└─────────────────────────────────────────────────┘
```

### GitOps Deployment

```
┌─────────────────────────────────────────────────┐
│  GitOps                                          │
├─────────────────────────────────────────────────┤
│                                                  │
│  Developer                                       │
│    ↓ git push                                   │
│  GitHub (Git Repository)                        │
│    ├─ Application code                          │
│    ├─ Docker images (tags in manifests)         │
│    └─ K8s manifests (desired state)             │
│         ↑                                        │
│         │ polls (every 3 min)                   │
│         │                                        │
│  Kubernetes Cluster                              │
│    ┌──────────────────────┐                     │
│    │  GitOps Controller   │                     │
│    │  (ArgoCD, Flux)      │                     │
│    │  - Polls Git          │                     │
│    │  - Compares states    │                     │
│    │  - Applies changes    │                     │
│    └──────────────────────┘                     │
│         ↓                                        │
│    Deployments, Services, Pods                  │
│                                                  │
│  Benefits:                                       │
│  ✅ Git = single source of truth                 │
│  ✅ Pull-based (more secure)                     │
│  ✅ Audit trail in Git history                   │
│  ✅ Rollback = git revert                        │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Comparison Table

| Aspect | Traditional | GitOps |
|--------|------------|--------|
| **Deployment** | Push (CI/CD → Cluster) | Pull (Cluster ← Git) |
| **Source of truth** | CI/CD config + scripts | Git repository |
| **Credentials** | CI/CD has cluster access | Controller in cluster |
| **Audit trail** | CI/CD logs (temporary) | Git history (permanent) |
| **Rollback** | Re-run CI/CD with old version | Git revert |
| **Drift detection** | Manual | Automatic |
| **Security** | External access to cluster | Internal only |
| **Observability** | Limited | Full state visibility |

---

## GitOps Workflow

### End-to-End Flow

```
Step 1: Developer Changes Code
├─ Edit src/churn_mlops/api/app.py
├─ Commit: "feat: add new endpoint"
└─ Push to GitHub

Step 2: CI Pipeline
├─ Run tests
├─ Build Docker image
├─ Push to ghcr.io (tag: sha-abc123)
└─ Update k8s/helm/values-staging.yaml
    (image.tag: sha-abc123)
    Commit: "chore: update image tag"

Step 3: GitOps Controller Detects Change
├─ ArgoCD polls Git every 3 minutes
├─ Detects values-staging.yaml changed
└─ Status: "OutOfSync"

Step 4: ArgoCD Syncs
├─ Compares Git (desired) vs Cluster (actual)
├─ Applies changes:
│   └─ kubectl set image deployment/churn-api ...
└─ Waits for rollout to complete

Step 5: Cluster Reflects Git
├─ New pods created with new image
├─ Old pods terminated
├─ Status: "Synced" + "Healthy"
└─ Deployment complete ✅
```

### GitOps Branching Strategy

```
┌─────────────────────────────────────────────────┐
│  Git Branches = Environments                     │
├─────────────────────────────────────────────────┤
│                                                  │
│  feature/new-model                               │
│    ↓ PR + merge                                 │
│  develop                                         │
│    ↓ deploy to                                  │
│  Development Cluster                             │
│                                                  │
│  develop                                         │
│    ↓ PR + merge                                 │
│  main                                            │
│    ↓ deploy to                                  │
│  Staging Cluster                                 │
│                                                  │
│  main                                            │
│    ↓ tag v1.2.3                                 │
│  Release (v1.2.3)                                │
│    ↓ deploy to                                  │
│  Production Cluster                              │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

## GitOps Tools Ecosystem

### Popular GitOps Tools

| Tool | Description | Use Case |
|------|-------------|----------|
| **ArgoCD** | Declarative GitOps CD | Kubernetes apps, UI, multi-cluster |
| **Flux** | GitOps operator | Kubernetes apps, lightweight |
| **Jenkins X** | CI/CD with GitOps | Full CI/CD pipeline |
| **Rancher Fleet** | Multi-cluster GitOps | Large-scale deployments |

### ArgoCD Overview

```
ArgoCD Components:

┌─────────────────────────────────────────────┐
│  ArgoCD Architecture                         │
├─────────────────────────────────────────────┤
│                                              │
│  ┌──────────────────────────────────────┐  │
│  │  ArgoCD Server (Web UI + API)       │  │
│  └──────────────────────────────────────┘  │
│                    ↓                        │
│  ┌──────────────────────────────────────┐  │
│  │  Application Controller              │  │
│  │  - Polls Git repositories            │  │
│  │  - Compares desired vs actual state  │  │
│  │  - Syncs applications                │  │
│  └──────────────────────────────────────┘  │
│                    ↓                        │
│  ┌──────────────────────────────────────┐  │
│  │  Repo Server                          │  │
│  │  - Fetches manifests from Git        │  │
│  │  - Renders Helm/Kustomize templates  │  │
│  └──────────────────────────────────────┘  │
│                    ↓                        │
│  ┌──────────────────────────────────────┐  │
│  │  Redis (cache)                       │  │
│  └──────────────────────────────────────┘  │
│                                              │
└─────────────────────────────────────────────┘
```

**Key Features**:
- 🎨 **Web UI**: Visual application management
- 🔄 **Auto-sync**: Automatically deploy changes
- 🔧 **Self-heal**: Revert manual changes
- 📜 **Rollback**: Easy rollback to previous versions
- 🔒 **RBAC**: Role-based access control
- 🔔 **Notifications**: Slack, email alerts
- 📊 **Health checks**: Application health monitoring

---

## GitOps for MLOps

### MLOps-Specific Considerations

```
ML System = Code + Data + Model

GitOps handles:
✅ Application code (API, training scripts)
✅ Infrastructure (K8s manifests, Helm charts)
✅ Configuration (hyperparameters, feature flags)

Not in Git (too large):
❌ Training data (use S3, GCS, data versioning)
❌ Trained models (use model registry, artifact store)

Solution: Store metadata in Git
✅ Model version: v1.2.3
✅ Data version: sha256:abc123
✅ Model artifact path: s3://models/v1.2.3
```

### ML Deployment Workflow

```
1. Data Scientist trains model
   ↓
2. Model registered in MLflow/Weights & Biases
   ↓
3. CI pipeline:
   - Tests model
   - Builds inference container
   - Pushes to registry (ghcr.io)
   ↓
4. CI updates Git:
   - values.yaml: image.tag = sha-abc123
   - Commit: "chore: deploy model v1.2.3"
   ↓
5. ArgoCD detects change
   ↓
6. ArgoCD syncs:
   - Deploys new API version
   - Loads model from S3
   - Health checks pass
   ↓
7. Production updated with new model ✅
```

### Directory Structure for GitOps

```
churn-mlops-prod/
├── .github/workflows/
│   ├── ci.yml                    # CI: test, lint
│   └── cd-build-push.yml         # CD: build, push, update Git
│
├── k8s/
│   ├── helm/churn-mlops/
│   │   ├── Chart.yaml
│   │   ├── values.yaml           # Defaults
│   │   ├── values-staging.yaml   # Staging overrides
│   │   ├── values-production.yaml # Prod overrides
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── cronjob.yaml
│
├── argocd/
│   ├── appproject.yaml           # RBAC, policies
│   ├── staging/
│   │   └── application.yaml      # ArgoCD app for staging
│   └── production/
│       └── application.yaml      # ArgoCD app for prod
│
└── src/churn_mlops/              # Application code
```

---

## Benefits and Challenges

### Benefits of GitOps

| Benefit | Description |
|---------|-------------|
| **🔒 Security** | No external cluster credentials |
| **📜 Auditability** | Git history = complete audit trail |
| **🔄 Consistency** | Same process for all environments |
| **⚡ Speed** | Faster deployments (automated) |
| **🔙 Rollback** | Easy rollback (git revert) |
| **👥 Collaboration** | PRs for infrastructure changes |
| **🔍 Observability** | Visibility into desired vs actual state |
| **🛡️ Disaster recovery** | Git = backup of entire system |

### Challenges

| Challenge | Solution |
|-----------|----------|
| **Secrets management** | Use Sealed Secrets, External Secrets Operator |
| **Large binary files** | Store in artifact stores (S3), reference in Git |
| **Learning curve** | Training, documentation, gradual adoption |
| **Latency** | ArgoCD polls every 3 min (can use webhooks) |
| **Debugging** | Check ArgoCD logs, use diff view |

---

## Code Walkthrough

### ArgoCD Application Manifest

```yaml
# argocd/staging/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-staging
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io  # Cleanup on delete
spec:
  # Which project (for RBAC)
  project: default
  
  # Source: Where to get manifests
  source:
    repoURL: https://github.com/yourusername/churn-mlops-prod.git
    targetRevision: main  # Branch or tag
    path: k8s/helm/churn-mlops  # Path to Helm chart
    
    helm:
      valueFiles:
        - values.yaml           # Base values
        - values-staging.yaml   # Staging overrides
      parameters:
        - name: image.tag
          value: staging
  
  # Destination: Where to deploy
  destination:
    server: https://kubernetes.default.svc  # In-cluster
    namespace: churn-mlops-staging
  
  # Sync policy: How to deploy
  syncPolicy:
    automated:
      prune: true      # Delete resources removed from Git
      selfHeal: true   # Revert manual changes
      allowEmpty: false
    
    syncOptions:
      - CreateNamespace=true  # Auto-create namespace
      - PrunePropagationPolicy=foreground
      - PruneLast=true  # Prune after successful sync
    
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  # Keep 10 revisions for rollback
  revisionHistoryLimit: 10
  
  # Ignore differences (e.g., HPA changes replicas)
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Don't sync replica count
```

**Key Fields Explained**:

- **`finalizers`**: Ensures resources are cleaned up on deletion
- **`automated.prune`**: Automatically delete resources removed from Git
- **`automated.selfHeal`**: Revert manual `kubectl` changes
- **`syncOptions.CreateNamespace`**: Auto-create target namespace
- **`ignoreDifferences`**: Don't sync specific fields (e.g., HPA-managed replicas)

---

## Hands-On Exercise

### Exercise 1: Understand GitOps Flow

**Scenario**: Deploy change via GitOps

```bash
# 1. Make change in Git
vim k8s/helm/churn-mlops/values-staging.yaml
# Change replicas: 2 → 3

# 2. Commit and push
git add k8s/helm/churn-mlops/values-staging.yaml
git commit -m "scale: increase staging replicas to 3"
git push origin main

# 3. Wait for ArgoCD to detect (or trigger manually)
# ArgoCD polls Git every 3 minutes

# 4. Check ArgoCD UI
# Go to: http://localhost:8080 (port-forward)
# See: Application "OutOfSync" → "Synced"

# 5. Verify in Kubernetes
kubectl get pods -n churn-mlops-staging
# Should see 3 pods running
```

### Exercise 2: Compare Declarative vs Imperative

**Imperative** (traditional):
```bash
kubectl scale deployment churn-api --replicas=5 -n staging
# Problem: Change not tracked, can drift
```

**Declarative** (GitOps):
```yaml
# values-staging.yaml
replicaCount: 5
```
```bash
git add values-staging.yaml
git commit -m "scale: increase to 5 replicas"
git push
# Benefit: Change tracked in Git, auditable, reversible
```

### Exercise 3: Simulate Drift Detection

```bash
# 1. Make manual change (simulate drift)
kubectl scale deployment churn-api --replicas=10 -n churn-mlops-staging

# 2. Check pods
kubectl get pods -n churn-mlops-staging
# Should see 10 pods

# 3. Wait for ArgoCD self-heal (~3 minutes)
# ArgoCD detects drift and reverts

# 4. Check pods again
kubectl get pods -n churn-mlops-staging
# Back to 3 pods (as defined in Git)
```

### Exercise 4: Visualize Git as Source of Truth

```bash
# Show Git history
git log --oneline --graph k8s/helm/churn-mlops/values-staging.yaml

# Example output:
# * abc123 scale: increase to 3 replicas
# * def456 feat: add new feature flag
# * ghi789 fix: correct image tag
#
# Each commit = deployment change
# Can rollback to any commit
```

### Exercise 5: Practice Rollback

```bash
# 1. Current state
kubectl get deployment churn-api -n churn-mlops-staging
# Replicas: 3

# 2. Rollback to previous commit
git revert HEAD
git push origin main

# 3. ArgoCD syncs
# Replicas automatically reverted to 2

# 4. Verify
kubectl get deployment churn-api -n churn-mlops-staging
# Replicas: 2
```

---

## Assessment Questions

### Question 1: Multiple Choice
What is the main principle of GitOps?

A) Use Git for code only  
B) **Git as single source of truth for everything** ✅  
C) Deploy manually with Git tags  
D) Store secrets in Git  

---

### Question 2: True/False
**Statement**: In GitOps, the CI/CD system directly applies changes to Kubernetes.

**Answer**: False ❌  
**Explanation**: GitOps uses a **pull-based** model. A controller **in the cluster** pulls changes from Git, not pushed from CI/CD.

---

### Question 3: Short Answer
What's the difference between "prune" and "self-heal" in ArgoCD?

**Answer**:
- **Prune**: Delete resources removed from Git (e.g., delete deployment if removed from manifest)
- **Self-heal**: Revert manual changes made via `kubectl` (e.g., if someone manually scales deployment, revert to Git-defined replicas)

---

### Question 4: Code Analysis
What happens when this is applied?

```yaml
syncPolicy:
  automated:
    prune: false
    selfHeal: true
```

**Answer**:
- **Prune disabled**: Resources removed from Git will **not** be deleted from cluster (manual cleanup needed)
- **Self-heal enabled**: Manual `kubectl` changes **will** be reverted to match Git
- **Use case**: Production (safer to manually delete resources, but still prevent drift)

---

### Question 5: Design Challenge
Design GitOps workflow for ML model deployment with model registry.

**Answer**:
```
1. Data Scientist trains model
   ↓
2. Model pushed to MLflow Registry
   - Model: churn-model-v1.2.3
   - Artifact: s3://models/churn/v1.2.3/model.pkl
   ↓
3. CI/CD builds inference container
   - Dockerfile includes model loading code
   - Image: ghcr.io/churn-api:v1.2.3
   ↓
4. CI/CD updates Git manifest
   - values-staging.yaml:
       image.tag: v1.2.3
       model.version: v1.2.3
       model.path: s3://models/churn/v1.2.3/
   ↓
5. ArgoCD syncs
   - Deploys new API container
   - Container loads model from S3
   - Health check verifies model loaded
   ↓
6. Production serves new model ✅

Key: Model artifacts in S3, metadata in Git
```

---

## Key Takeaways

### ✅ What You Learned

1. **GitOps Principles**
   - Declarative (describe desired state)
   - Versioned (Git history = audit trail)
   - Pull-based (controller pulls from Git)
   - Continuously reconciled (self-healing)

2. **GitOps vs Traditional**
   - Pull vs push deployment
   - Git as source of truth
   - Automatic drift detection
   - Easy rollback with git revert

3. **GitOps Tools**
   - ArgoCD (UI, multi-cluster)
   - Flux (lightweight)
   - Jenkins X (full CI/CD)

4. **GitOps for MLOps**
   - Code + config in Git
   - Models in artifact stores
   - Metadata in Git

5. **Benefits**
   - Security (no external credentials)
   - Auditability (Git history)
   - Consistency (same process everywhere)
   - Easy rollback

---

## Next Steps

Continue to **[Section 24: ArgoCD Setup](./section-24-argocd-setup.md)**

In the next section, we'll:
- Install ArgoCD in Kubernetes
- Configure ArgoCD CLI
- Create first application
- Explore ArgoCD UI

---

## Additional Resources

- [GitOps Principles](https://www.gitops.tech/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Flux Documentation](https://fluxcd.io/)
- [CNCF GitOps Working Group](https://github.com/cncf/tag-app-delivery/tree/main/gitops-wg)

---

**Progress**: 21/34 sections complete (62%) → **22/34 (65%)**
