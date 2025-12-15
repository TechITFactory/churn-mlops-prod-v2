# Section 25: Automated Deployments with GitOps

**Duration**: 3 hours  
**Level**: Advanced  
**Prerequisites**: Sections 23-24 (GitOps Principles, ArgoCD Setup), Module 6 (CI/CD)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Implement end-to-end GitOps workflow
- ✅ Integrate CI/CD with ArgoCD
- ✅ Automate deployments from Git commits
- ✅ Handle multi-environment promotions
- ✅ Implement progressive delivery
- ✅ Perform safe rollbacks
- ✅ Monitor and troubleshoot deployments

---

## 📚 Table of Contents

1. [End-to-End GitOps Workflow](#end-to-end-gitops-workflow)
2. [CI/CD Integration](#cicd-integration)
3. [Image Updater Pattern](#image-updater-pattern)
4. [Multi-Environment Strategy](#multi-environment-strategy)
5. [Progressive Delivery](#progressive-delivery)
6. [Rollback Strategies](#rollback-strategies)
7. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
8. [Code Walkthrough](#code-walkthrough)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## End-to-End GitOps Workflow

### Complete Deployment Flow

```
┌──────────────────────────────────────────────────────────┐
│  Step 1: Developer Commits Code                           │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  $ vim src/churn_mlops/api/app.py                        │
│  $ git commit -m "feat: add new prediction endpoint"     │
│  $ git push origin feature/new-endpoint                  │
│                                                            │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│  Step 2: CI Pipeline (GitHub Actions)                     │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  Triggered by: Push to branch                             │
│                                                            │
│  Jobs:                                                     │
│    ✅ Lint code (Ruff)                                     │
│    ✅ Run tests (pytest)                                   │
│    ✅ Security scan (Bandit, Safety)                       │
│    ✅ Build Docker image                                   │
│    ✅ Push to ghcr.io (tag: sha-abc123)                   │
│                                                            │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│  Step 3: CD Pipeline Updates Manifests                    │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  $ sed -i 's/tag:.*/tag: sha-abc123/' values-staging.yaml│
│  $ git commit -m "chore: update image tag to sha-abc123" │
│  $ git push origin main                                   │
│                                                            │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│  Step 4: ArgoCD Detects Change                            │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  ArgoCD polls Git every 3 minutes                         │
│  Detects: values-staging.yaml changed                     │
│  Status: OutOfSync                                         │
│                                                            │
│  Git (desired):    image.tag = sha-abc123                 │
│  Cluster (actual): image.tag = sha-def456                 │
│                                                            │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│  Step 5: ArgoCD Syncs Application                         │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  ArgoCD renders Helm chart                                │
│  Applies changes:                                          │
│    $ kubectl set image deployment/churn-api \             │
│        churn-api=ghcr.io/user/churn-api:sha-abc123       │
│                                                            │
│  Kubernetes rolling update:                                │
│    New pod:  churn-api-new-xyz  (Creating → Running)      │
│    Old pod:  churn-api-old-abc  (Running → Terminating)   │
│                                                            │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│  Step 6: Health Checks Pass                               │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  ArgoCD monitors health:                                   │
│    ✅ Liveness probe:  /live  (200 OK)                     │
│    ✅ Readiness probe: /ready (200 OK)                     │
│    ✅ Pods running: 3/3                                    │
│                                                            │
│  Status: Synced + Healthy                                  │
│  Deployment complete! 🚀                                   │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

### Timing

```
Total deployment time: ~5-10 minutes

Breakdown:
- CI pipeline:        2-3 minutes (tests, build, push)
- Update manifests:   10 seconds
- ArgoCD poll:        0-3 minutes (depends on timing)
- Sync + rollout:     1-2 minutes (K8s rolling update)
- Health checks:      30 seconds

Optimization:
- Use webhooks instead of polling → 0 seconds
- Parallel tests → faster CI
- Docker layer caching → faster builds
```

---

## CI/CD Integration

### GitHub Actions Workflow with ArgoCD

```yaml
# .github/workflows/cd-gitops.yml
name: CD - GitOps Deployment

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # ============================================
  # Job 1: Build and Push Docker Image
  # ============================================
  build:
    name: Build and Push
    runs-on: ubuntu-latest
    permissions:
      contents: write  # Push manifest updates
      packages: write  # Push Docker images
    
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      short-sha: ${{ steps.vars.outputs.short-sha }}
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set variables
        id: vars
        run: |
          echo "short-sha=$(git rev-parse --short HEAD)" >> $GITHUB_OUTPUT

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-api
          tags: |
            type=sha,prefix={{branch}}-
            type=ref,event=branch
            type=ref,event=pr

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile.api
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ============================================
  # Job 2: Update GitOps Manifests
  # ============================================
  update-manifests:
    name: Update Manifests
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Update image tag
        run: |
          # Update staging values
          sed -i "s|tag:.*|tag: \"${{ needs.build.outputs.short-sha }}\"|g" \
            k8s/helm/churn-mlops/values-staging.yaml
          
          echo "Updated image tag to: ${{ needs.build.outputs.short-sha }}"

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          
          git add k8s/helm/churn-mlops/values-staging.yaml
          git commit -m "chore: update staging image to ${{ needs.build.outputs.short-sha }}" || exit 0
          git push

  # ============================================
  # Job 3: Trigger ArgoCD Sync
  # ============================================
  sync-argocd:
    name: Sync ArgoCD
    needs: update-manifests
    runs-on: ubuntu-latest
    
    steps:
      - name: Trigger ArgoCD sync
        env:
          ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
          ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}
        run: |
          # Install ArgoCD CLI
          curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
          chmod +x argocd
          
          # Sync application
          ./argocd app sync churn-mlops-staging \
            --server $ARGOCD_SERVER \
            --auth-token $ARGOCD_AUTH_TOKEN \
            --insecure
          
          # Wait for sync
          ./argocd app wait churn-mlops-staging \
            --server $ARGOCD_SERVER \
            --auth-token $ARGOCD_AUTH_TOKEN \
            --health \
            --timeout 300

      - name: Get sync status
        if: always()
        run: |
          ./argocd app get churn-mlops-staging \
            --server ${{ secrets.ARGOCD_SERVER }} \
            --auth-token ${{ secrets.ARGOCD_AUTH_TOKEN }}
```

### ArgoCD Authentication Token

```bash
# Login to ArgoCD
argocd login argocd.example.com --username admin

# Create service account
argocd account create github-actions --yes

# Generate token (save to GitHub Secrets)
argocd account generate-token --account github-actions

# Add to GitHub:
# Settings → Secrets → Actions → New repository secret
# Name: ARGOCD_AUTH_TOKEN
# Value: <token-from-above>
```

---

## Image Updater Pattern

### Problem: Manual Image Updates

```
Problem:
1. CI builds image: ghcr.io/user/app:sha-abc123
2. Manual step: Update values.yaml with new tag
3. ArgoCD syncs

Issues:
❌ Manual work
❌ Slow
❌ Error-prone
```

### Solution 1: CI Updates Manifests

```yaml
# GitHub Actions updates values.yaml
- name: Update image tag
  run: |
    sed -i 's|tag:.*|tag: ${{ github.sha }}|' values.yaml
    git commit -am "chore: update image"
    git push
```

**Pros**: ✅ Simple, ✅ Works with any CI  
**Cons**: ❌ Commits to Git for every image change

### Solution 2: ArgoCD Image Updater

> **ArgoCD Image Updater**: Automatically updates image tags in Git

**Install**:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

**Configure Application**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-staging
  annotations:
    # Enable image updater
    argocd-image-updater.argoproj.io/image-list: api=ghcr.io/user/churn-api
    # Update strategy: latest tag matching pattern
    argocd-image-updater.argoproj.io/api.update-strategy: latest
    # Write back to Git
    argocd-image-updater.argoproj.io/write-back-method: git
```

**How it works**:
```
1. Image Updater polls container registry
2. Detects new image: ghcr.io/user/churn-api:sha-xyz
3. Updates values.yaml in Git
4. Commits: "chore: update image to sha-xyz"
5. ArgoCD syncs new image
```

**Pros**: ✅ Fully automated, ✅ No CI changes needed  
**Cons**: ❌ Adds complexity, ❌ Requires registry access

---

## Multi-Environment Strategy

### Environment Promotion Flow

```
┌─────────────────────────────────────────────────────┐
│  Environment Progression                             │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Developer Branch (feature/new-model)                │
│    ↓ CI tests pass                                  │
│    ↓ Merge to develop                               │
│                                                      │
│  Development Environment                             │
│    - Branch: develop                                 │
│    - Auto-deploy (every commit)                      │
│    - Testing + validation                            │
│    ↓ Merge to main                                  │
│                                                      │
│  Staging Environment                                 │
│    - Branch: main                                    │
│    - Auto-deploy (every merge)                       │
│    - Pre-production testing                          │
│    ↓ Create release tag                             │
│                                                      │
│  Production Environment                              │
│    - Tag: v1.2.3                                     │
│    - Manual approval                                 │
│    - Monitoring + rollback ready                     │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### ArgoCD Applications for Each Environment

**Development**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-dev
spec:
  source:
    repoURL: https://github.com/user/churn-mlops.git
    targetRevision: develop  # Track develop branch
    path: k8s/helm/churn-mlops
    helm:
      valueFiles:
        - values.yaml
        - values-dev.yaml
  
  destination:
    namespace: churn-mlops-dev
  
  syncPolicy:
    automated:
      prune: true      # Aggressive cleanup
      selfHeal: true
```

**Staging**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-staging
spec:
  source:
    repoURL: https://github.com/user/churn-mlops.git
    targetRevision: main  # Track main branch
    path: k8s/helm/churn-mlops
    helm:
      valueFiles:
        - values.yaml
        - values-staging.yaml
  
  destination:
    namespace: churn-mlops-staging
  
  syncPolicy:
    automated:
      prune: false     # Manual prune
      selfHeal: true
```

**Production**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-production
spec:
  source:
    repoURL: https://github.com/user/churn-mlops.git
    targetRevision: v1.2.3  # Track specific release tag
    path: k8s/helm/churn-mlops
    helm:
      valueFiles:
        - values.yaml
        - values-production.yaml
  
  destination:
    namespace: churn-mlops-production
  
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    
    # Block deploys during nights
    syncWindows:
      - kind: deny
        schedule: '0 22 * * *'
        duration: 8h
```

### Promotion Process

```bash
# Step 1: Deploy to development
git checkout develop
git commit -m "feat: new model"
git push
# → Auto-deploys to dev

# Step 2: Test in development
# ... manual testing ...

# Step 3: Promote to staging
git checkout main
git merge develop
git push
# → Auto-deploys to staging

# Step 4: Test in staging
# ... smoke tests, integration tests ...

# Step 5: Promote to production
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3

# Step 6: Update production ArgoCD app
argocd app set churn-mlops-production --revision v1.2.3

# Step 7: Manual sync with approval
argocd app sync churn-mlops-production
```

---

## Progressive Delivery

### Blue-Green Deployment

```yaml
# Blue-Green with ArgoCD
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: churn-api
spec:
  replicas: 3
  strategy:
    blueGreen:
      activeService: churn-api-active
      previewService: churn-api-preview
      autoPromotionEnabled: false  # Manual promotion
  
  template:
    spec:
      containers:
        - name: api
          image: ghcr.io/user/churn-api:v1.2.3
```

**Workflow**:
```
1. Deploy new version (green)
   - Green pods created
   - Blue pods still serving traffic

2. Test green environment
   - Access via preview service
   - Run smoke tests

3. Promote or rollback
   - Promote: Switch traffic to green
   - Rollback: Delete green, keep blue
```

### Canary Deployment

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: churn-api
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 10    # 10% traffic to new version
        - pause: {duration: 5m}
        - setWeight: 25    # 25% traffic
        - pause: {duration: 5m}
        - setWeight: 50    # 50% traffic
        - pause: {duration: 5m}
        - setWeight: 75    # 75% traffic
        - pause: {duration: 5m}
        # If no errors, promote to 100%
```

**Benefits**:
- ✅ Gradual rollout (reduce blast radius)
- ✅ Real traffic testing
- ✅ Easy rollback if issues detected

---

## Rollback Strategies

### Method 1: Git Revert

```bash
# Revert last commit
git revert HEAD
git push origin main

# ArgoCD syncs reverted state automatically
# (if automated sync enabled)
```

**Pros**: ✅ Git history preserved, ✅ Auditable  
**Cons**: ❌ Requires Git knowledge

### Method 2: ArgoCD Rollback

```bash
# List history
argocd app history churn-mlops-production

# Output:
# ID  DATE                    REVISION
# 10  2023-12-15 10:00:00     v1.2.3
# 9   2023-12-14 14:30:00     v1.2.2
# 8   2023-12-13 09:15:00     v1.2.1

# Rollback to revision 9
argocd app rollback churn-mlops-production 9

# Or rollback to previous
argocd app rollback churn-mlops-production
```

**Pros**: ✅ Fast, ✅ One command  
**Cons**: ❌ Doesn't update Git (drift)

### Method 3: Update Target Revision

```bash
# Change target revision in Application
kubectl patch application churn-mlops-production -n argocd \
  --type merge \
  --patch '{"spec":{"source":{"targetRevision":"v1.2.2"}}}'

# Sync
argocd app sync churn-mlops-production
```

**Pros**: ✅ Declarative, ✅ Git-trackable  
**Cons**: ❌ Requires manifest update

### Rollback Decision Tree

```
Issue detected in production
  ↓
Is it critical?
  ├─ Yes → Emergency rollback (Method 2: ArgoCD CLI)
  │         Fast, revert Git later
  │
  └─ No  → Planned rollback
            ├─ Method 1: Git revert (preferred)
            │   Maintains Git history
            │
            └─ Method 3: Update target revision
                For specific version rollback
```

---

## Monitoring and Troubleshooting

### ArgoCD UI Dashboard

```
Application View:
┌──────────────────────────────────────────────┐
│  churn-mlops-production                       │
│  ✅ Synced   ✅ Healthy                        │
├──────────────────────────────────────────────┤
│  Last Sync: 2 minutes ago                    │
│  Repo: github.com/user/churn-mlops           │
│  Revision: v1.2.3 (abc123)                   │
│  Namespace: churn-mlops-production           │
├──────────────────────────────────────────────┤
│  Resources:                                   │
│    Deployment  churn-api         ✅ Healthy  │
│    Service     churn-api         ✅ Healthy  │
│    ConfigMap   churn-config      ✅ Synced   │
│    CronJob     batch-score       ✅ Synced   │
└──────────────────────────────────────────────┘
```

### CLI Monitoring

```bash
# Watch application
argocd app get churn-mlops-production --refresh

# View sync status
argocd app list

# View logs
argocd app logs churn-mlops-production

# View events
argocd app events churn-mlops-production

# View diff (Git vs Cluster)
argocd app diff churn-mlops-production
```

### Common Issues

**1. Application OutOfSync**

```bash
# Check diff
argocd app diff churn-mlops-staging

# Possible causes:
# - Manual kubectl changes
# - Git commit not pulled yet
# - Sync policy disabled

# Solution: Sync
argocd app sync churn-mlops-staging
```

**2. Sync Fails**

```bash
# View logs
argocd app logs churn-mlops-staging

# Common causes:
# - Invalid YAML
# - Missing namespace
# - RBAC issues
# - Resource conflicts

# Solution: Check ArgoCD controller logs
kubectl logs -n argocd \
  -l app.kubernetes.io/name=argocd-application-controller
```

**3. Health Degraded**

```bash
# Check resource health
argocd app get churn-mlops-staging

# Common causes:
# - Pods CrashLooping
# - Failed health checks
# - Resource limits exceeded

# Solution: Check pod logs
kubectl logs -n churn-mlops-staging deployment/churn-api
```

---

## Code Walkthrough

### Complete GitOps Setup

**1. CI/CD Workflow** (`.github/workflows/cd-gitops.yml`):
```yaml
name: CD GitOps
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Build and push image
      - name: Build image
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/user/app:${{ github.sha }}
      
      # Update manifest
      - name: Update manifest
        run: |
          sed -i "s|tag:.*|tag: ${{ github.sha }}|" \
            k8s/helm/values-staging.yaml
          git add k8s/helm/values-staging.yaml
          git commit -m "chore: update image"
          git push
```

**2. ArgoCD Application** (`argocd/staging/application.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-staging
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/user/churn-mlops.git
    targetRevision: main
    path: k8s/helm/churn-mlops
    helm:
      valueFiles:
        - values-staging.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: churn-mlops-staging
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**3. Helm Values** (`k8s/helm/churn-mlops/values-staging.yaml`):
```yaml
image:
  repository: ghcr.io/user/churn-api
  tag: abc123  # Updated by CI/CD
  pullPolicy: IfNotPresent

replicaCount: 3

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

---

## Hands-On Exercise

### Exercise 1: Complete GitOps Flow

```bash
# 1. Make code change
vim src/churn_mlops/api/app.py
# Add new endpoint

# 2. Commit and push
git add .
git commit -m "feat: add health check endpoint"
git push origin feature/health

# 3. Create PR, wait for CI
# GitHub Actions runs tests

# 4. Merge to main
# Triggers CD pipeline

# 5. Watch ArgoCD
argocd app watch churn-mlops-staging

# 6. Verify deployment
kubectl get pods -n churn-mlops-staging
curl https://staging-api.example.com/health
```

### Exercise 2: Manual Rollback

```bash
# 1. View history
argocd app history churn-mlops-staging

# 2. Rollback to previous revision
argocd app rollback churn-mlops-staging

# 3. Verify
kubectl get pods -n churn-mlops-staging
```

### Exercise 3: Sync Policies

```bash
# Disable auto-sync
argocd app set churn-mlops-staging --sync-policy none

# Make change in Git
vim k8s/helm/values-staging.yaml
git commit -am "test: disable auto-sync"
git push

# App shows OutOfSync
argocd app get churn-mlops-staging

# Manual sync required
argocd app sync churn-mlops-staging

# Re-enable auto-sync
argocd app set churn-mlops-staging --sync-policy automated
```

### Exercise 4: Multi-Environment Promotion

```bash
# Deploy to dev
git checkout develop
git commit -m "feat: new feature"
git push
# Auto-deploys to dev

# Test in dev
curl https://dev-api.example.com/health

# Promote to staging
git checkout main
git merge develop
git push
# Auto-deploys to staging

# Test in staging
curl https://staging-api.example.com/health

# Promote to production
git tag v1.3.0
git push origin v1.3.0

# Update production app
argocd app set churn-mlops-production --revision v1.3.0
argocd app sync churn-mlops-production
```

### Exercise 5: Troubleshoot Sync Failure

```bash
# Introduce error in manifest
vim k8s/helm/churn-mlops/templates/deployment.yaml
# Add invalid YAML

git commit -am "test: break deployment"
git push

# Watch sync fail
argocd app get churn-mlops-staging

# View error
argocd app logs churn-mlops-staging

# Fix
git revert HEAD
git push

# Verify sync
argocd app sync churn-mlops-staging
```

---

## Assessment Questions

### Question 1: Multiple Choice
What triggers ArgoCD to sync an application?

A) Manual sync only  
B) **Git commit detected (if auto-sync enabled)** ✅  
C) Every hour automatically  
D) When pods restart  

---

### Question 2: True/False
**Statement**: ArgoCD polls Git every 3 minutes by default.

**Answer**: True ✅  
**Explanation**: ArgoCD polls Git repositories every 3 minutes. Can be reduced with webhooks for instant sync.

---

### Question 3: Short Answer
How does CI/CD integrate with ArgoCD?

**Answer**:
1. CI builds Docker image, pushes to registry
2. CI updates image tag in Git manifests (values.yaml)
3. CI commits and pushes manifest change
4. ArgoCD detects Git change and syncs to cluster

---

### Question 4: Code Analysis
What's the deployment flow with this setup?

```yaml
syncPolicy:
  automated:
    prune: false
    selfHeal: false
```

**Answer**:
- **Auto-sync**: Enabled (new Git commits trigger sync)
- **Prune**: Disabled (resources removed from Git won't be deleted)
- **Self-heal**: Disabled (manual kubectl changes won't be reverted)
- **Result**: Semi-automated (syncs new changes, but requires manual cleanup/drift correction)

---

### Question 5: Design Challenge
Design complete GitOps workflow with rollback capability.

**Answer**:
```yaml
# 1. CI/CD Workflow
on:
  push:
    branches: [main]
jobs:
  deploy:
    steps:
      - name: Build
        run: docker build -t app:${{ github.sha }} .
      - name: Push
        run: docker push app:${{ github.sha }}
      - name: Update manifest
        run: |
          sed -i "s|tag:.*|tag: ${{ github.sha }}|" values.yaml
          git commit -am "deploy: ${{ github.sha }}"
          git push

# 2. ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    repoURL: https://github.com/user/repo
    targetRevision: main
  syncPolicy:
    automated: {}
  revisionHistoryLimit: 20  # Keep 20 revisions

# 3. Rollback
# Method A: Git revert
git revert HEAD && git push

# Method B: ArgoCD rollback
argocd app rollback app <revision>

# Method C: Update target
kubectl patch app app --patch '{"spec":{"source":{"targetRevision":"v1.2.2"}}}'
```

---

## Key Takeaways

### ✅ What You Learned

1. **End-to-End GitOps**
   - CI builds and pushes images
   - CI updates manifests in Git
   - ArgoCD syncs from Git
   - Kubernetes applies changes

2. **CI/CD Integration**
   - GitHub Actions updates manifests
   - ArgoCD Auth Token for API access
   - Webhooks for instant sync

3. **Multi-Environment**
   - Dev (develop branch, auto-deploy)
   - Staging (main branch, auto-deploy)
   - Production (tags, manual approval)

4. **Progressive Delivery**
   - Blue-green deployments
   - Canary releases
   - Gradual rollouts

5. **Rollback Strategies**
   - Git revert (preferred)
   - ArgoCD rollback (fast)
   - Update target revision (specific version)

6. **Monitoring**
   - ArgoCD UI dashboard
   - CLI commands
   - Logs and events
   - Drift detection

---

## Next Steps

**Module 7 Complete!** 🎉 You've finished GitOps.

Continue to **[Module 08: Monitoring and Observability](../../module-08-monitoring/)**

In the next module, we'll:
- Set up Prometheus for metrics
- Create Grafana dashboards
- Implement logging with Loki
- Configure alerts

---

## Additional Resources

- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Workflow Patterns](https://www.weave.works/technologies/gitops/)
- [Progressive Delivery](https://www.weave.works/blog/what-is-progressive-delivery-all-about)

---

**Progress**: 23/34 sections complete (68%) → **24/34 (71%)**

**Module 7 Summary**:
- ✅ Section 23: GitOps Principles (2 hours)
- ✅ Section 24: ArgoCD Setup (2.5 hours)
- ✅ Section 25: Automated Deployments (3 hours)

**Total Module 7**: 7.5 hours of content

Next: **Module 8: Monitoring** →
