# Tutorial Sections - Complete Index

This document provides a detailed outline of all 34 sections. Each section follows the same comprehensive structure as Sections 01 and 02.

---

## ✅ Completed Sections

### Module 1: Foundation & Setup
- ✅ **Section 01**: Introduction to MLOps (COMPLETED - 2h content)
- ✅ **Section 02**: Project Setup & Environment (COMPLETED - 1.5h content)
- ⏳ **Section 03**: Understanding the Business Problem (Ready to create)

---

## 📋 Sections to Create

### Module 1: Foundation & Setup (1 remaining)

#### Section 03: Understanding the Business Problem
**File**: `module-01-foundation/section-03-business-problem.md`
**Content outline**:
- What is churn in e-learning?
- Business impact ($500K/year loss)
- User lifecycle stages
- Churn patterns and signals
- Success metrics (precision, recall, F1)
- Business vs ML metrics
- ROI calculation
- Intervention strategies
- **Code**: Analysis of churn rates in synthetic data
- **Exercise**: Calculate churn rate from data
- **Assessment**: Business metrics vs ML metrics

---

### Module 2: Data Engineering (4 sections)

#### Section 04: Data Architecture & Design  
**File**: `module-02-data/section-04-data-architecture.md`
**Content outline**:
- E-learning data model (users, events, subscriptions)
- Entity-relationship diagrams
- Time-series data design
- Synthetic data generation explained
- **Code walkthrough**: `src/churn_mlops/data/generate_synthetic.py`
  - User generation (demographics, signup patterns)
  - Event generation (courses, watch time, engagement)
  - Realistic behavior simulation
- Schema design principles
- Data versioning strategies
- **Exercise**: Generate custom synthetic dataset
- **Assessment**: Schema design questions

#### Section 05: Data Validation Gates
**File**: `module-02-data/section-05-data-validation.md`
**Content outline**:
- Why validation matters (fail fast principle)
- Validation types: schema, nulls, types, ranges, business rules
- **Code walkthrough**: `src/churn_mlops/data/validate.py`
  - validate_users() function
  - validate_events() function
  - Referential integrity checks
  - Business rule validation
- Exit codes and error handling
- Integration with pipelines
- **Exercise**: Add custom validation rule
- **Assessment**: Design validation for new data source

#### Section 06: Data Processing Pipeline
**File**: `module-02-data/section-06-data-processing.md`
**Content outline**:
- Raw to processed data flow
- Data cleaning techniques
- User-daily aggregation logic
- **Code walkthrough**: `src/churn_mlops/data/prepare_dataset.py`
  - clean_users()
  - clean_events()
  - build_user_daily()
  - Date alignment
- Pandas best practices
- Memory optimization
- **Exercise**: Add new aggregation metric
- **Assessment**: Debug data processing issue

#### Section 07: Feature Engineering Deep Dive
**File**: `module-02-data/section-07-feature-engineering.md`
**Content outline**:
- Feature engineering philosophy
- Rolling window calculations (7d, 14d, 30d)
- Temporal features (recency, frequency)
- Label leakage prevention
- **Code walkthrough**: `src/churn_mlops/features/build_features.py`
  - Rolling aggregations with pandas
  - Days-since features
  - Payment failure rate
  - Static features (plan, country)
- Feature catalog and documentation
- Feature importance analysis
- **Exercise**: Create new rolling window feature
- **Assessment**: Identify label leakage scenarios

---

### Module 3: Machine Learning (4 sections)

#### Section 08: ML Fundamentals for Churn
**File**: `module-03-ml/section-08-ml-fundamentals.md`
**Content outline**:
- Classification problem definition
- Logistic regression explained
  - Sigmoid function
  - Log-odds
  - Coefficients interpretation
- Evaluation metrics deep-dive
  - Accuracy (why it's misleading)
  - Precision, Recall, F1-score
  - ROC curve, AUC
  - Confusion matrix
- Class imbalance problem
  - Why churn is imbalanced (25% vs 75%)
  - Solutions: class_weight, SMOTE, threshold tuning
- Scikit-learn pipeline architecture
- **Exercise**: Calculate metrics manually
- **Assessment**: Metric selection for business problem

#### Section 09: Training Pipeline
**File**: `module-03-ml/section-09-training-pipeline.md`
**Content outline**:
- Label creation logic (30-day forward window)
- **Code walkthrough**: `src/churn_mlops/training/build_labels.py`
- Training set creation
- **Code walkthrough**: `src/churn_mlops/training/build_training_set.py`
- Time-aware train/test split (why random split is wrong)
- **Code walkthrough**: `src/churn_mlops/training/train_baseline.py`
  - ColumnTransformer for preprocessing
  - Pipeline construction
  - Model training
  - Evaluation
- Hyperparameter tuning (GridSearchCV)
- **Code walkthrough**: `src/churn_mlops/training/train_candidate.py`
- **Exercise**: Train model with different hyperparameters
- **Assessment**: Explain time-aware split importance

#### Section 10: Model Registry & Versioning
**File**: `module-03-ml/section-10-model-registry.md`
**Content outline**:
- Why model versioning matters
- Artifact structure (model + metadata)
- **Code walkthrough**: `src/churn_mlops/training/promote_model.py`
  - Model comparison logic
  - Promotion criteria
  - production_latest.joblib creation
- Metadata tracking (metrics, settings, timestamps)
- Model lineage
- Rollback strategies
- **Exercise**: Compare two models and promote best
- **Assessment**: Design model registry schema

#### Section 11: Batch & Real-time Inference
**File**: `module-03-ml/section-11-inference.md`
**Content outline**:
- Batch vs real-time serving
- **Code walkthrough**: `src/churn_mlops/inference/batch_score.py`
  - Load production model
  - Feature alignment
  - Batch prediction
  - Risk ranking
- **Code walkthrough**: `src/churn_mlops/api/app.py`
  - FastAPI application structure
  - /predict endpoint
  - /health, /ready, /live endpoints
  - Request/response models (Pydantic)
  - Error handling
- API testing with curl
- **Exercise**: Add new API endpoint
- **Assessment**: When to use batch vs real-time?

---

### Module 4: Containerization (3 sections)

#### Section 12: Docker Fundamentals
**File**: `module-04-containers/section-12-docker-fundamentals.md`
**Content outline**:
- What are containers? (vs VMs)
- Docker architecture (images, containers, registries)
- Dockerfile syntax
  - FROM, RUN, COPY, CMD, ENTRYPOINT
  - Multi-stage builds
  - Layer caching
- Image optimization techniques
  - Minimize layers
  - Use .dockerignore
  - Small base images (alpine vs slim)
- Docker commands cheat sheet
- **Exercise**: Build simple Python container
- **Assessment**: Optimize Dockerfile size

#### Section 13: ML Container Design
**File**: `module-04-containers/section-13-ml-containers.md`
**Content outline**:
- **Code walkthrough**: `docker/Dockerfile.ml`
  - Base image selection
  - Dependency installation
  - Script copying
  - Volume mount points
  - Working directory
- Environment variables for config
- Handling data volumes
- Running ML jobs in containers
- Testing containers locally
- **Exercise**: Build and run ML container
- **Assessment**: Debug container build failure

#### Section 14: API Container Design
**File**: `module-04-containers/section-14-api-containers.md`
**Content outline**:
- **Code walkthrough**: `docker/Dockerfile.api`
  - FastAPI + uvicorn setup
  - Port exposure
  - Health check configuration
  - Graceful shutdown
- Production configurations
  - Workers count
  - Timeout settings
  - Logging to stdout
- Container security best practices
  - Non-root user
  - Minimal packages
  - Vulnerability scanning
- **Exercise**: Build and test API container
- **Assessment**: Configure production-ready API

---

### Module 5: Kubernetes Orchestration (5 sections)

#### Section 15: Kubernetes Fundamentals
**File**: `module-05-kubernetes/section-15-k8s-fundamentals.md`
**Content outline**:
- Kubernetes architecture
  - Control plane (API server, scheduler, etcd)
  - Worker nodes (kubelet, kube-proxy)
- Core concepts
  - Pods (smallest unit)
  - Services (networking)
  - ConfigMaps (configuration)
  - Secrets (sensitive data)
  - PersistentVolumes (storage)
  - Namespaces (isolation)
- kubectl commands cheat sheet
- YAML manifest structure
- **Exercise**: Deploy hello-world pod
- **Assessment**: Kubernetes concepts quiz

#### Section 16: Jobs & CronJobs
**File**: `module-05-kubernetes/section-16-jobs-cronjobs.md`
**Content outline**:
- Jobs for one-time tasks
- CronJobs for scheduled tasks
- **Code walkthrough**: `k8s/plain/seed-model-job.yaml`
  - initContainers (directory setup)
  - Main container (training pipeline)
  - Volume mounts
  - ConfigMap injection
  - Backoff policy
- **Code walkthrough**: `k8s/helm/churn-mlops/templates/seed-job.yaml`
- Batch scoring CronJob
- Drift detection CronJob
- Job management and monitoring
- **Exercise**: Create custom CronJob
- **Assessment**: Debug failed Job

#### Section 17: Deployments & Services
**File**: `module-05-kubernetes/section-17-deployments-services.md`
**Content outline**:
- Deployments for stateless apps
- **Code walkthrough**: `k8s/plain/api-deployment.yaml`
  - Replicas for high availability
  - Rolling update strategy
  - Resource requests/limits
  - Liveness/readiness probes
  - Volume mounts
- **Code walkthrough**: `k8s/plain/service.yaml`
  - ClusterIP, NodePort, LoadBalancer
  - Service discovery
  - Port configuration
- Scaling (manual and HPA)
- **Exercise**: Deploy API with 3 replicas
- **Assessment**: Configure health checks

#### Section 18: Helm Charts Deep Dive
**File**: `module-05-kubernetes/section-18-helm-charts.md`
**Content outline**:
- What is Helm? (package manager for K8s)
- Chart structure
  - Chart.yaml (metadata)
  - values.yaml (default config)
  - templates/ (YAML templates)
  - _helpers.tpl (template functions)
- **Code walkthrough**: `k8s/helm/churn-mlops/`
  - Template syntax ({{ .Values.* }})
  - Conditionals ({{- if }})
  - Loops ({{- range }})
  - Include/define
- Multi-environment values
  - values-staging.yaml
  - values-production.yaml
- Helm commands
  - helm lint
  - helm template
  - helm install/upgrade
- **Exercise**: Customize Helm values
- **Assessment**: Debug Helm template error

#### Section 19: Storage & Configuration
**File**: `module-05-kubernetes/section-19-storage-config.md`
**Content outline**:
- **Code walkthrough**: `k8s/plain/pvc.yaml`
  - PersistentVolumeClaim
  - AccessModes (ReadWriteOnce, ReadWriteMany)
  - Storage classes
- **Code walkthrough**: `k8s/plain/configmap.yaml`
  - Store config.yaml
  - Mount as file or env vars
- Secrets (not in this repo, but explained)
- Init containers for setup
- Volume sharing between containers
- **Exercise**: Create ConfigMap from file
- **Assessment**: Choose correct storage solution

---

### Module 6: CI/CD Pipeline (4 sections)

#### Section 20: CI/CD Fundamentals
**File**: `module-06-cicd/section-20-cicd-fundamentals.md`
**Content outline**:
- CI vs CD vs CD (Continuous Delivery vs Deployment)
- Pipeline stages
  - Source → Build → Test → Deploy
- Testing pyramid
  - Unit tests (fast, many)
  - Integration tests (medium)
  - E2E tests (slow, few)
- Deployment strategies
  - Blue/green
  - Canary
  - Rolling update
- Trunk-based development
- Feature flags
- **Exercise**: Design CI/CD pipeline
- **Assessment**: Choose deployment strategy

#### Section 21: GitHub Actions Setup
**File**: `module-06-cicd/section-21-github-actions.md`
**Content outline**:
- **Code walkthrough**: `.github/workflows/ci.yml`
  - Trigger (on push, pull_request)
  - Jobs (lint, test, build)
  - Steps (checkout, setup-python, install, test)
  - Caching dependencies
- **Code walkthrough**: `.github/workflows/cd-build-push.yml`
  - Docker build and push
  - Image tagging (staging, main)
  - Secrets management (DOCKERHUB_TOKEN)
- **Code walkthrough**: `.github/workflows/release.yml`
  - Release creation
  - Semantic versioning
  - GitHub releases
- Workflow syntax deep-dive
- **Exercise**: Add new workflow step
- **Assessment**: Debug workflow failure

#### Section 22: Testing & Quality Gates
**File**: `module-06-cicd/section-22-testing-quality.md`
**Content outline**:
- **Code walkthrough**: `tests/` directory
  - test_config.py (config loading)
  - test_data.py (data generation/validation)
  - test_features.py (feature engineering)
  - test_training.py (model training)
  - test_api.py (API endpoints)
  - conftest.py (pytest fixtures)
- pytest features
  - Fixtures
  - Parametrize
  - Markers
  - Coverage
- Linting with ruff
  - ruff.toml configuration
  - Rules explained
- Code formatting with black
- Pre-commit hooks
- **Exercise**: Write new test
- **Assessment**: Achieve 80% coverage

#### Section 23: Build & Push Pipeline
**File**: `module-06-cicd/section-23-build-push.md`
**Content outline**:
- Docker build in CI
  - Build arguments
  - Build context
  - Layer caching in CI
- Multi-architecture builds (amd64, arm64)
- Image tagging strategies
  - Git SHA
  - Branch name (staging, production)
  - Semantic version (v1.2.3)
- Container registry
  - Docker Hub
  - GitHub Container Registry
  - Private registries
- Image scanning (Trivy, Snyk)
- **Exercise**: Add image scanning step
- **Assessment**: Design tagging strategy

---

### Module 7: GitOps Deployment (3 sections)

#### Section 24: GitOps Principles
**File**: `module-07-gitops/section-24-gitops-principles.md`
**Content outline**:
- What is GitOps?
  - Git as single source of truth
  - Declarative configuration
  - Automated sync
  - Self-healing
- GitOps vs traditional CD
- Pull vs push deployment
- Benefits
  - Audit trail
  - Easy rollback
  - Collaboration
- GitOps workflow
  - Change manifest → Git commit → Auto sync → K8s updates
- ArgoCD vs Flux
- **Exercise**: Compare GitOps vs kubectl apply
- **Assessment**: GitOps principles quiz

#### Section 25: ArgoCD Setup & Configuration
**File**: `module-07-gitops/section-25-argocd-setup.md`
**Content outline**:
- ArgoCD architecture
- Installation on Minikube
- **Code walkthrough**: `argocd/appproject.yaml`
  - Project for organizing apps
  - Source repos
  - Destinations
  - Resource whitelist/blacklist
- **Code walkthrough**: `argocd/staging/application.yaml`
  - Application CRD
  - Source (Git repo, path, revision)
  - Destination (cluster, namespace)
  - Sync policy (auto vs manual)
  - Helm values
- ArgoCD UI overview
- argocd CLI commands
- **Exercise**: Deploy app with ArgoCD
- **Assessment**: Configure sync policy

#### Section 26: Multi-Environment Deployment
**File**: `module-07-gitops/section-26-multi-env-deployment.md`
**Content outline**:
- Environment strategy
  - Development (local)
  - Staging (test cluster)
  - Production (prod cluster)
- **Code comparison**: 
  - argocd/staging/application.yaml
  - argocd/production/application.yaml
  - values-staging.yaml vs values-production.yaml
- Promotion workflow
  - Merge to main → Staging auto-deploys
  - Tag release → Production manual-deploy
- Environment-specific configs
  - Replicas (1 staging, 3 prod)
  - Resources (small staging, large prod)
  - Ingress domains
- Secrets management (sealed-secrets, external-secrets)
- **Exercise**: Promote staging to production
- **Assessment**: Design 3-environment strategy

---

### Module 8: Monitoring & Operations (4 sections)

#### Section 27: Observability Fundamentals
**File**: `module-08-monitoring/section-27-observability-fundamentals.md`
**Content outline**:
- Three pillars: Metrics, Logs, Traces
- Metrics types
  - Counter (predictions_total)
  - Gauge (model_age_seconds)
  - Histogram (prediction_latency)
  - Summary
- Logging best practices
  - Structured logging (JSON)
  - Log levels (DEBUG, INFO, WARNING, ERROR)
  - Correlation IDs
- Distributed tracing (OpenTelemetry)
- SLIs, SLOs, SLAs
  - SLI: API latency p99 < 200ms
  - SLO: 99.5% uptime
  - SLA: Customer agreement
- **Exercise**: Define SLIs for API
- **Assessment**: Design monitoring strategy

#### Section 28: Prometheus Metrics
**File**: `module-08-monitoring/section-28-prometheus-metrics.md`
**Content outline**:
- **Code walkthrough**: `src/churn_mlops/monitoring/api_metrics.py`
  - prometheus_client library
  - Counter: PREDICTION_COUNT
  - Histogram: PREDICTION_LATENCY
  - Gauge: MODEL_INFO
  - Middleware integration
- **Code walkthrough**: `/metrics` endpoint in `api/app.py`
- Prometheus architecture
  - Pull model
  - Time-series database
  - PromQL queries
- Grafana dashboards
  - Visualization
  - Alerting
- Common queries
  - Rate: rate(predictions_total[5m])
  - Percentile: histogram_quantile(0.99, prediction_latency)
- **Exercise**: Add custom metric
- **Assessment**: Write PromQL queries

#### Section 29: Drift Detection
**File**: `module-08-monitoring/section-29-drift-detection.md`
**Content outline**:
- What is drift?
  - Data drift: Input distributions change
  - Concept drift: Relationship between X and y changes
- Why drift matters
  - Model trained on old distribution
  - Performance degrades silently
- Population Stability Index (PSI)
  - Formula: Σ (actual% - expected%) × ln(actual% / expected%)
  - Thresholds: <0.1 no drift, 0.1-0.25 medium, >0.25 high drift
- **Code walkthrough**: `src/churn_mlops/monitoring/drift.py`
  - psi_feature() calculation
  - Binning strategy
  - Handling zero divisions
- **Code walkthrough**: `src/churn_mlops/monitoring/run_drift_check.py`
  - Load reference data
  - Load current data
  - Calculate PSI per feature
  - Exit code 2 if drift detected
- Integration with K8s CronJob
- **Exercise**: Calculate PSI manually
- **Assessment**: Interpret PSI values

#### Section 30: Automated Retraining
**File**: `module-08-monitoring/section-30-automated-retraining.md`
**Content outline**:
- Retraining triggers
  - Scheduled (weekly)
  - Drift-based (PSI > threshold)
  - Performance-based (accuracy drop)
- Retraining workflow
  - Trigger → Train candidate → Evaluate → Compare → Promote/Reject
- **Code walkthrough**: K8s retrain CronJob
  - Runs train_candidate.sh
  - Compares with production model
  - Auto-promotes if better
- Champion/Challenger pattern
  - Champion: Current production model
  - Challenger: New candidate model
  - A/B test before full promotion
- **Code walkthrough**: Score proxy
  - src/churn_mlops/monitoring/run_score_proxy.py
  - Collect actual outcomes
  - Calculate realized metrics
- Model performance monitoring
- **Exercise**: Configure retraining schedule
- **Assessment**: Design retraining strategy

---

### Module 9: Production Best Practices (3 sections)

#### Section 31: Security & Compliance
**File**: `module-09-production/section-31-security-compliance.md`
**Content outline**:
- Container security
  - Scan images (Trivy)
  - Non-root user
  - Read-only filesystem
  - Drop capabilities
- Kubernetes security
  - RBAC (Role-Based Access Control)
  - ServiceAccounts
  - NetworkPolicies
  - PodSecurityPolicies/Standards
  - Secrets management
- API security
  - Authentication (API keys, JWT)
  - Rate limiting
  - Input validation
  - HTTPS/TLS
- Data security
  - Encryption at rest
  - Encryption in transit
  - PII handling
  - GDPR compliance
- Vulnerability scanning
- **Exercise**: Add RBAC for namespace
- **Assessment**: Security checklist

#### Section 32: Performance & Scalability
**File**: `module-09-production/section-32-performance-scalability.md`
**Content outline**:
- Resource optimization
  - CPU/Memory requests vs limits
  - Right-sizing pods
  - Vertical vs horizontal scaling
- Horizontal Pod Autoscaling (HPA)
  - Metrics: CPU, memory, custom
  - Target utilization
  - Scale up/down behavior
- API performance
  - Async processing
  - Caching strategies (Redis)
  - Connection pooling
  - Batch predictions
- Model optimization
  - Model compression (quantization, pruning)
  - ONNX runtime
  - Model serving frameworks (TorchServe, TFServing)
- Load testing (Locust, k6)
- Profiling Python code
- **Exercise**: Configure HPA
- **Assessment**: Performance tuning quiz

#### Section 33: Troubleshooting & Debugging
**File**: `module-09-production/section-33-troubleshooting.md`
**Content outline**:
- Common issues & solutions
  - Pod CrashLoopBackOff
  - ImagePullBackOff
  - OOMKilled (out of memory)
  - API 500 errors
  - Model not found
  - Data validation failures
- Debugging commands
  - kubectl describe pod
  - kubectl logs -f
  - kubectl exec -it
  - kubectl get events
- Application debugging
  - Enable DEBUG logging
  - Add print statements
  - Use pdb/ipdb
  - Test locally first
- Monitoring & alerts
  - Set up PagerDuty/Opsgenie
  - Alert on high error rate
  - Alert on drift detection
- Runbook creation
  - Step-by-step procedures
  - Common failure scenarios
  - Escalation paths
- **Exercise**: Debug failing Job
- **Assessment**: Create runbook entry

---

### Module 10: Capstone Project (1 section)

#### Section 34: End-to-End Deployment
**File**: `module-10-capstone/section-34-end-to-end-deployment.md`
**Content outline**:
- Complete workflow walkthrough
  1. Generate data
  2. Validate data
  3. Engineer features
  4. Train model
  5. Promote to production
  6. Build Docker images
  7. Deploy to staging with ArgoCD
  8. Run integration tests
  9. Monitor for drift
  10. Deploy to production
- Production readiness checklist
  - ✓ All tests passing
  - ✓ Security scans clean
  - ✓ Performance tested
  - ✓ Monitoring configured
  - ✓ Runbooks documented
  - ✓ Team trained
- Go-live procedures
  - Pre-deployment checklist
  - Deployment execution
  - Post-deployment validation
  - Rollback plan
- Post-deployment monitoring
  - Watch error rates
  - Monitor latency
  - Check drift
  - Verify predictions
- Continuous improvement
  - Review metrics weekly
  - Optimize based on data
  - Retrain regularly
- **Exercise**: Full deployment from scratch
- **Assessment**: Production readiness review

---

## 🚀 How to Request Sections

To have any section created with full depth and detail, just ask:

```
"Create Section X: [Section Name]"
```

For example:
- "Create Section 04: Data Architecture & Design"
- "Create Section 09: Training Pipeline"
- "Create Section 18: Helm Charts Deep Dive"

Each section will include:
- ✅ Learning objectives
- ✅ Theory with diagrams
- ✅ Code walkthroughs from actual codebase
- ✅ Hands-on exercises
- ✅ Assessment questions
- ✅ 1.5-3 hours of content

---

## 📊 Progress Tracker

```
Module 1: ████████░░░░ 67% (2/3 complete)
Module 2: ░░░░░░░░░░░░  0% (0/4 complete)
Module 3: ░░░░░░░░░░░░  0% (0/4 complete)
Module 4: ░░░░░░░░░░░░  0% (0/3 complete)
Module 5: ░░░░░░░░░░░░  0% (0/5 complete)
Module 6: ░░░░░░░░░░░░  0% (0/4 complete)
Module 7: ░░░░░░░░░░░░  0% (0/3 complete)
Module 8: ░░░░░░░░░░░░  0% (0/4 complete)
Module 9: ░░░░░░░░░░░░  0% (0/3 complete)
Module 10: ░░░░░░░░░░░░  0% (0/1 complete)

Overall: ██░░░░░░░░░░░░  6% (2/34 complete)
```

---

**Ready to continue?** Just ask for the next section!
