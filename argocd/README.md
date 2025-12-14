# ArgoCD GitOps Configuration

This directory contains ArgoCD Application manifests for GitOps-based deployment of the Churn MLOps platform.

## Structure

```
argocd/
├── appproject.yaml           # ArgoCD AppProject for RBAC and policies
├── staging/
│   └── application.yaml      # Staging environment application
└── production/
    └── application.yaml      # Production environment application
```

## Prerequisites

1. **ArgoCD installed** in your Kubernetes cluster:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. **ArgoCD CLI** (optional but recommended):
   ```bash
   # macOS
   brew install argocd
   
   # Linux
   curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
   sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
   ```

3. **Access ArgoCD UI**:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   
   # Get initial admin password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

## Deployment

### 1. Create AppProject

```bash
kubectl apply -f argocd/appproject.yaml
```

### 2. Deploy Staging Environment

```bash
kubectl apply -f argocd/staging/application.yaml
```

Check status:
```bash
argocd app get churn-mlops-staging
argocd app sync churn-mlops-staging
```

### 3. Deploy Production Environment

```bash
kubectl apply -f argocd/production/application.yaml
```

Check status:
```bash
argocd app get churn-mlops-production
argocd app sync churn-mlops-production
```

## Configuration

### Update Repository URL

Before deploying, update the `repoURL` in all application manifests:

```bash
# In staging/application.yaml and production/application.yaml
sed -i 's|yourusername|YOUR_GITHUB_USERNAME|g' argocd/*/application.yaml
```

### Update Image Tags

Image tags are automatically updated by the CI/CD pipeline, but you can manually override:

```bash
argocd app set churn-mlops-staging -p image.tag=v1.2.3
```

## Sync Policies

### Staging
- **Automated sync**: Enabled
- **Auto-prune**: Enabled
- **Self-heal**: Enabled

Staging automatically deploys changes from the `main` branch.

### Production
- **Automated sync**: Enabled
- **Auto-prune**: Disabled (manual approval required)
- **Self-heal**: Enabled
- **Sync windows**: Deployments blocked during 22:00-06:00 UTC

## Monitoring

### Check Application Health

```bash
# Get application status
argocd app get churn-mlops-production

# List all applications
argocd app list

# View sync history
argocd app history churn-mlops-production
```

### View Logs

```bash
argocd app logs churn-mlops-production
```

## Rollback

### Using ArgoCD CLI

```bash
# List history
argocd app history churn-mlops-production

# Rollback to specific revision
argocd app rollback churn-mlops-production <REVISION>
```

### Using kubectl

```bash
# Get previous revisions
kubectl get applications.argoproj.io churn-mlops-production -n argocd -o yaml

# Edit and change targetRevision
kubectl edit applications.argoproj.io churn-mlops-production -n argocd
```

## Notifications

ArgoCD can send notifications to Slack, email, or other channels.

### Setup Slack Notifications

1. Create a Slack webhook
2. Configure ArgoCD notifications:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  subscriptions: |
    - recipients:
      - slack:churn-mlops-alerts
      triggers:
      - on-sync-succeeded
      - on-sync-failed
      - on-health-degraded
EOF
```

## Troubleshooting

### Application Not Syncing

```bash
# Check application details
argocd app get churn-mlops-production

# View events
kubectl get events -n churn-mlops-production

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Sync Failures

```bash
# Force sync
argocd app sync churn-mlops-production --force

# Sync with prune
argocd app sync churn-mlops-production --prune
```

### Permission Issues

Check RBAC:
```bash
kubectl get appproject production -n argocd -o yaml
```

## Best Practices

1. **Never commit secrets** to Git. Use sealed-secrets or external secret managers.
2. **Test in staging** before promoting to production.
3. **Use semantic versioning** for production tags (v1.2.3).
4. **Monitor sync status** regularly.
5. **Review diffs** before syncing critical changes.
6. **Use sync windows** to prevent deployments during business hours.

## Integration with CI/CD

The GitHub Actions workflows automatically:
1. Build and push Docker images
2. Update image tags in Helm values files
3. Commit changes to trigger ArgoCD sync

See `.github/workflows/cd-build-push.yml` for details.

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Best Practices](https://www.gitops.tech/)
- [Helm Documentation](https://helm.sh/docs/)
