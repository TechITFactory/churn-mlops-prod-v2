# GitOps Workflow

This document describes the complete GitOps workflow for the Churn MLOps platform.

## Overview

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│             │     │              │     │             │     │              │
│  Developer  │────▶│  GitHub PR   │────▶│   GitHub    │────▶│   ArgoCD     │
│             │     │   (CI)       │     │   Actions   │     │   (Sync)     │
│             │     │              │     │   (CD)      │     │              │
└─────────────┘     └──────────────┘     └─────────────┘     └──────────────┘
                            │                    │                    │
                            ▼                    ▼                    ▼
                     ┌──────────────┐   ┌─────────────┐    ┌──────────────┐
                     │   Lint/Test  │   │    Build    │    │  Kubernetes  │
                     │   Security   │   │    Push     │    │   Cluster    │
                     └──────────────┘   └─────────────┘    └──────────────┘
```

## Workflow Steps

### 1. Development Phase

#### Create Feature Branch

```bash
# Start from main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/improve-churn-model

# Make changes
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: improve churn prediction model accuracy"
```

#### Push and Create PR

```bash
git push origin feature/improve-churn-model
```

Create Pull Request on GitHub targeting `main` branch.

### 2. Continuous Integration (CI)

When PR is created, GitHub Actions automatically runs:

#### Lint & Format Check
- Ruff linting
- Black formatting
- Type checking (mypy)

#### Unit Tests
- pytest with coverage
- Upload coverage reports

#### Security Scanning
- Dependency scanning (Safety)
- Code security (Bandit)
- SAST analysis

#### Build Validation
- Docker image builds (without push)
- Multi-stage build validation

**Workflow File**: `.github/workflows/ci.yml`

### 3. Code Review

Team reviews:
- Code quality
- Test coverage
- Security findings
- Architecture decisions

### 4. Merge to Main

When PR is approved and merged:

#### Continuous Deployment (CD) Triggers

**Workflow File**: `.github/workflows/cd-build-push.yml`

1. **Build Docker Images**
   - Multi-stage builds for ML and API
   - Layer caching for faster builds
   - Security scanning with Trivy

2. **Tag Images**
   - `main`: Latest tag
   - `SHA-based`: `main-abc1234`
   - `Branch`: `main`

3. **Push to Registry**
   - GitHub Container Registry (ghcr.io)
   - Automated authentication
   - SBOM generation

4. **Update GitOps Manifests**
   - Update Helm values with new image tags
   - Commit changes back to repository
   - Trigger ArgoCD sync

### 5. ArgoCD Sync (Staging)

#### Automatic Deployment

ArgoCD monitors the repository and automatically:

1. **Detect Changes**
   - Poll repository every 3 minutes
   - Webhook for instant updates (optional)

2. **Compare Manifests**
   - Git state vs. Cluster state
   - Generate diff

3. **Sync Application**
   - Apply Kubernetes manifests
   - Rolling update deployment
   - Health checks

4. **Self-Heal**
   - Automatically fix drift
   - Restore desired state

**ArgoCD Application**: `argocd/staging/application.yaml`

#### Monitoring Staging

```bash
# Watch ArgoCD sync
argocd app get churn-mlops-staging --watch

# Watch Kubernetes deployment
kubectl rollout status deployment/churn-mlops-api -n churn-mlops-staging -w

# Check application health
kubectl get pods -n churn-mlops-staging
```

### 6. Validation & Testing

#### Automated Tests

Run integration tests against staging:

```bash
# API health check
curl https://churn-api-staging.example.com/health

# Smoke tests
pytest tests/test_api_smoke.py --env=staging

# Load tests (optional)
k6 run tests/load-test.js
```

#### Manual Validation

- Check metrics in Grafana
- Review logs in Kibana/Loki
- Test critical user flows
- Verify data pipelines

### 7. Production Release

#### Create Release Tag

When staging is validated:

```bash
# Create and push version tag
git tag -a v1.2.3 -m "Release v1.2.3: Improved model accuracy"
git push origin v1.2.3
```

#### Release Workflow Triggers

**Workflow File**: `.github/workflows/release.yml`

1. **Build Production Images**
   - Same build process as CD
   - Tagged with version (v1.2.3)

2. **Create GitHub Release**
   - Generate changelog
   - Attach artifacts
   - Document breaking changes

3. **Update Production Values**
   - Update `values-production.yaml`
   - Set image tag to version

#### ArgoCD Sync (Production)

**ArgoCD Application**: `argocd/production/application.yaml`

Production sync is:
- **Automated**: Yes (with sync windows)
- **Auto-prune**: No (manual approval)
- **Self-heal**: Yes
- **Sync windows**: Deployments blocked during business hours

```bash
# Review production changes
argocd app diff churn-mlops-production

# Sync to production
argocd app sync churn-mlops-production

# Monitor deployment
argocd app get churn-mlops-production --watch
```

### 8. Post-Deployment

#### Monitoring

- Check Prometheus metrics
- Review Grafana dashboards
- Monitor error rates
- Validate SLOs

#### Notifications

ArgoCD sends notifications on:
- Successful deployment
- Failed deployment
- Health degradation

Channels:
- Slack: `#churn-mlops-alerts`
- Email: DevOps team
- PagerDuty: On-call engineer

#### Documentation

Update:
- Release notes
- Runbook
- Known issues
- Breaking changes

## Rollback Procedures

### Quick Rollback (ArgoCD)

```bash
# Rollback to previous version
argocd app rollback churn-mlops-production

# Rollback to specific revision
argocd app rollback churn-mlops-production 42
```

### Git Revert

```bash
# Revert the commit that caused issues
git revert <commit-hash>
git push origin main

# ArgoCD will auto-sync the revert
```

### Manual Intervention

```bash
# Scale down problematic deployment
kubectl scale deployment churn-mlops-api --replicas=0 -n churn-mlops-production

# Investigate and fix

# Scale back up
kubectl scale deployment churn-mlops-api --replicas=3 -n churn-mlops-production
```

## Branch Strategy

### Main Branch (`main`)

- Protected branch
- Requires PR approval
- Triggers staging deployment
- Production-ready code only

### Feature Branches

- `feature/*`: New features
- `bugfix/*`: Bug fixes
- `hotfix/*`: Critical fixes
- `experiment/*`: Experimental changes

### Tag Strategy

- `v*.*.*`: Production releases (semantic versioning)
  - `v1.0.0`: Major release
  - `v1.1.0`: Minor release
  - `v1.1.1`: Patch release
- `v*.*.*-rc*`: Release candidates
- `v*.*.*-beta*`: Beta releases

## Environment Promotion

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│             │       │             │       │             │
│   Develop   │──────▶│   Staging   │──────▶│ Production  │
│  (feature)  │       │    (main)   │       │  (v*.*.*)   │
│             │       │             │       │             │
└─────────────┘       └─────────────┘       └─────────────┘
      │                     │                      │
      ▼                     ▼                      ▼
  Auto-deploy          Auto-deploy          Manual approval
   On commit            On merge            On tag creation
```

## Disaster Recovery

### Backup Strategy

1. **Persistent Volumes**: Daily snapshots
2. **Git Repository**: Version controlled
3. **Container Registry**: Immutable tags
4. **ArgoCD State**: Backup via `kubectl`

### Recovery Procedure

```bash
# 1. Restore Git to last known good state
git checkout v1.2.2
git push origin main --force

# 2. Sync ArgoCD
argocd app sync churn-mlops-production --force

# 3. Restore data from backup
kubectl apply -f backup/pvc-snapshot.yaml
```

## Security Considerations

### Image Scanning

Every image is scanned for:
- CVEs (Common Vulnerabilities)
- Malware
- Secrets
- License compliance

Tools:
- Trivy (vulnerability scanning)
- Anchore (SBOM generation)
- Snyk (dependency checking)

### Secret Management

**Never commit secrets to Git**

Options:
1. **Sealed Secrets**: Encrypt secrets for Git
2. **External Secrets Operator**: Sync from vault
3. **Kubernetes Secrets**: Manual creation

```bash
# Create secret
kubectl create secret generic api-secrets \
  --from-literal=api-key=<value> \
  -n churn-mlops-production

# Reference in deployment
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: api-secrets
        key: api-key
```

### RBAC

ArgoCD AppProject defines:
- Who can deploy
- Where they can deploy
- When they can deploy

See `argocd/appproject.yaml` for details.

## Monitoring & Observability

### Metrics

- **Deployment frequency**: How often we deploy
- **Lead time**: Code commit to production
- **MTTR**: Mean time to recovery
- **Change failure rate**: % of deployments causing issues

### Dashboards

1. **ArgoCD Dashboard**: Application sync status
2. **Kubernetes Dashboard**: Cluster health
3. **Grafana**: Application metrics
4. **Prometheus**: System metrics

### Alerts

Configure alerts for:
- Deployment failures
- High error rates
- Resource exhaustion
- Security vulnerabilities

## Best Practices

### Development

1. ✅ Write tests for all changes
2. ✅ Keep commits atomic and well-described
3. ✅ Run linting locally before pushing
4. ✅ Update documentation with code changes
5. ✅ Review security scan results

### Deployment

1. ✅ Always deploy to staging first
2. ✅ Validate in staging before production
3. ✅ Use semantic versioning for releases
4. ✅ Document breaking changes
5. ✅ Monitor after deployment

### Operations

1. ✅ Regular backup testing
2. ✅ Periodic security audits
3. ✅ Keep dependencies updated
4. ✅ Review and rotate credentials
5. ✅ Document incidents and resolutions

## Troubleshooting

### Common Issues

#### ArgoCD Out of Sync

```bash
# Hard refresh
argocd app get churn-mlops-production --hard-refresh

# Force sync
argocd app sync churn-mlops-production --force --prune
```

#### Image Not Updating

```bash
# Check image tag in values
cat k8s/helm/churn-mlops/values-production.yaml | grep tag

# Verify image exists
docker pull ghcr.io/yourorg/churn-mlops-prod-api:v1.2.3

# Force pod restart
kubectl rollout restart deployment/churn-mlops-api -n churn-mlops-production
```

#### Pipeline Failure

```bash
# Check GitHub Actions logs
# Go to: https://github.com/yourorg/repo/actions

# Re-run failed job
# Click "Re-run jobs" in GitHub UI

# Or trigger manually
gh workflow run cd-build-push.yml
```

## Additional Resources

- [GitOps Principles](https://www.gitops.tech/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Kubernetes GitOps](https://kubernetes.io/blog/2021/04/13/kubernetes-gitops/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
