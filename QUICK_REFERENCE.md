# 📋 Quick Reference Card

## Essential Commands

### ArgoCD

```bash
# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Login CLI
argocd login localhost:8080 --username admin --insecure

# List apps
argocd app list

# Sync app
argocd app sync churn-mlops-staging

# Get app status
argocd app get churn-mlops-production

# Rollback
argocd app rollback churn-mlops-production <REVISION>
```

### Kubernetes

```bash
# Check pods
kubectl get pods -n churn-mlops-staging
kubectl get pods -n churn-mlops-production

# View logs
kubectl logs -n churn-mlops-production -l app=churn-mlops-api -f

# Describe pod
kubectl describe pod <POD_NAME> -n churn-mlops-production

# Port forward API
kubectl port-forward -n churn-mlops-production svc/churn-mlops-api 8000:8000

# Check events
kubectl get events -n churn-mlops-production --sort-by='.lastTimestamp'

# Scale deployment
kubectl scale deployment churn-mlops-api --replicas=5 -n churn-mlops-production

# Restart deployment
kubectl rollout restart deployment/churn-mlops-api -n churn-mlops-production

# Check rollout status
kubectl rollout status deployment/churn-mlops-api -n churn-mlops-production
```

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/my-feature

# Commit changes
git add .
git commit -m "feat: add my feature"

# Push and create PR
git push origin feature/my-feature

# After merge, tag for production
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### Helm

```bash
# Install/upgrade staging
helm upgrade --install churn-mlops ./k8s/helm/churn-mlops \
  --namespace churn-mlops-staging \
  --create-namespace \
  --values k8s/helm/churn-mlops/values-staging.yaml

# Install/upgrade production
helm upgrade --install churn-mlops ./k8s/helm/churn-mlops \
  --namespace churn-mlops-production \
  --create-namespace \
  --values k8s/helm/churn-mlops/values-production.yaml

# List releases
helm list -A

# Get values
helm get values churn-mlops -n churn-mlops-production

# Rollback
helm rollback churn-mlops <REVISION> -n churn-mlops-production
```

### Docker

```bash
# Build ML image
docker build -f docker/Dockerfile.ml -t churn-mlops-ml:latest .

# Build API image
docker build -f docker/Dockerfile.api -t churn-mlops-api:latest .

# Run API locally
docker run -p 8000:8000 churn-mlops-api:latest

# Push to registry
docker tag churn-mlops-api:latest ghcr.io/yourorg/churn-mlops-prod-api:latest
docker push ghcr.io/yourorg/churn-mlops-prod-api:latest
```

### API Testing

```bash
# Health check
curl http://localhost:8000/health

# Predict
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test123", "features": {...}}'

# Metrics
curl http://localhost:8000/metrics
```

### Monitoring

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Top pods
kubectl top pods -n churn-mlops-production

# Top nodes
kubectl top nodes
```

## File Locations

| Component | Location |
|-----------|----------|
| CI Workflow | `.github/workflows/ci.yml` |
| CD Workflow | `.github/workflows/cd-build-push.yml` |
| Release Workflow | `.github/workflows/release.yml` |
| Staging ArgoCD | `argocd/staging/application.yaml` |
| Production ArgoCD | `argocd/production/application.yaml` |
| Helm Chart | `k8s/helm/churn-mlops/` |
| Staging Values | `k8s/helm/churn-mlops/values-staging.yaml` |
| Production Values | `k8s/helm/churn-mlops/values-production.yaml` |
| API Dockerfile | `docker/Dockerfile.api` |
| ML Dockerfile | `docker/Dockerfile.ml` |
| Setup Script | `scripts/setup_production.sh` |

## Troubleshooting

| Issue | Command |
|-------|---------|
| Pod not starting | `kubectl describe pod <POD> -n <NAMESPACE>` |
| Check logs | `kubectl logs <POD> -n <NAMESPACE>` |
| ArgoCD sync failed | `argocd app get <APP> --refresh` |
| Image pull error | Check imagePullSecrets, verify credentials |
| API not responding | Check service, ingress, and pod status |
| Out of sync | `argocd app sync <APP> --force` |

## Important URLs

| Service | Local URL | Production URL |
|---------|-----------|----------------|
| ArgoCD UI | https://localhost:8080 | https://argocd.example.com |
| API Staging | http://localhost:8000 | https://churn-api-staging.example.com |
| API Production | http://localhost:8000 | https://churn-api.example.com |
| Grafana | http://localhost:3000 | https://grafana.example.com |
| Prometheus | http://localhost:9090 | https://prometheus.example.com |

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `CHURN_MLOPS_CONFIG` | Config file path | `/app/config/config.yaml` |
| `LOG_LEVEL` | Logging level | `INFO`, `DEBUG` |
| `ENVIRONMENT` | Environment name | `staging`, `production` |

## Resource Limits

| Environment | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-------------|-------------|-----------|----------------|--------------|
| Staging API | 250m | 500m | 256Mi | 512Mi |
| Production API | 1000m | 2000m | 1Gi | 2Gi |
| ML Jobs | 1000m | 4000m | 2Gi | 8Gi |

## Sync Schedule (Production)

| Job | Schedule | Description |
|-----|----------|-------------|
| Batch Score | `0 2 * * *` | Daily at 2 AM |
| Retrain | `0 3 * * 0` | Weekly Sunday at 3 AM |
| Drift Monitor | `0 */6 * * *` | Every 6 hours |

## Quick Links

- [Full Deployment Guide](docs/PRODUCTION_DEPLOYMENT.md)
- [GitOps Workflow](docs/GITOPS_WORKFLOW.md)
- [ArgoCD Docs](argocd/README.md)
- [Security Policy](SECURITY.md)
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md)

## Emergency Contacts

- **On-call Engineer**: [Your PagerDuty/On-call system]
- **Slack Channel**: #churn-mlops-alerts
- **Email**: support@techitfactory.com

---

**Print this card and keep it handy! 📌**
