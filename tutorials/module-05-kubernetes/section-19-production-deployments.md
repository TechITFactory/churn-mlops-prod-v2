# Section 19: Production Kubernetes Deployments

**Duration**: 3 hours  
**Level**: Advanced  
**Prerequisites**: Sections 16-18 (K8s Fundamentals, Helm, ConfigMaps/Secrets)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Deploy production-ready ML systems to Kubernetes
- ✅ Implement CronJobs for batch scoring
- ✅ Manage persistent storage with PVCs
- ✅ Configure resource limits and requests
- ✅ Set up monitoring and health checks
- ✅ Implement autoscaling
- ✅ Handle rolling updates and rollbacks

---

## 📚 Table of Contents

1. [Production Deployment Architecture](#production-deployment-architecture)
2. [Persistent Storage](#persistent-storage)
3. [CronJobs for ML Pipelines](#cronjobs-for-ml-pipelines)
4. [Resource Management](#resource-management)
5. [Monitoring and Observability](#monitoring-and-observability)
6. [Autoscaling](#autoscaling)
7. [Code Walkthrough](#code-walkthrough)
8. [Hands-On Exercise](#hands-on-exercise)
9. [Assessment Questions](#assessment-questions)

---

## Production Deployment Architecture

### Churn MLOps System Components

```
┌────────────────────────────────────────────────────────┐
│         Kubernetes Cluster (Production)                 │
├────────────────────────────────────────────────────────┤
│                                                         │
│  Namespace: churn-mlops                                 │
│  ┌───────────────────────────────────────────────┐    │
│  │                                               │    │
│  │  API Service (Real-time)                      │    │
│  │  ┌────────┐ ┌────────┐ ┌────────┐           │    │
│  │  │ API    │ │ API    │ │ API    │           │    │
│  │  │ Pod 1  │ │ Pod 2  │ │ Pod 3  │           │    │
│  │  └────────┘ └────────┘ └────────┘           │    │
│  │       ↑          ↑          ↑               │    │
│  │       └──────────┴──────────┘               │    │
│  │              Service (LoadBalancer)          │    │
│  │                                               │    │
│  │  Batch Jobs (Scheduled)                      │    │
│  │  ┌────────────────────────────────┐         │    │
│  │  │ CronJob: Batch Score           │         │    │
│  │  │ Schedule: "0 2 * * *" (2 AM)   │         │    │
│  │  └────────────────────────────────┘         │    │
│  │  ┌────────────────────────────────┐         │    │
│  │  │ CronJob: Drift Check           │         │    │
│  │  │ Schedule: "0 8 * * 1" (Mon 8AM)│         │    │
│  │  └────────────────────────────────┘         │    │
│  │  ┌────────────────────────────────┐         │    │
│  │  │ CronJob: Retrain               │         │    │
│  │  │ Schedule: "0 4 * * 0" (Sun 4AM)│         │    │
│  │  └────────────────────────────────┘         │    │
│  │                                               │    │
│  │  Storage                                      │    │
│  │  ┌────────────────────────────────┐         │    │
│  │  │ PersistentVolumeClaim (10 Gi)  │         │    │
│  │  │ ├── data/                      │         │    │
│  │  │ │   ├── raw/                   │         │    │
│  │  │ │   ├── processed/             │         │    │
│  │  │ │   └── predictions/           │         │    │
│  │  │ └── artifacts/                 │         │    │
│  │  │     ├── models/                │         │    │
│  │  │     └── metrics/               │         │    │
│  │  └────────────────────────────────┘         │    │
│  │                                               │    │
│  │  Configuration                                │    │
│  │  ┌────────────────────────────────┐         │    │
│  │  │ ConfigMap: churn-mlops-config  │         │    │
│  │  │ Secret: db-credentials         │         │    │
│  │  └────────────────────────────────┘         │    │
│  └───────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────┘
```

### Deployment Strategy

| Component | Type | Replicas | Purpose |
|-----------|------|----------|---------|
| **API** | Deployment | 3-5 | Real-time predictions |
| **Batch Scoring** | CronJob | 1 | Daily predictions |
| **Drift Detection** | CronJob | 1 | Weekly model monitoring |
| **Retrain** | CronJob | 1 | Weekly model retraining |
| **Seed Model** | Job | 1 | Initial model deployment |

---

## Persistent Storage

### Why Persistent Volumes?

```
Problem: Ephemeral Storage

Pod lifecycle:
┌──────┐  crashes  ┌──────┐
│ Pod  │ ────────→ │ New  │
│ v1   │           │ Pod  │
└──────┘           └──────┘
   ↓ All data lost!    ↓ Fresh start

- Trained models gone
- User data deleted
- Predictions lost
```

### PersistentVolumeClaim (PVC)

> **PVC**: Request for storage (like a claim ticket for cloud storage)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: churn-mlops-pvc
  namespace: churn-mlops
spec:
  accessModes:
    - ReadWriteOnce  # Single node read/write
  resources:
    requests:
      storage: 10Gi  # Request 10 GB
  storageClassName: standard  # Cloud provider storage class
```

**Access Modes**:
| Mode | Description | Use Case |
|------|-------------|----------|
| `ReadWriteOnce (RWO)` | Single node read/write | Databases, single-replica apps |
| `ReadOnlyMany (ROX)` | Multiple nodes read-only | Shared config |
| `ReadWriteMany (RWX)` | Multiple nodes read/write | Shared file system (NFS) |

### Using PVC in Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-api
spec:
  template:
    spec:
      containers:
        - name: api
          image: techitfactory/churn-api:v1.0
          volumeMounts:
            - name: mlops-storage
              mountPath: /app/data
              subPath: data
            - name: mlops-storage
              mountPath: /app/artifacts
              subPath: artifacts
      
      volumes:
        - name: mlops-storage
          persistentVolumeClaim:
            claimName: churn-mlops-pvc
```

**Directory Structure on PVC**:
```
/pvc/
├── data/
│   ├── raw/
│   ├── processed/
│   ├── features/
│   └── predictions/
└── artifacts/
    ├── models/
    │   ├── baseline_20231215.pkl
    │   └── candidate_20231215.pkl
    ├── metrics/
    │   └── evaluation_20231215.json
    └── registry/
        └── model_registry.db
```

---

## CronJobs for ML Pipelines

### What is a CronJob?

> **CronJob**: Scheduled job (like cron in Linux)

```
Cron Schedule Syntax:
┌───────────── minute (0-59)
│ ┌───────────── hour (0-23)
│ │ ┌───────────── day of month (1-31)
│ │ │ ┌───────────── month (1-12)
│ │ │ │ ┌───────────── day of week (0-6, 0=Sunday)
│ │ │ │ │
* * * * *

Examples:
"0 2 * * *"     → Every day at 2 AM
"0 */6 * * *"   → Every 6 hours
"0 8 * * 1"     → Every Monday at 8 AM
"0 0 1 * *"     → First day of month at midnight
"*/15 * * * *"  → Every 15 minutes
```

### Batch Scoring CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: churn-batch-score
  namespace: churn-mlops
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  successfulJobsHistoryLimit: 2  # Keep 2 successful jobs
  failedJobsHistoryLimit: 2      # Keep 2 failed jobs
  
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never  # Don't restart on failure
          
          containers:
            - name: churn-batch
              image: techitfactory/churn-ml:0.1.0
              imagePullPolicy: IfNotPresent
              
              env:
                - name: CHURN_MLOPS_CONFIG
                  value: /app/config/config.yaml
              
              volumeMounts:
                - name: config
                  mountPath: /app/config/config.yaml
                  subPath: config.yaml
                - name: mlops-storage
                  mountPath: /app/data
                  subPath: data
                - name: mlops-storage
                  mountPath: /app/artifacts
                  subPath: artifacts
              
              command:
                - /bin/sh
                - -c
                - |
                  set -e
                  echo "Starting batch scoring..."
                  python -m churn_mlops.inference.batch_score
                  echo "Batch scoring complete!"
          
          volumes:
            - name: config
              configMap:
                name: churn-mlops-config
            - name: mlops-storage
              persistentVolumeClaim:
                claimName: churn-mlops-pvc
```

### Drift Detection CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: churn-drift-check
  namespace: churn-mlops
spec:
  schedule: "0 8 * * 1"  # Every Monday at 8 AM
  
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          
          containers:
            - name: drift-check
              image: techitfactory/churn-ml:0.1.0
              
              env:
                - name: CHURN_MLOPS_CONFIG
                  value: /app/config/config.yaml
              
              volumeMounts:
                - name: config
                  mountPath: /app/config/config.yaml
                  subPath: config.yaml
                - name: mlops-storage
                  mountPath: /app/data
                  subPath: data
                - name: mlops-storage
                  mountPath: /app/artifacts
                  subPath: artifacts
              
              command:
                - /bin/sh
                - -c
                - |
                  set -e
                  echo "Checking for data drift..."
                  python -m churn_mlops.monitoring.check_drift
                  echo "Drift check complete!"
          
          volumes:
            - name: config
              configMap:
                name: churn-mlops-config
            - name: mlops-storage
              persistentVolumeClaim:
                claimName: churn-mlops-pvc
```

### Retrain CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: churn-retrain
  namespace: churn-mlops
spec:
  schedule: "0 4 * * 0"  # Every Sunday at 4 AM
  
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          
          containers:
            - name: retrain
              image: techitfactory/churn-ml:0.1.0
              
              resources:
                limits:
                  cpu: 2000m
                  memory: 4Gi
                requests:
                  cpu: 1000m
                  memory: 2Gi
              
              env:
                - name: CHURN_MLOPS_CONFIG
                  value: /app/config/config.yaml
              
              volumeMounts:
                - name: config
                  mountPath: /app/config/config.yaml
                  subPath: config.yaml
                - name: mlops-storage
                  mountPath: /app/data
                  subPath: data
                - name: mlops-storage
                  mountPath: /app/artifacts
                  subPath: artifacts
              
              command:
                - /bin/sh
                - -c
                - |
                  set -e
                  echo "Starting model retraining..."
                  python -m churn_mlops.training.train_candidate
                  python -m churn_mlops.training.promote_model
                  echo "Retraining complete!"
          
          volumes:
            - name: config
              configMap:
                name: churn-mlops-config
            - name: mlops-storage
              persistentVolumeClaim:
                claimName: churn-mlops-pvc
```

### Managing CronJobs

```bash
# List CronJobs
kubectl get cronjobs -n churn-mlops

# Describe (see schedule, last run)
kubectl describe cronjob churn-batch-score -n churn-mlops

# Manually trigger (create one-off job)
kubectl create job --from=cronjob/churn-batch-score manual-batch-1 -n churn-mlops

# View job history
kubectl get jobs -n churn-mlops

# View logs from job
kubectl logs job/churn-batch-score-1234567890 -n churn-mlops

# Suspend CronJob (stop scheduling)
kubectl patch cronjob churn-batch-score -p '{"spec":{"suspend":true}}' -n churn-mlops

# Resume CronJob
kubectl patch cronjob churn-batch-score -p '{"spec":{"suspend":false}}' -n churn-mlops
```

---

## Resource Management

### Why Resource Limits?

```
Without Limits:

Pod 1: Uses 4 GB memory → OK
Pod 2: Uses 6 GB memory → OK
Pod 3: Tries to allocate 3 GB → OOMKilled! (Out of Memory)

Node has 10 GB total
Pods exceed capacity → Kubernetes kills pods randomly
```

### Requests vs Limits

```yaml
resources:
  requests:
    memory: "512Mi"   # Guaranteed minimum
    cpu: "500m"       # 0.5 CPU cores
  limits:
    memory: "1Gi"     # Maximum allowed
    cpu: "1000m"      # 1 CPU core
```

**How it works**:
1. **Requests**: Scheduler ensures node has this much available
   - Pod guaranteed to get at least this much
   - If node doesn't have enough, pod not scheduled

2. **Limits**: Container killed if exceeds
   - Memory limit → OOMKilled (Out of Memory)
   - CPU limit → Throttled (slowed down)

### Resource Units

| Resource | Units | Example |
|----------|-------|---------|
| **Memory** | `Ki`, `Mi`, `Gi` | `512Mi` = 512 MiB |
| **CPU** | `m` (millicores) | `500m` = 0.5 cores |
|  | Decimal | `0.5` = 0.5 cores |

**CPU Examples**:
```yaml
cpu: "1"      # 1 CPU core
cpu: "1000m"  # 1 CPU core (1000 millicores)
cpu: "500m"   # 0.5 CPU core
cpu: "0.5"    # 0.5 CPU core
cpu: "2"      # 2 CPU cores
```

### Production Resource Configuration

```yaml
# API (real-time, low latency required)
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"

# ML Training (compute-intensive)
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"

# Batch Scoring (medium load)
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### Quality of Service (QoS)

| QoS Class | Condition | Priority |
|-----------|-----------|----------|
| **Guaranteed** | requests = limits | Highest (killed last) |
| **Burstable** | requests < limits | Medium |
| **BestEffort** | No requests/limits | Lowest (killed first) |

**Example**:
```yaml
# Guaranteed QoS (production critical)
resources:
  requests:
    memory: "1Gi"
    cpu: "1000m"
  limits:
    memory: "1Gi"    # Same as requests
    cpu: "1000m"     # Same as requests

# Burstable QoS (can burst above requests)
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "2Gi"    # Can use up to 2Gi
    cpu: "2000m"     # Can use up to 2 cores
```

---

## Monitoring and Observability

### Health Checks (Probes)

```yaml
containers:
  - name: api
    image: techitfactory/churn-api:v1.0
    
    # Liveness: Is container alive?
    livenessProbe:
      httpGet:
        path: /live
        port: 8000
      initialDelaySeconds: 10  # Wait 10s after start
      periodSeconds: 20        # Check every 20s
      timeoutSeconds: 5        # 5s timeout
      failureThreshold: 3      # Restart after 3 failures
    
    # Readiness: Is container ready for traffic?
    readinessProbe:
      httpGet:
        path: /ready
        port: 8000
      initialDelaySeconds: 5
      periodSeconds: 10
      failureThreshold: 3
    
    # Startup: Has container started?
    startupProbe:
      httpGet:
        path: /live
        port: 8000
      initialDelaySeconds: 0
      periodSeconds: 5
      failureThreshold: 30  # 30 * 5s = 150s startup time
```

**Probe Implementations** (`src/churn_mlops/api/app.py`):
```python
@app.get("/live")
def liveness():
    """Liveness probe: Is API process running?"""
    return {"status": "alive"}

@app.get("/ready")
def readiness():
    """Readiness probe: Is API ready for traffic?"""
    # Check dependencies
    try:
        # Check model loaded
        if not model_loaded():
            return JSONResponse(
                status_code=503,
                content={"status": "not ready", "reason": "model not loaded"}
            )
        
        # Check database connection (if applicable)
        # if not db_healthy():
        #     return JSONResponse(status_code=503, ...)
        
        return {"status": "ready"}
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={"status": "error", "reason": str(e)}
        )
```

### Prometheus Metrics

```yaml
# API Service with Prometheus annotations
apiVersion: v1
kind: Service
metadata:
  name: churn-api
  annotations:
    prometheus.io/scrape: "true"    # Enable scraping
    prometheus.io/path: "/metrics"  # Metrics endpoint
    prometheus.io/port: "8000"      # Port
```

**Metrics Implementation**:
```python
from prometheus_client import Counter, Histogram, Gauge

# Request counter
requests_total = Counter(
    'api_requests_total',
    'Total API requests',
    ['method', 'endpoint', 'status']
)

# Response time
response_time = Histogram(
    'api_response_time_seconds',
    'API response time'
)

# Model version
model_version = Gauge(
    'model_version_info',
    'Current model version',
    ['version', 'date']
)

@app.get("/predict")
async def predict(request: PredictionRequest):
    requests_total.labels(method='POST', endpoint='/predict', status='200').inc()
    
    with response_time.time():
        # Make prediction
        result = model.predict(request.features)
    
    return result
```

---

## Autoscaling

### Horizontal Pod Autoscaler (HPA)

> **HPA**: Automatically scales replicas based on metrics

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: churn-api-hpa
  namespace: churn-mlops
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: churn-api
  
  minReplicas: 2   # Minimum pods
  maxReplicas: 10  # Maximum pods
  
  metrics:
    # Scale based on CPU
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70  # Target 70% CPU
    
    # Scale based on memory
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80  # Target 80% memory
```

**How it works**:
```
Current CPU usage: 85% (above 70% target)
HPA: Scale up!
Replicas: 2 → 3

CPU drops to 60% (below 70%)
HPA: OK, maintain

CPU drops to 40% (well below 70%)
HPA: Scale down
Replicas: 3 → 2
```

**Manage HPA**:
```bash
# Create HPA
kubectl apply -f hpa.yaml

# View HPA
kubectl get hpa -n churn-mlops

# Describe (see current metrics)
kubectl describe hpa churn-api-hpa -n churn-mlops

# Watch scaling events
kubectl get hpa -n churn-mlops -w
```

---

## Code Walkthrough

### Complete Production Deployment

**1. Namespace**:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: churn-mlops
```

**2. PersistentVolumeClaim**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: churn-mlops-pvc
  namespace: churn-mlops
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard
```

**3. ConfigMap** (from earlier section)

**4. API Deployment**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-api
  namespace: churn-mlops
spec:
  replicas: 3
  selector:
    matchLabels:
      app: churn-api
  template:
    metadata:
      labels:
        app: churn-api
    spec:
      containers:
        - name: churn-api
          image: techitfactory/churn-api:0.1.0
          ports:
            - containerPort: 8000
          env:
            - name: CHURN_MLOPS_CONFIG
              value: /app/config/config.yaml
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
          livenessProbe:
            httpGet:
              path: /live
              port: 8000
            initialDelaySeconds: 10
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /ready
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 10
          volumeMounts:
            - name: config
              mountPath: /app/config/config.yaml
              subPath: config.yaml
            - name: mlops-storage
              mountPath: /app/data
              subPath: data
            - name: mlops-storage
              mountPath: /app/artifacts
              subPath: artifacts
      volumes:
        - name: config
          configMap:
            name: churn-mlops-config
        - name: mlops-storage
          persistentVolumeClaim:
            claimName: churn-mlops-pvc
```

**5. Service**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: churn-api
  namespace: churn-mlops
spec:
  type: ClusterIP
  selector:
    app: churn-api
  ports:
    - port: 8000
      targetPort: 8000
```

**Deploy All**:
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/pvc.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/api-service.yaml
kubectl apply -f k8s/batch-cronjob.yaml
```

---

## Hands-On Exercise

### Exercise 1: Deploy Complete System

```bash
# Create namespace
kubectl create namespace churn-mlops

# Apply all resources
kubectl apply -f k8s/ -n churn-mlops

# Check status
kubectl get all -n churn-mlops

# View pods
kubectl get pods -n churn-mlops
```

### Exercise 2: Test API

```bash
# Port forward
kubectl port-forward -n churn-mlops svc/churn-api 8000:8000

# Test health
curl http://localhost:8000/health

# Test prediction
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user123",
    "features": {
      "logins_7d": 15,
      "sessions_7d": 20
    }
  }'
```

### Exercise 3: Trigger Batch Job

```bash
# Manually trigger batch scoring
kubectl create job --from=cronjob/churn-batch-score manual-batch -n churn-mlops

# Watch job
kubectl get jobs -n churn-mlops -w

# View logs
kubectl logs job/manual-batch -n churn-mlops

# Check predictions
kubectl exec -n churn-mlops deployment/churn-api -- ls /app/data/predictions
```

### Exercise 4: Scale API

```bash
# Manual scale
kubectl scale deployment churn-api --replicas=5 -n churn-mlops

# Check
kubectl get pods -n churn-mlops

# Create HPA
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: churn-api-hpa
  namespace: churn-mlops
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: churn-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
EOF

# View HPA
kubectl get hpa -n churn-mlops
```

### Exercise 5: Rolling Update

```bash
# Update image
kubectl set image deployment/churn-api churn-api=techitfactory/churn-api:0.2.0 -n churn-mlops

# Watch rollout
kubectl rollout status deployment/churn-api -n churn-mlops

# Check history
kubectl rollout history deployment/churn-api -n churn-mlops

# Rollback if needed
kubectl rollout undo deployment/churn-api -n churn-mlops
```

---

## Assessment Questions

### Question 1: Multiple Choice
What's the purpose of a CronJob?

A) Run containers continuously  
B) **Run scheduled tasks periodically** ✅  
C) Store configuration  
D) Expose services externally  

---

### Question 2: True/False
**Statement**: PersistentVolumeClaims provide storage that persists across pod restarts.

**Answer**: True ✅  
**Explanation**: PVCs provide persistent storage independent of pod lifecycle.

---

### Question 3: Short Answer
What happens if a container exceeds its memory limit?

**Answer**:
- Container is killed (OOMKilled - Out of Memory)
- Kubernetes may restart it (depending on restart policy)
- Check with: `kubectl describe pod <pod-name>` (shows OOMKilled status)

---

### Question 4: Code Analysis
What's wrong with this CronJob schedule?

```yaml
schedule: "* * * * *"  # Every minute
```

**Answer**:
- Runs every minute (too frequent for ML tasks!)
- Can cause:
  - Resource exhaustion (too many jobs)
  - Overlapping jobs (previous job not finished)
  - High costs (compute resources)
- Better: `"0 2 * * *"` (daily) or `"0 */6 * * *"` (every 6 hours)

---

### Question 5: Design Challenge
Design production deployment for API with autoscaling, health checks, and persistent storage.

**Answer**:
```yaml
# PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: api
          image: my-api:v1.0
          resources:
            requests: {memory: "512Mi", cpu: "500m"}
            limits: {memory: "1Gi", cpu: "1000m"}
          livenessProbe:
            httpGet: {path: /live, port: 8000}
          readinessProbe:
            httpGet: {path: /ready, port: 8000}
          volumeMounts:
            - name: storage
              mountPath: /data
      volumes:
        - name: storage
          persistentVolumeClaim:
            claimName: data-pvc
---
# HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef: {kind: Deployment, name: api}
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource: {name: cpu, target: {type: Utilization, averageUtilization: 70}}
```

---

## Key Takeaways

### ✅ What You Learned

1. **Production Architecture**
   - API Deployment (3+ replicas)
   - CronJobs (batch, drift, retrain)
   - Persistent storage (PVC)
   - Configuration (ConfigMap/Secret)

2. **Persistent Storage**
   - PersistentVolumeClaim (PVC)
   - Access modes (RWO, ROX, RWX)
   - Volume mounts in pods

3. **CronJobs**
   - Scheduled tasks (cron syntax)
   - Batch scoring, drift detection, retraining
   - Job history management

4. **Resource Management**
   - Requests (guaranteed minimum)
   - Limits (maximum allowed)
   - QoS classes

5. **Autoscaling**
   - HPA (Horizontal Pod Autoscaler)
   - CPU/memory-based scaling
   - Min/max replicas

---

## Next Steps

**Module 5 Complete!** 🎉 You've finished Kubernetes.

Continue to **[Module 06: CI/CD](../../module-06-cicd/)**

In the next module, we'll:
- Build CI/CD pipelines
- Automate testing and deployment
- Implement GitOps workflows
- Set up continuous delivery

---

## Additional Resources

- [Kubernetes Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)
- [CronJob Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- [Autoscaling Guide](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

---

**Progress**: 17/34 sections complete (50%) → **18/34 (53%)**

**Module 5 Summary**:
- ✅ Section 16: Kubernetes Fundamentals (3 hours)
- ✅ Section 17: Helm Charts (2.5 hours)
- ✅ Section 18: ConfigMaps & Secrets (2 hours)
- ✅ Section 19: Production Deployments (3 hours)

**Total Module 5**: 10.5 hours of content

Next: **Module 6: CI/CD** →
