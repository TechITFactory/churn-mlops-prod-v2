# Section 24: ArgoCD Setup and Configuration

**Duration**: 2.5 hours  
**Level**: Intermediate  
**Prerequisites**: Section 23 (GitOps Principles), Module 5 (Kubernetes)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Install ArgoCD in Kubernetes cluster
- ✅ Access ArgoCD UI and CLI
- ✅ Configure ArgoCD with Git repositories
- ✅ Create ArgoCD Applications
- ✅ Understand ArgoCD Projects and RBAC
- ✅ Configure sync policies and health checks
- ✅ Set up notifications and webhooks

---

## 📚 Table of Contents

1. [ArgoCD Installation](#argocd-installation)
2. [Accessing ArgoCD](#accessing-argocd)
3. [ArgoCD CLI](#argocd-cli)
4. [Creating Applications](#creating-applications)
5. [Projects and RBAC](#projects-and-rbac)
6. [Sync Policies](#sync-policies)
7. [Notifications](#notifications)
8. [Code Walkthrough](#code-walkthrough)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## ArgoCD Installation

### Prerequisites

```bash
# 1. Kubernetes cluster (minikube, kind, or cloud)
kubectl cluster-info

# 2. kubectl configured
kubectl get nodes

# 3. Helm (optional, for easier installation)
helm version
```

### Install ArgoCD

**Method 1: Using kubectl**

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Check installation
kubectl get pods -n argocd
```

**Expected output**:
```
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-application-controller-0       1/1     Running   0          2m
argocd-dex-server-5dd67f4f9c-8xqwt   1/1     Running   0          2m
argocd-redis-74cb89f466-9rmfb        1/1     Running   0          2m
argocd-repo-server-6c5f4d8f6-xj9qg   1/1     Running   0          2m
argocd-server-7d5d8d5d9f-2tggh       1/1     Running   0          2m
```

**Method 2: Using Helm**

```bash
# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer

# Check
helm list -n argocd
```

### ArgoCD Components

```
ArgoCD Architecture:

┌─────────────────────────────────────────────────┐
│  argocd namespace                                │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌─────────────────────────────────────────┐   │
│  │  argocd-server                           │   │
│  │  - Web UI (HTTPS)                        │   │
│  │  - API server                            │   │
│  │  - gRPC server                           │   │
│  └─────────────────────────────────────────┘   │
│                    ↑                            │
│  ┌─────────────────────────────────────────┐   │
│  │  argocd-application-controller           │   │
│  │  - Monitors Git repositories             │   │
│  │  - Compares desired vs actual state      │   │
│  │  - Executes sync operations              │   │
│  └─────────────────────────────────────────┘   │
│                    ↑                            │
│  ┌─────────────────────────────────────────┐   │
│  │  argocd-repo-server                      │   │
│  │  - Clones Git repositories               │   │
│  │  - Renders manifests (Helm, Kustomize)   │   │
│  │  - Caches repository data                │   │
│  └─────────────────────────────────────────┘   │
│                    ↑                            │
│  ┌─────────────────────────────────────────┐   │
│  │  argocd-redis                            │   │
│  │  - Cache for manifests                   │   │
│  │  - Session storage                       │   │
│  └─────────────────────────────────────────┘   │
│                                                  │
│  ┌─────────────────────────────────────────┐   │
│  │  argocd-dex-server                       │   │
│  │  - OAuth2 / SSO integration              │   │
│  │  - LDAP, SAML, GitHub auth               │   │
│  └─────────────────────────────────────────┘   │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

## Accessing ArgoCD

### Get Initial Admin Password

```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Output: random password (e.g., A7bC9dEfGhI3)
```

### Access UI

**Option 1: Port Forward**

```bash
# Forward port 8080 → ArgoCD server port 443
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser
# https://localhost:8080

# Login:
# Username: admin
# Password: (from command above)
```

**Option 2: LoadBalancer** (cloud clusters)

```bash
# Change service type to LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get external IP
kubectl get svc argocd-server -n argocd

# Open browser
# https://<EXTERNAL-IP>
```

**Option 3: Ingress**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - argocd.example.com
      secretName: argocd-server-tls
  rules:
    - host: argocd.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
```

### Change Admin Password

```bash
# Login first (see CLI section below)
argocd login localhost:8080

# Change password
argocd account update-password
# Current password: A7bC9dEfGhI3
# New password: MySecurePassword123
```

---

## ArgoCD CLI

### Install CLI

**macOS**:
```bash
brew install argocd
```

**Linux**:
```bash
# Download
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# Install
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Verify
argocd version
```

**Windows**:
```powershell
# Download from GitHub releases
# https://github.com/argoproj/argo-cd/releases

# Or use Scoop
scoop install argocd
```

### Login

```bash
# Port forward first (if not using LoadBalancer)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login (in another terminal)
argocd login localhost:8080 \
  --username admin \
  --password A7bC9dEfGhI3 \
  --insecure  # Skip TLS verification for localhost

# Success: 'admin:login' logged in successfully
```

### Common CLI Commands

```bash
# List applications
argocd app list

# Get application details
argocd app get <app-name>

# Sync application
argocd app sync <app-name>

# View sync history
argocd app history <app-name>

# Rollback to previous version
argocd app rollback <app-name> <revision>

# Delete application
argocd app delete <app-name>

# List repositories
argocd repo list

# Add repository
argocd repo add https://github.com/username/repo.git

# List clusters
argocd cluster list
```

---

## Creating Applications

### Application CRD

> **Application**: ArgoCD custom resource defining what to deploy and where

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-staging
  namespace: argocd
spec:
  # Source: Where to get manifests
  source:
    repoURL: https://github.com/yourusername/churn-mlops-prod.git
    targetRevision: main
    path: k8s/helm/churn-mlops
    helm:
      valueFiles:
        - values.yaml
        - values-staging.yaml
  
  # Destination: Where to deploy
  destination:
    server: https://kubernetes.default.svc
    namespace: churn-mlops-staging
  
  # Sync policy
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Create Application via UI

1. **Login** to ArgoCD UI
2. Click **+ New App**
3. Fill form:
   - **Application Name**: `churn-mlops-staging`
   - **Project**: `default`
   - **Sync Policy**: `Automatic`
   - **Repository URL**: `https://github.com/yourusername/churn-mlops-prod.git`
   - **Revision**: `main`
   - **Path**: `k8s/helm/churn-mlops`
   - **Cluster URL**: `https://kubernetes.default.svc`
   - **Namespace**: `churn-mlops-staging`
4. Click **Create**

### Create Application via CLI

```bash
argocd app create churn-mlops-staging \
  --repo https://github.com/yourusername/churn-mlops-prod.git \
  --path k8s/helm/churn-mlops \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace churn-mlops-staging \
  --sync-policy automated \
  --auto-prune \
  --self-heal \
  --helm-set image.tag=staging

# Sync immediately
argocd app sync churn-mlops-staging
```

### Create Application via YAML

```bash
# Apply manifest
kubectl apply -f argocd/staging/application.yaml

# Check status
argocd app get churn-mlops-staging
```

### Application Health Status

```
Health Status:

├── Healthy    ✅ All resources running correctly
├── Progressing ⏳ Deployment in progress
├── Degraded   ⚠️  Some resources failing
├── Suspended  ⏸️  Manually suspended
├── Missing    ❌ Resources not found
└── Unknown    ❓ Health unknown
```

### Sync Status

```
Sync Status:

├── Synced      ✅ Git == Cluster
├── OutOfSync   ⚠️  Git ≠ Cluster
└── Unknown     ❓ Status unknown
```

---

## Projects and RBAC

### What is an AppProject?

> **AppProject**: Group of applications with shared RBAC policies

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production MLOps Project
  
  # Allowed source repositories
  sourceRepos:
    - https://github.com/yourusername/churn-mlops-prod.git
  
  # Allowed destination clusters and namespaces
  destinations:
    - namespace: churn-mlops-production
      server: https://kubernetes.default.svc
    - namespace: churn-mlops-staging
      server: https://kubernetes.default.svc
  
  # Allowed cluster-scoped resources
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
    - group: ''
      kind: PersistentVolume
  
  # Allowed namespace-scoped resources (all)
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
  
  # RBAC roles
  roles:
    - name: admin
      description: Admin privileges
      policies:
        - p, proj:production:admin, applications, *, production/*, allow
      groups:
        - production-admins
    
    - name: developer
      description: Developer access
      policies:
        - p, proj:production:developer, applications, get, production/*, allow
        - p, proj:production:developer, applications, sync, production/*, allow
      groups:
        - developers
```

**Key Concepts**:

- **`sourceRepos`**: Which Git repos can be used
- **`destinations`**: Which clusters/namespaces can be deployed to
- **`clusterResourceWhitelist`**: Cluster-scoped resources (e.g., Namespace)
- **`namespaceResourceWhitelist`**: Namespace-scoped resources
- **`roles`**: RBAC policies for users/groups

### Sync Windows

> **Sync Windows**: Time periods when sync is allowed/denied

```yaml
spec:
  syncWindows:
    # Deny deployments 10 PM - 6 AM UTC
    - kind: deny
      schedule: '0 22 * * *'  # Cron: 10 PM
      duration: 8h            # 8 hours
      applications:
        - '*'                 # All apps
      manualSync: true        # Allow manual sync
      timeZone: UTC
    
    # Allow deployments only during business hours
    - kind: allow
      schedule: '0 9 * * MON-FRI'  # 9 AM weekdays
      duration: 8h
      applications:
        - churn-mlops-production
```

---

## Sync Policies

### Automated Sync

```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources removed from Git
    selfHeal: true   # Revert manual changes
    allowEmpty: false # Don't sync if no resources
```

### Sync Options

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true   # Auto-create namespace
    - PrunePropagationPolicy=foreground  # Delete order
    - PruneLast=true         # Prune after successful sync
    - ApplyOutOfSyncOnly=true # Only sync out-of-sync resources
    - RespectIgnoreDifferences=true  # Honor ignoreDifferences
```

### Retry Policy

```yaml
syncPolicy:
  retry:
    limit: 5           # Max retry attempts
    backoff:
      duration: 5s     # Initial delay
      factor: 2        # Exponential backoff
      maxDuration: 3m  # Max delay
```

**Retry Logic**:
```
Attempt 1: Wait 5s
Attempt 2: Wait 10s (5s × 2)
Attempt 3: Wait 20s (10s × 2)
Attempt 4: Wait 40s (20s × 2)
Attempt 5: Wait 1m20s (40s × 2)
Give up after 5 attempts
```

### Ignore Differences

> **ignoreDifferences**: Fields to exclude from diff

```yaml
spec:
  ignoreDifferences:
    # Ignore replicas (managed by HPA)
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
    
    # Ignore HPA replicas
    - group: autoscaling
      kind: HorizontalPodAutoscaler
      jsonPointers:
        - /spec/replicas
    
    # Ignore all fields in a resource
    - group: ''
      kind: Secret
      name: auto-generated-secret
      jsonPointers:
        - /data
```

---

## Notifications

### Notification Triggers

```yaml
triggers:
  - on-sync-succeeded  # Deployment succeeded
  - on-sync-failed     # Deployment failed
  - on-health-degraded # Application unhealthy
  - on-deployed        # New version deployed
```

### Slack Notifications

**1. Create Slack Webhook**:
- Go to Slack App → Incoming Webhooks
- Create webhook for channel (e.g., `#churn-mlops-alerts`)
- Copy webhook URL

**2. Configure ArgoCD**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  
  trigger.on-sync-succeeded: |
    - when: app.status.sync.status == 'Synced'
      send: [app-sync-succeeded]
  
  trigger.on-sync-failed: |
    - when: app.status.sync.status == 'Failed'
      send: [app-sync-failed]
  
  template.app-sync-succeeded: |
    message: |
      Application {{.app.metadata.name}} synced successfully!
      Revision: {{.app.status.sync.revision}}
      Repository: {{.app.spec.source.repoURL}}
  
  template.app-sync-failed: |
    message: |
      ⚠️ Application {{.app.metadata.name}} sync FAILED!
      Error: {{.app.status.operationState.message}}
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
stringData:
  slack-token: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

**3. Subscribe Application**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-production
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: churn-mlops-alerts
    notifications.argoproj.io/subscribe.on-sync-failed.slack: churn-mlops-alerts
    notifications.argoproj.io/subscribe.on-health-degraded.slack: churn-mlops-alerts
```

---

## Code Walkthrough

### Complete Application with All Features

```yaml
# argocd/production/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-production
  namespace: argocd
  
  # Cleanup on delete
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  
  # Notifications
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: churn-mlops-alerts
    notifications.argoproj.io/subscribe.on-sync-failed.slack: churn-mlops-alerts
    notifications.argoproj.io/subscribe.on-health-degraded.slack: churn-mlops-alerts

spec:
  # Use production project (RBAC)
  project: production
  
  # Source: Git repository
  source:
    repoURL: https://github.com/yourusername/churn-mlops-prod.git
    targetRevision: main  # Track main branch
    path: k8s/helm/churn-mlops
    
    helm:
      valueFiles:
        - values.yaml           # Base values
        - values-production.yaml # Production overrides
      
      parameters:
        - name: image.tag
          value: v1.0.0         # Production version
  
  # Destination: Production namespace
  destination:
    server: https://kubernetes.default.svc
    namespace: churn-mlops-production
  
  # Sync policy
  syncPolicy:
    automated:
      prune: false      # Manual prune in production
      selfHeal: true    # Auto-revert manual changes
      allowEmpty: false
    
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 5m
  
  # Keep 20 revisions for rollback
  revisionHistoryLimit: 20
  
  # Ignore HPA-managed fields
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
    - group: autoscaling
      kind: HorizontalPodAutoscaler
      jsonPointers:
        - /spec/replicas
```

---

## Hands-On Exercise

### Exercise 1: Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
```

### Exercise 2: Login with CLI

```bash
# Install CLI (if not already)
# macOS: brew install argocd
# Linux: curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && sudo install argocd /usr/local/bin/

# Login
argocd login localhost:8080 \
  --username admin \
  --password <password-from-step-1> \
  --insecure

# Change password
argocd account update-password
```

### Exercise 3: Create First Application

**Option A: Via CLI**
```bash
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Sync
argocd app sync guestbook

# Check
argocd app get guestbook
kubectl get all -n default
```

**Option B: Via UI**
1. Login to ArgoCD UI
2. Click **+ New App**
3. Fill:
   - Name: `guestbook`
   - Project: `default`
   - Repo: `https://github.com/argoproj/argocd-example-apps.git`
   - Path: `guestbook`
   - Cluster: `https://kubernetes.default.svc`
   - Namespace: `default`
4. Click **Create** → **Sync**

### Exercise 4: Create Churn MLOps Application

```bash
# Update repo URL in manifest
vim argocd/staging/application.yaml
# Change: yourusername → your-github-username

# Apply
kubectl apply -f argocd/staging/application.yaml

# Check
argocd app get churn-mlops-staging

# Sync
argocd app sync churn-mlops-staging

# Watch progress
argocd app wait churn-mlops-staging --health
```

### Exercise 5: Test Self-Heal

```bash
# Make manual change
kubectl scale deployment churn-api --replicas=10 -n churn-mlops-staging

# Check (should be 10)
kubectl get deployment churn-api -n churn-mlops-staging

# Wait for ArgoCD to detect and revert (~3 minutes)
# Or trigger manual sync
argocd app sync churn-mlops-staging

# Check again (reverted to Git-defined replicas)
kubectl get deployment churn-api -n churn-mlops-staging
```

---

## Assessment Questions

### Question 1: Multiple Choice
What does `prune: true` do in ArgoCD?

A) Delete the application  
B) **Delete resources removed from Git** ✅  
C) Clean up logs  
D) Remove old revisions  

---

### Question 2: True/False
**Statement**: `selfHeal: true` automatically deploys new commits from Git.

**Answer**: False ❌  
**Explanation**: `selfHeal` **reverts manual changes** made via `kubectl`. Auto-deploying new commits requires `automated` sync policy.

---

### Question 3: Short Answer
What's the difference between ArgoCD Application and AppProject?

**Answer**:
- **Application**: Defines a specific app to deploy (repo, path, destination)
- **AppProject**: Groups multiple applications with shared RBAC policies, allowed repos, and destinations

---

### Question 4: Code Analysis
What's wrong with this configuration?

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: false
```

**Answer**:
- **Prune enabled** but **self-heal disabled**: Resources removed from Git will be deleted, but manual `kubectl` changes won't be reverted
- **Inconsistent**: Usually both enabled (staging) or both limited (production)
- **Risk**: Manual changes can cause drift without detection

---

### Question 5: Design Challenge
Design ArgoCD setup for 3 environments (dev, staging, prod) with different sync policies.

**Answer**:
```yaml
# Dev: Full automation
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-dev
spec:
  source:
    targetRevision: develop  # Track develop branch
  syncPolicy:
    automated:
      prune: true   # Auto-delete
      selfHeal: true # Auto-revert
---
# Staging: Auto-sync, manual prune
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-staging
spec:
  source:
    targetRevision: main
  syncPolicy:
    automated:
      prune: false  # Manual prune
      selfHeal: true
---
# Production: Manual sync
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-prod
spec:
  source:
    targetRevision: v1.0.0  # Track specific tag
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
  syncWindows:
    - kind: deny
      schedule: '0 22 * * *'
      duration: 8h
```

---

## Key Takeaways

### ✅ What You Learned

1. **ArgoCD Installation**
   - Install via kubectl or Helm
   - Components: server, controller, repo-server, redis
   - Access via UI, CLI, or API

2. **ArgoCD CLI**
   - Install and login
   - Create, sync, manage applications
   - View history, rollback

3. **Applications**
   - Define source (repo, path, branch)
   - Define destination (cluster, namespace)
   - Configure sync policies

4. **Projects and RBAC**
   - Group applications
   - Control access (roles, policies)
   - Sync windows

5. **Sync Policies**
   - Automated vs manual
   - Prune, self-heal
   - Retry, ignore differences

6. **Notifications**
   - Slack, email alerts
   - Triggers (sync, health, deploy)

---

## Next Steps

Continue to **[Section 25: Automated Deployments](./section-25-automated-deployments.md)**

In the next section, we'll:
- Implement full GitOps workflow
- Auto-sync from Git commits
- Handle rollbacks
- Monitor deployments

---

## Additional Resources

- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ArgoCD CLI Reference](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/)

---

**Progress**: 22/34 sections complete (65%) → **23/34 (68%)**
