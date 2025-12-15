# Section 26: Prometheus Metrics Collection

**Duration**: 2.5 hours  
**Level**: Intermediate  
**Prerequisites**: Module 5 (Kubernetes), Module 7 (GitOps)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand Prometheus architecture and data model
- ✅ Install Prometheus in Kubernetes
- ✅ Instrument applications with metrics
- ✅ Create custom metrics for ML systems
- ✅ Configure service discovery and scraping
- ✅ Query metrics with PromQL
- ✅ Understand metric types and best practices

---

## 📚 Table of Contents

1. [What is Prometheus?](#what-is-prometheus)
2. [Prometheus Architecture](#prometheus-architecture)
3. [Metric Types](#metric-types)
4. [Installing Prometheus](#installing-prometheus)
5. [Instrumenting Applications](#instrumenting-applications)
6. [Service Discovery](#service-discovery)
7. [PromQL Queries](#promql-queries)
8. [Code Walkthrough](#code-walkthrough)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## What is Prometheus?

> **Prometheus**: Open-source monitoring and alerting toolkit designed for reliability and scalability

```
Traditional Monitoring (Push):
Application → Metrics → Monitoring System
(App pushes metrics)

Prometheus (Pull):
Prometheus ← /metrics ← Application
(Prometheus pulls metrics)
```

### Key Features

| Feature | Description |
|---------|-------------|
| **Time-series database** | Stores metrics with timestamps |
| **Pull-based** | Scrapes metrics from targets |
| **Powerful query language** | PromQL for analysis |
| **Service discovery** | Auto-discovers K8s services |
| **Alerting** | Alert on metric thresholds |
| **Visualization** | Built-in expression browser |

### Why Prometheus for MLOps?

```
MLOps Monitoring Needs:

Application Metrics:
✅ Request rate, latency, errors
✅ API performance

Model Metrics:
✅ Prediction count
✅ Model inference time
✅ Model version

Infrastructure Metrics:
✅ CPU, memory usage
✅ Pod restarts
✅ Storage usage

Data Metrics:
✅ Data drift detection
✅ Feature distribution changes
✅ Prediction quality
```

---

## Prometheus Architecture

### Components

```
┌─────────────────────────────────────────────────┐
│  Prometheus Architecture                         │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │  Prometheus Server                        │  │
│  │  ┌────────────────────────────────────┐  │  │
│  │  │  Retrieval (Scrape targets)        │  │  │
│  │  └────────────────────────────────────┘  │  │
│  │  ┌────────────────────────────────────┐  │  │
│  │  │  Storage (Time-series DB)          │  │  │
│  │  └────────────────────────────────────┘  │  │
│  │  ┌────────────────────────────────────┐  │  │
│  │  │  HTTP Server (API + UI)            │  │  │
│  │  └────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────┘  │
│                    ↑                            │
│                    │ scrapes                    │
│  ┌──────────────────────────────────────────┐  │
│  │  Service Discovery                        │  │
│  │  - Kubernetes API                         │  │
│  │  - Consul, DNS, etc.                      │  │
│  └──────────────────────────────────────────┘  │
│                    ↑                            │
│                    │ discovers                  │
│  ┌──────────────────────────────────────────┐  │
│  │  Targets (Applications)                   │  │
│  │  - /metrics endpoint                      │  │
│  │  - Exposes Prometheus format             │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │  Alertmanager (optional)                  │  │
│  │  - Receives alerts                        │  │
│  │  - Routes to Slack, PagerDuty, etc.      │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Data Flow

```
1. Service Discovery
   Prometheus → Kubernetes API → "Find all pods with prometheus.io/scrape=true"
   
2. Scrape Targets
   Prometheus → HTTP GET /metrics → Application
   Every 30 seconds (configurable)
   
3. Store Metrics
   Time-series database
   metric_name{label1="value1"} value timestamp
   
4. Query Metrics
   User → PromQL → Prometheus → Results
   
5. Alert (if thresholds exceeded)
   Prometheus → Alertmanager → Slack/Email
```

---

## Metric Types

### 1. Counter

> **Counter**: Monotonically increasing value (can only go up)

```python
from prometheus_client import Counter

# Define counter
requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

# Increment
requests_total.labels(method='GET', endpoint='/predict', status='200').inc()
requests_total.labels(method='POST', endpoint='/predict', status='200').inc(5)
```

**Use cases**:
- Total requests
- Total predictions
- Error count
- Cache hits/misses

**Example queries**:
```promql
# Rate of requests per second
rate(http_requests_total[5m])

# Total requests in last hour
increase(http_requests_total[1h])
```

### 2. Gauge

> **Gauge**: Value that can go up or down

```python
from prometheus_client import Gauge

# Define gauge
active_users = Gauge(
    'active_users',
    'Number of active users'
)

# Set value
active_users.set(150)

# Increment/decrement
active_users.inc()     # +1
active_users.dec(5)    # -5
```

**Use cases**:
- Current memory usage
- Number of active connections
- Queue size
- Model confidence

**Example queries**:
```promql
# Current active users
active_users

# Average over 5 minutes
avg_over_time(active_users[5m])
```

### 3. Histogram

> **Histogram**: Samples observations and counts them in configurable buckets

```python
from prometheus_client import Histogram

# Define histogram
request_latency = Histogram(
    'http_request_duration_seconds',
    'Request latency in seconds',
    ['method', 'endpoint'],
    buckets=[0.01, 0.05, 0.1, 0.5, 1.0, 5.0]  # seconds
)

# Observe values
request_latency.labels(method='GET', endpoint='/predict').observe(0.23)
```

**Automatically creates**:
- `_count`: Total number of observations
- `_sum`: Sum of all observed values
- `_bucket{le="..."}`: Cumulative counts in buckets

**Use cases**:
- Request duration
- Model inference time
- Response size

**Example queries**:
```promql
# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Average latency
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
```

### 4. Summary

> **Summary**: Similar to histogram, but calculates quantiles on client side

```python
from prometheus_client import Summary

# Define summary
prediction_time = Summary(
    'prediction_duration_seconds',
    'Time spent making predictions'
)

# Observe
with prediction_time.time():
    # Make prediction
    result = model.predict(features)
```

**Use cases**: Similar to histogram, but prefer histogram for aggregation

---

## Installing Prometheus

### Using Prometheus Operator

**Prometheus Operator**: Simplifies Prometheus deployment on Kubernetes

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (includes Prometheus, Grafana, Alertmanager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false

# Check installation
kubectl get pods -n monitoring
```

**Installed components**:
```
NAME                                                   READY   STATUS
prometheus-kube-prometheus-prometheus-0                2/2     Running
prometheus-kube-state-metrics-xxx                      1/1     Running
prometheus-prometheus-node-exporter-xxx                1/1     Running
prometheus-grafana-xxx                                 3/3     Running
prometheus-kube-prometheus-operator-xxx                1/1     Running
alertmanager-prometheus-kube-prometheus-alertmanager-0 2/2     Running
```

### Access Prometheus UI

```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open browser
# http://localhost:9090
```

### Prometheus Configuration

```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    # Retention period
    retention: 30d
    
    # Storage
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    
    # Scrape interval
    scrapeInterval: 30s
    
    # Evaluation interval (for rules)
    evaluationInterval: 30s
    
    # Resource limits
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi
```

---

## Instrumenting Applications

### Python Application (FastAPI)

```python
# src/churn_mlops/api/app.py
from fastapi import FastAPI
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response
import time

app = FastAPI()

# Define metrics
REQUEST_COUNT = Counter(
    'churn_api_requests_total',
    'Total HTTP requests',
    ['method', 'path', 'status']
)

REQUEST_LATENCY = Histogram(
    'churn_api_request_latency_seconds',
    'Request latency in seconds',
    ['method', 'path']
)

PREDICTION_COUNT = Counter(
    'churn_api_predictions_total',
    'Total predictions served'
)

PREDICTION_LATENCY = Histogram(
    'churn_api_prediction_latency_seconds',
    'Prediction latency in seconds'
)

# Middleware for automatic metrics
@app.middleware("http")
async def metrics_middleware(request, call_next):
    start_time = time.perf_counter()
    
    response = await call_next(request)
    
    # Record metrics
    elapsed_time = time.perf_counter() - start_time
    REQUEST_LATENCY.labels(
        method=request.method,
        path=request.url.path
    ).observe(elapsed_time)
    
    REQUEST_COUNT.labels(
        method=request.method,
        path=request.url.path,
        status=response.status_code
    ).inc()
    
    return response

# Metrics endpoint
@app.get("/metrics")
def metrics():
    """Prometheus metrics endpoint."""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )

# Prediction endpoint with metrics
@app.post("/predict")
def predict(request: PredictionRequest):
    with PREDICTION_LATENCY.time():
        # Make prediction
        result = model.predict(request.features)
        
        # Increment counter
        PREDICTION_COUNT.inc()
    
    return {"prediction": result}
```

### Metrics Output

```
# HELP churn_api_requests_total Total HTTP requests
# TYPE churn_api_requests_total counter
churn_api_requests_total{method="GET",path="/health",status="200"} 150.0
churn_api_requests_total{method="POST",path="/predict",status="200"} 523.0

# HELP churn_api_request_latency_seconds Request latency in seconds
# TYPE churn_api_request_latency_seconds histogram
churn_api_request_latency_seconds_bucket{le="0.005",method="POST",path="/predict"} 12.0
churn_api_request_latency_seconds_bucket{le="0.01",method="POST",path="/predict"} 45.0
churn_api_request_latency_seconds_bucket{le="0.025",method="POST",path="/predict"} 320.0
churn_api_request_latency_seconds_bucket{le="0.05",method="POST",path="/predict"} 498.0
churn_api_request_latency_seconds_bucket{le="+Inf",method="POST",path="/predict"} 523.0
churn_api_request_latency_seconds_sum{method="POST",path="/predict"} 8.234
churn_api_request_latency_seconds_count{method="POST",path="/predict"} 523.0

# HELP churn_api_predictions_total Total predictions served
# TYPE churn_api_predictions_total counter
churn_api_predictions_total 523.0
```

---

## Service Discovery

### ServiceMonitor (Prometheus Operator)

> **ServiceMonitor**: Custom resource that tells Prometheus which services to scrape

```yaml
# k8s/monitoring/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: churn-api
  namespace: churn-mlops
  labels:
    release: prometheus  # Must match Prometheus selector
spec:
  selector:
    matchLabels:
      app: churn-api  # Match service labels
  
  namespaceSelector:
    matchNames:
      - churn-mlops
  
  endpoints:
    - port: http          # Service port name
      path: /metrics      # Metrics endpoint
      interval: 30s       # Scrape interval
      scrapeTimeout: 10s
```

**How it works**:
```
1. Deploy ServiceMonitor
   ↓
2. Prometheus Operator watches for ServiceMonitors
   ↓
3. Operator configures Prometheus to scrape matching services
   ↓
4. Prometheus scrapes /metrics endpoint every 30s
```

### Service with Prometheus Annotations

```yaml
# k8s/api-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: churn-api
  namespace: churn-mlops
  labels:
    app: churn-api
  annotations:
    prometheus.io/scrape: "true"   # Enable scraping
    prometheus.io/path: "/metrics" # Metrics path
    prometheus.io/port: "8000"     # Port to scrape
spec:
  type: ClusterIP
  selector:
    app: churn-api
  ports:
    - name: http
      port: 8000
      targetPort: 8000
```

---

## PromQL Queries

### Basic Queries

```promql
# Instant vector (current value)
churn_api_predictions_total

# Rate of predictions per second
rate(churn_api_predictions_total[5m])

# Sum across all instances
sum(rate(churn_api_predictions_total[5m]))

# Filter by label
churn_api_requests_total{status="200"}

# Multiple filters
churn_api_requests_total{method="POST", path="/predict", status="200"}
```

### Aggregations

```promql
# Sum
sum(rate(churn_api_requests_total[5m]))

# Average
avg(churn_api_request_latency_seconds)

# Max
max(churn_api_request_latency_seconds)

# Count
count(up{job="churn-api"})

# Group by label
sum by(path) (rate(churn_api_requests_total[5m]))
```

### Time Functions

```promql
# Rate (per-second average over time)
rate(churn_api_predictions_total[5m])

# Increase (total increase over time)
increase(churn_api_predictions_total[1h])

# Average over time
avg_over_time(churn_api_request_latency_seconds[5m])

# Predict linear trend
predict_linear(churn_api_predictions_total[1h], 3600)
```

### Percentiles (from histogram)

```promql
# 95th percentile latency
histogram_quantile(
  0.95,
  rate(churn_api_request_latency_seconds_bucket[5m])
)

# 99th percentile
histogram_quantile(
  0.99,
  rate(churn_api_request_latency_seconds_bucket[5m])
)

# Average latency
rate(churn_api_request_latency_seconds_sum[5m]) /
rate(churn_api_request_latency_seconds_count[5m])
```

### Complex Queries

```promql
# Error rate (percentage)
sum(rate(churn_api_requests_total{status=~"5.."}[5m])) /
sum(rate(churn_api_requests_total[5m])) * 100

# Requests per second by endpoint
sum by(path) (rate(churn_api_requests_total[5m]))

# Memory usage percentage
(container_memory_usage_bytes / container_memory_limit_bytes) * 100

# Prediction throughput (predictions/minute)
rate(churn_api_predictions_total[5m]) * 60
```

---

## Code Walkthrough

### Complete Metrics Implementation

```python
# src/churn_mlops/monitoring/api_metrics.py
from prometheus_client import Counter, Histogram, Gauge, Info
import time

# === Counters (always increasing) ===
REQUEST_COUNT = Counter(
    'churn_api_requests_total',
    'Total HTTP requests',
    ['method', 'path', 'status']
)

PREDICTION_COUNT = Counter(
    'churn_api_predictions_total',
    'Total predictions served'
)

ERROR_COUNT = Counter(
    'churn_api_errors_total',
    'Total errors',
    ['error_type']
)

# === Histograms (distributions) ===
REQUEST_LATENCY = Histogram(
    'churn_api_request_latency_seconds',
    'Request latency in seconds',
    ['method', 'path'],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

PREDICTION_LATENCY = Histogram(
    'churn_api_prediction_latency_seconds',
    'Prediction latency in seconds',
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]
)

# === Gauges (can go up/down) ===
ACTIVE_REQUESTS = Gauge(
    'churn_api_active_requests',
    'Number of requests currently being processed'
)

MODEL_CONFIDENCE = Gauge(
    'churn_api_model_confidence',
    'Average model confidence score'
)

# === Info (metadata) ===
MODEL_INFO = Info(
    'churn_api_model',
    'Information about the deployed model'
)

# Set model info once at startup
MODEL_INFO.info({
    'version': 'v1.2.3',
    'algorithm': 'HistGradientBoostingClassifier',
    'trained_date': '2023-12-15'
})


def metrics_middleware():
    """FastAPI middleware for automatic metrics collection."""
    async def middleware(request, call_next):
        # Track active requests
        ACTIVE_REQUESTS.inc()
        
        start_time = time.perf_counter()
        status_code = 500
        
        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        
        except Exception as e:
            ERROR_COUNT.labels(error_type=type(e).__name__).inc()
            raise
        
        finally:
            # Record latency
            elapsed = time.perf_counter() - start_time
            REQUEST_LATENCY.labels(
                method=request.method,
                path=request.url.path
            ).observe(elapsed)
            
            # Record request count
            REQUEST_COUNT.labels(
                method=request.method,
                path=request.url.path,
                status=str(status_code)
            ).inc()
            
            # Decrement active requests
            ACTIVE_REQUESTS.dec()
    
    return middleware
```

---

## Hands-On Exercise

### Exercise 1: Install Prometheus

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Check pods
kubectl get pods -n monitoring

# Port forward
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open browser: http://localhost:9090
```

### Exercise 2: Deploy Application with Metrics

```bash
# Apply ServiceMonitor
kubectl apply -f k8s/monitoring/servicemonitor.yaml

# Deploy application
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/api-service.yaml

# Check metrics endpoint
kubectl port-forward -n churn-mlops svc/churn-api 8000:8000
curl http://localhost:8000/metrics
```

### Exercise 3: Query Metrics

```bash
# Open Prometheus UI: http://localhost:9090

# Query 1: Total predictions
churn_api_predictions_total

# Query 2: Prediction rate (per second)
rate(churn_api_predictions_total[5m])

# Query 3: 95th percentile latency
histogram_quantile(0.95, rate(churn_api_request_latency_seconds_bucket[5m]))

# Query 4: Error rate
sum(rate(churn_api_requests_total{status=~"5.."}[5m])) / sum(rate(churn_api_requests_total[5m]))
```

### Exercise 4: Custom Metrics

```python
# Add custom metric
from prometheus_client import Gauge

data_drift_score = Gauge(
    'churn_data_drift_score',
    'Data drift score (0-1)'
)

# Update in drift detection job
def check_drift():
    score = calculate_drift(current_data, baseline_data)
    data_drift_score.set(score)
```

### Exercise 5: Check Service Discovery

```bash
# Check Prometheus targets
# Prometheus UI → Status → Targets

# Should see:
# churn-mlops/churn-api/0 (UP)
# Endpoint: http://10.0.0.1:8000/metrics
# Last scrape: 5s ago
```

---

## Assessment Questions

### Question 1: Multiple Choice
What metric type should you use for tracking total predictions?

A) Gauge  
B) Histogram  
C) **Counter** ✅  
D) Summary  

---

### Question 2: True/False
**Statement**: Prometheus uses a push-based model where applications push metrics.

**Answer**: False ❌  
**Explanation**: Prometheus uses a **pull-based** model where it scrapes metrics from applications' `/metrics` endpoints.

---

### Question 3: Short Answer
What's the difference between Counter and Gauge?

**Answer**:
- **Counter**: Only increases (e.g., total requests, errors). Reset on restart. Use `rate()` for per-second calculations.
- **Gauge**: Can go up or down (e.g., memory usage, active connections, temperature). Represents current value.

---

### Question 4: Code Analysis
What will this query return?

```promql
rate(churn_api_predictions_total[5m])
```

**Answer**:
- **Per-second rate** of predictions over the last 5 minutes
- Example: If 150 predictions in 5 minutes → 0.5 predictions/second
- Use case: Monitor prediction throughput in real-time

---

### Question 5: Design Challenge
Design metrics for ML model monitoring.

**Answer**:
```python
from prometheus_client import Counter, Histogram, Gauge

# Prediction metrics
PREDICTIONS = Counter('model_predictions_total', 'Total predictions')
PREDICTION_TIME = Histogram('model_inference_seconds', 'Inference time')

# Model performance
PREDICTION_CONFIDENCE = Histogram('model_confidence', 'Prediction confidence')
LOW_CONFIDENCE_PREDICTIONS = Counter('low_confidence_predictions_total', 'Predictions below threshold')

# Data quality
MISSING_FEATURES = Counter('missing_features_total', 'Missing feature values', ['feature'])
DATA_DRIFT = Gauge('data_drift_score', 'Data drift score (0-1)')

# Model version
MODEL_VERSION = Info('model_version', 'Current model version')

# Usage:
PREDICTIONS.inc()
with PREDICTION_TIME.time():
    result = model.predict(X)
PREDICTION_CONFIDENCE.observe(result['confidence'])
if result['confidence'] < 0.7:
    LOW_CONFIDENCE_PREDICTIONS.inc()
```

---

## Key Takeaways

### ✅ What You Learned

1. **Prometheus Basics**
   - Pull-based monitoring
   - Time-series database
   - Service discovery in K8s

2. **Metric Types**
   - Counter (monotonic increase)
   - Gauge (up/down values)
   - Histogram (distributions)
   - Summary (quantiles)

3. **Instrumentation**
   - Python prometheus_client
   - FastAPI middleware
   - Custom metrics for ML

4. **Service Discovery**
   - ServiceMonitor CRD
   - Prometheus annotations
   - Automatic target discovery

5. **PromQL**
   - Basic queries
   - Aggregations (sum, avg)
   - Rate calculations
   - Percentiles

---

## Next Steps

Continue to **[Section 27: Grafana Dashboards](./section-27-grafana-dashboards.md)**

In the next section, we'll:
- Install and configure Grafana
- Create dashboards for ML metrics
- Build visualization panels
- Set up dashboard variables

---

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [Python Client Library](https://github.com/prometheus/client_python)

---

**Progress**: 24/34 sections complete (71%) → **25/34 (74%)**
