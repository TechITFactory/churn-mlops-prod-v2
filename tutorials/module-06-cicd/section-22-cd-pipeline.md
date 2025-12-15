# Section 22: CD Pipeline - Docker Push & Deployment

**Duration**: 3 hours  
**Level**: Advanced  
**Prerequisites**: Sections 20-21 (GitHub Actions, CI Pipeline)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Build continuous deployment pipeline
- ✅ Push Docker images to container registry
- ✅ Implement semantic versioning
- ✅ Create release workflows
- ✅ Update GitOps manifests automatically
- ✅ Deploy to multiple environments
- ✅ Implement rollback strategies

---

## 📚 Table of Contents

1. [CD Pipeline Overview](#cd-pipeline-overview)
2. [Container Registry](#container-registry)
3. [Building and Pushing Images](#building-and-pushing-images)
4. [Semantic Versioning](#semantic-versioning)
5. [Release Workflow](#release-workflow)
6. [GitOps Integration](#gitops-integration)
7. [Multi-Environment Deployment](#multi-environment-deployment)
8. [Code Walkthrough](#code-walkthrough)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## CD Pipeline Overview

### What is Continuous Deployment?

> **CD**: Automatically deploy code to production after passing CI

```
CI/CD Flow:

Developer
  ↓ git push
GitHub
  ↓ trigger
CI Pipeline (Section 21)
  ├── Lint ✅
  ├── Test ✅
  ├── Security ✅
  └── Build ✅
  ↓ all pass
CD Pipeline (This Section)
  ├── Build Docker images
  ├── Push to registry
  ├── Update manifests
  └── Deploy to K8s
  ↓
Production 🚀
```

### CD vs CD (Delivery vs Deployment)

| Continuous Delivery | Continuous Deployment |
|---------------------|----------------------|
| **Manual** approval to production | **Automatic** deployment |
| Human clicks "Deploy" button | No human intervention |
| Safer (control) | Faster (automation) |
| Common for enterprises | Common for SaaS |

**This Tutorial**: Continuous Delivery (manual production approval)

### Environment Promotion

```
┌──────────────────────────────────────────────────┐
│                                                   │
│  Develop Branch                                  │
│    ↓ merge                                       │
│  Main Branch                                      │
│    ↓ CI passes                                   │
│  Staging Environment (auto-deploy)              │
│    ↓ testing + approval                         │
│  Production Environment (manual deploy)         │
│                                                   │
└──────────────────────────────────────────────────┘
```

---

## Container Registry

### What is a Container Registry?

> **Registry**: Storage for Docker images (like Docker Hub, but can be private)

```
Docker Hub (public):
  docker.io/techitfactory/churn-api:v1.0

GitHub Container Registry (ghcr.io):
  ghcr.io/username/churn-mlops-api:v1.0

Amazon ECR:
  123456789.dkr.ecr.us-east-1.amazonaws.com/churn-api:v1.0

Google Container Registry:
  gcr.io/project-id/churn-api:v1.0
```

### GitHub Container Registry (GHCR)

**Benefits**:
- ✅ **Free** for public repos
- ✅ **Integrated** with GitHub Actions
- ✅ **Private** registries available
- ✅ **Automatic** authentication

**Registry URL**:
```
ghcr.io/OWNER/IMAGE_NAME:TAG

Example:
ghcr.io/techitfactory/churn-mlops-ml:v1.0.0
ghcr.io/techitfactory/churn-mlops-api:v1.0.0
```

### Authentication

**GitHub Actions** (automatic):
```yaml
- name: Log in to GHCR
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}  # Auto-provided
```

**Local** (manual):
```bash
# Create personal access token (PAT)
# Settings → Developer settings → Personal access tokens
# Scopes: write:packages, read:packages

# Login
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Pull image
docker pull ghcr.io/username/churn-mlops-api:v1.0.0
```

---

## Building and Pushing Images

### Multi-Platform Builds

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: .
    file: docker/Dockerfile.api
    push: true
    tags: ghcr.io/${{ github.repository }}-api:latest
    platforms: linux/amd64,linux/arm64  # Multi-platform
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

**Why multi-platform?**
- **amd64**: Intel/AMD processors (most servers)
- **arm64**: Apple Silicon M1/M2, AWS Graviton

### Image Tags

**Tagging Strategy**:
```yaml
tags: |
  ghcr.io/${{ github.repository }}-api:latest
  ghcr.io/${{ github.repository }}-api:v1.0.0
  ghcr.io/${{ github.repository }}-api:v1.0
  ghcr.io/${{ github.repository }}-api:v1
  ghcr.io/${{ github.repository }}-api:sha-abc1234
```

**Explanation**:
| Tag | Purpose | Example |
|-----|---------|---------|
| `latest` | Always newest | `:latest` |
| `v1.0.0` | Exact version | `:v1.0.0` |
| `v1.0` | Minor version | `:v1.0` (can update) |
| `v1` | Major version | `:v1` (can update) |
| `sha-abc1234` | Git commit | `:sha-abc1234` |

### Complete Build Job

```yaml
jobs:
  build-and-push:
    name: Build and Push Docker Images
    runs-on: ubuntu-latest
    
    permissions:
      contents: read
      packages: write  # Required for GHCR
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata for ML image
        id: meta-ml
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}-ml
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push ML image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile.ml
          push: true
          tags: ${{ steps.meta-ml.outputs.tags }}
          labels: ${{ steps.meta-ml.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64
          build-args: |
            BUILD_DATE=${{ github.event.head_commit.timestamp }}
            VCS_REF=${{ github.sha }}

      - name: Extract metadata for API image
        id: meta-api
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}-api
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push API image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile.api
          push: true
          tags: ${{ steps.meta-api.outputs.tags }}
          labels: ${{ steps.meta-api.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64
```

---

## Semantic Versioning

### SemVer Format

```
v MAJOR . MINOR . PATCH

v 1 . 2 . 3
  │   │    │
  │   │    └─ Bug fixes (backwards compatible)
  │   └────── New features (backwards compatible)
  └────────── Breaking changes

Examples:
v0.1.0  → Initial development
v1.0.0  → First stable release
v1.1.0  → Added new feature
v1.1.1  → Fixed bug
v2.0.0  → Breaking change (new API)
```

### When to Bump Version?

| Change | Version | Example |
|--------|---------|---------|
| **Bug fix** | Patch (x.x.X) | v1.0.0 → v1.0.1 |
| **New feature** | Minor (x.X.x) | v1.0.1 → v1.1.0 |
| **Breaking change** | Major (X.x.x) | v1.1.0 → v2.0.0 |

**MLOps Examples**:
```
v1.0.0 → v1.0.1: Fixed prediction bug
v1.0.1 → v1.1.0: Added new model algorithm
v1.1.0 → v2.0.0: Changed API response format (breaking)
```

### Creating Releases

**Tag and Push**:
```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0"

# Push tag
git push origin v1.0.0
```

**GitHub UI**:
1. Go to **Releases** → **Create new release**
2. Choose tag: `v1.0.0` (create new)
3. Title: `v1.0.0 - Initial Release`
4. Description: Changelog
5. Click **Publish release**

---

## Release Workflow

### Automated Release Creation

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'  # Trigger on version tags

permissions:
  contents: write  # Create releases
  packages: write  # Push images

jobs:
  create-release:
    name: Create GitHub Release
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Get full history for changelog

      - name: Generate changelog
        id: changelog
        run: |
          # Get previous tag
          PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
          
          if [ -z "$PREV_TAG" ]; then
            echo "First release"
            CHANGELOG=$(git log --pretty=format:"- %s (%h)" --no-merges)
          else
            echo "Changes since $PREV_TAG"
            CHANGELOG=$(git log ${PREV_TAG}..HEAD --pretty=format:"- %s (%h)" --no-merges)
          fi
          
          # Write changelog
          echo "$CHANGELOG" > changelog.txt
          
          # Set output
          echo "changelog<<EOF" >> $GITHUB_OUTPUT
          echo "$CHANGELOG" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          body: |
            ## Changes
            
            ${{ steps.changelog.outputs.changelog }}
            
            ## Docker Images
            
            - ML Image: `ghcr.io/${{ github.repository }}-ml:${{ github.ref_name }}`
            - API Image: `ghcr.io/${{ github.repository }}-api:${{ github.ref_name }}`
            
            ## Installation
            
            ```bash
            # Pull images
            docker pull ghcr.io/${{ github.repository }}-ml:${{ github.ref_name }}
            docker pull ghcr.io/${{ github.repository }}-api:${{ github.ref_name }}
            
            # Deploy with Helm
            helm upgrade --install churn-mlops ./k8s/helm/churn-mlops \
              --namespace churn-mlops \
              --create-namespace \
              --set image.tag=${{ github.ref_name }}
            ```
          draft: false
          prerelease: ${{ contains(github.ref, 'alpha') || contains(github.ref, 'beta') || contains(github.ref, 'rc') }}
          generate_release_notes: true
```

**Result**: Automatic release page with:
- Changelog
- Docker image URLs
- Installation instructions

---

## GitOps Integration

### What is GitOps?

> **GitOps**: Git as single source of truth for infrastructure

```
Traditional Deployment:
Developer → kubectl apply → Kubernetes

GitOps:
Developer → git push → GitHub → ArgoCD → Kubernetes
                          ↑
                    Single source of truth
```

### Updating Manifests

**After building images, update Helm values**:
```yaml
jobs:
  update-gitops-manifests:
    name: Update GitOps Manifests
    needs: build-and-push
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Update image tags in Helm values
        run: |
          # Determine environment
          if [[ "${{ github.ref }}" == refs/tags/v* ]]; then
            ENV="production"
            TAG="${GITHUB_REF#refs/tags/}"
          else
            ENV="staging"
            TAG="${GITHUB_SHA::8}"
          fi
          
          # Update values file
          VALUES_FILE="k8s/helm/churn-mlops/values-${ENV}.yaml"
          
          if [ -f "$VALUES_FILE" ]; then
            sed -i "s|tag:.*|tag: \"${TAG}\"|g" "$VALUES_FILE"
            echo "Updated $VALUES_FILE with tag: $TAG"
          fi

      - name: Commit and push changes
        run: |
          git config --local user.email "github-actions[bot]@users.noreply.github.com"
          git config --local user.name "github-actions[bot]"
          
          if git diff --quiet; then
            echo "No changes to commit"
          else
            git add k8s/helm/churn-mlops/values-*.yaml
            git commit -m "chore: update image tags to ${{ github.sha }}"
            git push
          fi
```

**Before**:
```yaml
# k8s/helm/churn-mlops/values-staging.yaml
image:
  tag: "v0.9.0"
```

**After** (automated update):
```yaml
# k8s/helm/churn-mlops/values-staging.yaml
image:
  tag: "v1.0.0"
```

---

## Multi-Environment Deployment

### Environment Strategy

```
┌─────────────────────────────────────────────┐
│  Environments                                │
├─────────────────────────────────────────────┤
│                                              │
│  Development (local)                        │
│  - docker-compose up                        │
│  - Local K8s (minikube)                     │
│                                              │
│  Staging (auto-deploy)                      │
│  - Branch: main                             │
│  - K8s namespace: churn-mlops-staging       │
│  - URL: staging.churn-api.com               │
│                                              │
│  Production (manual)                        │
│  - Tag: v*.*.*                              │
│  - K8s namespace: churn-mlops-prod          │
│  - URL: api.churn.com                       │
│                                              │
└─────────────────────────────────────────────┘
```

### Workflow Dispatch for Manual Deploy

```yaml
# .github/workflows/deploy.yml
name: Deploy to Environment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - staging
          - production
      image_tag:
        description: 'Docker image tag'
        required: true
        default: 'latest'

jobs:
  deploy:
    name: Deploy to ${{ inputs.environment }}
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}  # GitHub Environment
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'v1.28.0'

      - name: Configure kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG }}" > ~/.kube/config

      - name: Deploy with Helm
        run: |
          helm upgrade --install churn-mlops \
            ./k8s/helm/churn-mlops \
            --namespace churn-mlops-${{ inputs.environment }} \
            --create-namespace \
            --values k8s/helm/churn-mlops/values-${{ inputs.environment }}.yaml \
            --set image.tag=${{ inputs.image_tag }} \
            --wait \
            --timeout 5m

      - name: Verify deployment
        run: |
          kubectl rollout status deployment/churn-api \
            -n churn-mlops-${{ inputs.environment }} \
            --timeout=5m
```

**Trigger**:
1. Go to **Actions** → **Deploy to Environment**
2. Click **Run workflow**
3. Select environment: `production`
4. Enter image tag: `v1.0.0`
5. Click **Run workflow**

### GitHub Environments

**Settings → Environments → New environment**

```
Name: production

Protection rules:
✅ Required reviewers: 1
  - Select team or users

✅ Wait timer: 0 minutes

Environment secrets:
- KUBECONFIG (production cluster)
- SLACK_WEBHOOK_URL
```

**Benefits**:
- Manual approval before production
- Environment-specific secrets
- Deployment history

---

## Code Walkthrough

### Complete CD Workflow

```yaml
# .github/workflows/cd-build-push.yml
name: CD - Build & Push Docker Images

on:
  push:
    branches:
      - main
    tags:
      - 'v*.*.*'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

env:
  REGISTRY: ghcr.io
  IMAGE_NAME_ML: ${{ github.repository }}-ml
  IMAGE_NAME_API: ${{ github.repository }}-api

jobs:
  # ============================================
  # Job 1: Build and Push Images
  # ============================================
  build-and-push:
    name: Build and Push Docker Images
    runs-on: ubuntu-latest
    
    permissions:
      contents: read
      packages: write
      id-token: write
    
    outputs:
      ml-tags: ${{ steps.meta-ml.outputs.tags }}
      api-tags: ${{ steps.meta-api.outputs.tags }}
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata for ML image
        id: meta-ml
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_ML }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push ML image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile.ml
          push: true
          tags: ${{ steps.meta-ml.outputs.tags }}
          labels: ${{ steps.meta-ml.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64
          build-args: |
            BUILD_DATE=${{ github.event.head_commit.timestamp }}
            VCS_REF=${{ github.sha }}

      - name: Extract metadata for API image
        id: meta-api
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_API }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push API image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile.api
          push: true
          tags: ${{ steps.meta-api.outputs.tags }}
          labels: ${{ steps.meta-api.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_API }}:${{ github.sha }}
          format: spdx-json
          output-file: sbom-api.spdx.json

      - name: Scan for vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_API }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
        continue-on-error: true

  # ============================================
  # Job 2: Update GitOps Manifests
  # ============================================
  update-gitops-manifests:
    name: Update GitOps Manifests
    needs: build-and-push
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v')
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Update image tags
        run: |
          if [[ "${{ github.ref }}" == refs/tags/v* ]]; then
            ENV="production"
            TAG="${GITHUB_REF#refs/tags/}"
          else
            ENV="staging"
            TAG="${GITHUB_SHA::8}"
          fi
          
          VALUES_FILE="k8s/helm/churn-mlops/values-${ENV}.yaml"
          
          if [ -f "$VALUES_FILE" ]; then
            sed -i "s|tag:.*|tag: \"${TAG}\"|g" "$VALUES_FILE"
            echo "Updated $VALUES_FILE with tag: $TAG"
          fi

      - name: Commit and push
        run: |
          git config --local user.email "github-actions[bot]@users.noreply.github.com"
          git config --local user.name "github-actions[bot]"
          
          if ! git diff --quiet; then
            git add k8s/helm/churn-mlops/values-*.yaml
            git commit -m "chore: update image tags to ${{ github.sha }}"
            git push
          fi
```

---

## Hands-On Exercise

### Exercise 1: Create CD Workflow

Create `.github/workflows/cd.yml`:
```yaml
name: CD

on:
  push:
    branches: [main]
    tags: ['v*.*.*']

env:
  REGISTRY: ghcr.io

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile.api
          push: true
          tags: ghcr.io/${{ github.repository }}-api:latest
```

### Exercise 2: Test Image Push

```bash
# Create and push
git checkout -b feature/cd-workflow
git add .github/workflows/cd.yml
git commit -m "Add CD workflow"
git push origin feature/cd-workflow

# Merge to main (triggers workflow)
# Check: https://github.com/USERNAME/REPO/pkgs/container/REPO-api
```

### Exercise 3: Create Release

```bash
# Tag release
git checkout main
git pull
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Check:
# - Actions tab (workflow running)
# - Releases tab (release created)
# - Packages tab (images with v1.0.0 tag)
```

### Exercise 4: Manual Deployment

Create `.github/workflows/deploy-manual.yml`:
```yaml
name: Manual Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment'
        required: true
        type: choice
        options: [staging, production]
      image_tag:
        description: 'Image tag'
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: |
          echo "Deploying ${{ inputs.image_tag }} to ${{ inputs.environment }}"
          # helm upgrade --install ...
```

### Exercise 5: Setup GitHub Environment

1. **Settings** → **Environments** → **New environment**
2. Name: `production`
3. **Required reviewers**: Add yourself
4. **Secrets**: Add `KUBECONFIG` (if deploying to K8s)
5. Save

Test: Trigger manual deploy workflow, see approval request

---

## Assessment Questions

### Question 1: Multiple Choice
What's the purpose of `docker/metadata-action`?

A) Build Docker images  
B) **Generate image tags and labels automatically** ✅  
C) Push images to registry  
D) Scan for vulnerabilities  

---

### Question 2: True/False
**Statement**: `type=semver,pattern={{version}}` creates tags like `v1.0.0`.

**Answer**: True ✅  
**Explanation**: Semver pattern extracts version from git tags (e.g., `v1.0.0` → tag `v1.0.0`).

---

### Question 3: Short Answer
What's the difference between `latest` and version tags?

**Answer**:
- **`latest`**: Always points to newest image. Mutable (changes). Not recommended for production.
- **Version tags** (e.g., `v1.0.0`): Immutable (fixed). Reproducible deployments. Production-safe.

---

### Question 4: Code Analysis
Why is this workflow problematic?

```yaml
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: kubectl apply -f k8s/
```

**Answer**:
- **No build step**: Not building images first
- **No authentication**: kubectl not authenticated
- **No validation**: Not checking if deployment succeeded
- **No rollback**: If fails, production broken
- **Better**: Build → Push → Update manifests → Let ArgoCD deploy

---

### Question 5: Design Challenge
Design CD pipeline that:
- Builds images on main branch
- Pushes to staging automatically
- Requires approval for production

**Answer**:
```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [staging, production]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/repo/app:${{ github.sha }}
  
  deploy-staging:
    needs: build
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - run: helm upgrade churn-mlops --set image.tag=${{ github.sha }}
  
  deploy-production:
    needs: build
    if: inputs.environment == 'production'
    environment: production  # Requires approval
    runs-on: ubuntu-latest
    steps:
      - run: helm upgrade churn-mlops --set image.tag=${{ github.sha }}
```

---

## Key Takeaways

### ✅ What You Learned

1. **CD Pipeline**
   - Build Docker images
   - Push to container registry (GHCR)
   - Automate deployments

2. **Container Registry**
   - GitHub Container Registry (ghcr.io)
   - Authentication with GITHUB_TOKEN
   - Multi-platform builds

3. **Semantic Versioning**
   - Major.Minor.Patch (v1.2.3)
   - Automated tag generation
   - Release workflows

4. **GitOps**
   - Git as source of truth
   - Update manifests automatically
   - ArgoCD integration

5. **Multi-Environment**
   - Staging (auto-deploy)
   - Production (manual approval)
   - GitHub Environments

---

## Next Steps

**Module 6 Complete!** 🎉 You've finished CI/CD.

Continue to **[Module 07: GitOps with ArgoCD](../../module-07-gitops/)**

In the next module, we'll:
- Set up ArgoCD
- Implement GitOps workflows
- Automate K8s deployments
- Handle rollbacks

---

## Additional Resources

- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Semantic Versioning](https://semver.org/)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)

---

**Progress**: 20/34 sections complete (59%) → **21/34 (62%)**

**Module 6 Summary**:
- ✅ Section 20: GitHub Actions Fundamentals (2.5 hours)
- ✅ Section 21: CI Pipeline (3 hours)
- ✅ Section 22: CD Pipeline (3 hours)

**Total Module 6**: 8.5 hours of content

Next: **Module 7: GitOps** →
