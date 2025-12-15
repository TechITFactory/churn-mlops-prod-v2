# Section 28: Logging and Log Aggregation with Loki

**Duration**: 2.5 hours  
**Level**: Intermediate  
**Prerequisites**: Section 27 (Grafana Dashboards)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand the difference between metrics and logs
- ✅ Install Grafana Loki for log aggregation
- ✅ Configure structured logging in Python applications
- ✅ Query logs with LogQL
- ✅ Correlate logs with metrics in Grafana
- ✅ Set up log-based alerts
- ✅ Implement log retention policies

---

## 📚 Table of Contents

1. [Metrics vs Logs vs Traces](#metrics-vs-logs-vs-traces)
2. [What is Grafana Loki?](#what-is-grafana-loki)
3. [Installing Loki](#installing-loki)
4. [Structured Logging](#structured-logging)
5. [LogQL Query Language](#logql-query-language)
6. [Correlating Logs and Metrics](#correlating-logs-and-metrics)
7. [Log-Based Alerts](#log-based-alerts)
8. [Code Walkthrough](#code-walkthrough)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## Metrics vs Logs vs Traces

### The Three Pillars of Observability

```
┌────────────────────────────────────────────────┐
│  Observability Pillars                          │
├────────────────────────────────────────────────┤
│                                                 │
│  📊 METRICS (What is happening?)               │
│  - Aggregated numeric data                     │
│  - Time-series database                        │
│  - Example: request_rate = 100 req/sec        │
│  - Tool: Prometheus                            │
│                                                 │
│  📝 LOGS (Why did it happen?)                  │
│  - Individual events with context              │
│  - Structured or unstructured text             │
│  - Example: "User 123 prediction failed: ..."  │
│  - Tool: Loki                                  │
│                                                 │
│  🔍 TRACES (How did it propagate?)             │
│  - Request flow through services               │
│  - Distributed transactions                    │
│  - Example: API → Model → Database             │
│  - Tool: Jaeger, Tempo                         │
│                                                 │
└────────────────────────────────────────────────┘
```

### When to Use Each

| Scenario | Use |
|----------|-----|
| **Monitor API response time trend** | Metrics (Prometheus histogram) |
| **Investigate specific failed request** | Logs (Loki with request ID) |
| **Track request across microservices** | Traces (Jaeger) |
| **Alert on high error rate** | Metrics + Logs |
| **Debug model prediction issue** | Logs (input features, model output) |
| **Capacity planning** | Metrics (CPU, memory trends) |

### Example: Debugging a Failed Prediction

```
1. METRICS (Detection):
   Prometheus alert: error_rate > 1%
   "Something is wrong"

2. LOGS (Investigation):
   Loki query: {app="churn-api"} |= "error"
   Find: "ValueError: Feature 'age' missing"
   "Specific problem identified"

3. TRACES (Root cause):
   Jaeger: API → Feature Service → Database
   Find: Feature Service returned incomplete data
   "Full request flow revealed"
```

---

## What is Grafana Loki?

> **Loki**: Horizontally scalable, highly available log aggregation system inspired by Prometheus

### Key Features

| Feature | Description |
|---------|-------------|
| **Labels-based indexing** | Like Prometheus (not full-text indexing) |
| **Cost-effective** | Indexes only metadata, not log content |
| **Grafana integration** | Native support in Grafana |
| **PromQL-like queries** | LogQL similar to PromQL |
| **Cloud-native** | Kubernetes-ready |
| **Multi-tenancy** | Supports multiple isolated tenants |

### Loki vs ELK Stack

| Aspect | Loki | ELK (Elasticsearch) |
|--------|------|---------------------|
| **Indexing** | Labels only | Full-text |
| **Storage** | Object storage (S3) | Dedicated nodes |
| **Cost** | Low (small index) | High (large index) |
| **Query speed** | Fast for labeled queries | Fast for text search |
| **Setup complexity** | Simple | Complex |
| **Best for** | Cloud-native apps | Complex text search |

### Loki Architecture

```
┌──────────────────────────────────────────────────┐
│  Loki Architecture                                │
├──────────────────────────────────────────────────┤
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │  Application (Churn API)                     │ │
│  │  - Logs to stdout/stderr                     │ │
│  │  - JSON structured logs                      │ │
│  └─────────────────────────────────────────────┘ │
│                    ↓                              │
│  ┌─────────────────────────────────────────────┐ │
│  │  Promtail (Log collector)                    │ │
│  │  - Reads pod logs                            │ │
│  │  - Adds labels (namespace, pod, container)   │ │
│  │  - Pushes to Loki                            │ │
│  └─────────────────────────────────────────────┘ │
│                    ↓                              │
│  ┌─────────────────────────────────────────────┐ │
│  │  Loki (Storage & Query)                      │ │
│  │  - Indexes labels                            │ │
│  │  - Stores logs in chunks                     │ │
│  │  - Serves queries                            │ │
│  └─────────────────────────────────────────────┘ │
│                    ↓                              │
│  ┌─────────────────────────────────────────────┐ │
│  │  Grafana (Visualization)                     │ │
│  │  - LogQL queries                             │ │
│  │  - Log browser                               │ │
│  │  - Correlated with metrics                   │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
└──────────────────────────────────────────────────┘
```

---

## Installing Loki

### Using Helm (Loki Stack)

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki stack (Loki + Promtail + Grafana)
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \  # Already have Grafana
  --set prometheus.enabled=false \  # Already have Prometheus
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi

# Check installation
kubectl get pods -n monitoring
# loki-0
# loki-promtail-xxxxx (DaemonSet on each node)
```

### Configuration

```yaml
# loki-values.yaml
loki:
  config:
    auth_enabled: false
    
    ingester:
      chunk_idle_period: 3m
      chunk_block_size: 262144
      chunk_retain_period: 1m
      max_transfer_retries: 0
      lifecycler:
        ring:
          kvstore:
            store: inmemory
          replication_factor: 1
    
    limits_config:
      retention_period: 168h  # 7 days
      enforce_metric_name: false
      reject_old_samples: true
      reject_old_samples_max_age: 168h
      ingestion_rate_mb: 10
      ingestion_burst_size_mb: 20
    
    schema_config:
      configs:
        - from: 2020-10-24
          store: boltdb-shipper
          object_store: filesystem
          schema: v11
          index:
            prefix: index_
            period: 24h
    
    server:
      http_listen_port: 3100
    
    storage_config:
      boltdb_shipper:
        active_index_directory: /data/loki/boltdb-shipper-active
        cache_location: /data/loki/boltdb-shipper-cache
        cache_ttl: 24h
        shared_store: filesystem
      filesystem:
        directory: /data/loki/chunks
    
    chunk_store_config:
      max_look_back_period: 168h  # 7 days
    
    table_manager:
      retention_deletes_enabled: true
      retention_period: 168h  # 7 days
  
  persistence:
    enabled: true
    size: 10Gi

promtail:
  config:
    clients:
      - url: http://loki:3100/loki/api/v1/push
    
    positions:
      filename: /tmp/positions.yaml
    
    scrape_configs:
      # Kubernetes pods
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        
        relabel_configs:
          # Only scrape pods with annotation
          - source_labels:
              - __meta_kubernetes_pod_annotation_prometheus_io_scrape
            action: keep
            regex: true
          
          # Add namespace label
          - source_labels:
              - __meta_kubernetes_namespace
            target_label: namespace
          
          # Add pod label
          - source_labels:
              - __meta_kubernetes_pod_name
            target_label: pod
          
          # Add container label
          - source_labels:
              - __meta_kubernetes_pod_container_name
            target_label: container
          
          # Add app label
          - source_labels:
              - __meta_kubernetes_pod_label_app
            target_label: app
```

### Add Loki Data Source to Grafana

```bash
# Via UI:
1. Configuration → Data Sources
2. Add data source
3. Select "Loki"
4. URL: http://loki:3100
5. Save & Test

# Or apply ConfigMap:
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasource-loki
  namespace: monitoring
data:
  loki-datasource.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki:3100
        jsonData:
          maxLines: 1000
EOF
```

---

## Structured Logging

### Why Structured Logging?

```
❌ Unstructured:
2023-12-15 10:30:45 INFO User john made prediction with confidence 0.85

✅ Structured (JSON):
{
  "timestamp": "2023-12-15T10:30:45Z",
  "level": "INFO",
  "message": "Prediction made",
  "user": "john",
  "confidence": 0.85,
  "model_version": "v1.2.3",
  "request_id": "abc-123"
}
```

**Benefits**:
- Easy to parse and query
- Consistent format
- Enable log aggregation
- Support filtering by fields

### Python Structured Logging

```python
# src/churn_mlops/utils/logging.py
import logging
import json
import sys
from datetime import datetime
from typing import Any, Dict

class StructuredFormatter(logging.Formatter):
    """JSON formatter for structured logging."""
    
    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON."""
        log_data: Dict[str, Any] = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        
        # Add custom fields from extra
        if hasattr(record, "extra_fields"):
            log_data.update(record.extra_fields)
        
        return json.dumps(log_data)


def setup_logging(level: str = "INFO") -> None:
    """Configure structured logging."""
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(StructuredFormatter())
    
    logging.root.setLevel(level)
    logging.root.addHandler(handler)


# Usage in API
from fastapi import FastAPI, Request
import logging
import uuid

app = FastAPI()
logger = logging.getLogger(__name__)

@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    """Add request ID to logs."""
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    
    # Add request_id to log context
    extra = {
        "extra_fields": {
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
        }
    }
    
    logger.info("Request started", extra=extra)
    
    response = await call_next(request)
    
    extra["extra_fields"]["status_code"] = response.status_code
    logger.info("Request completed", extra=extra)
    
    return response


@app.post("/predict")
def predict(request: PredictionRequest, http_request: Request):
    """Make prediction with logging."""
    request_id = http_request.state.request_id
    
    extra = {"extra_fields": {"request_id": request_id}}
    
    logger.info(
        "Making prediction",
        extra={
            "extra_fields": {
                "request_id": request_id,
                "features": request.features,
            }
        }
    )
    
    try:
        result = model.predict(request.features)
        
        logger.info(
            "Prediction successful",
            extra={
                "extra_fields": {
                    "request_id": request_id,
                    "prediction": result["prediction"],
                    "confidence": result["confidence"],
                    "model_version": model.version,
                }
            }
        )
        
        return result
    
    except Exception as e:
        logger.error(
            "Prediction failed",
            exc_info=True,
            extra={
                "extra_fields": {
                    "request_id": request_id,
                    "error_type": type(e).__name__,
                }
            }
        )
        raise
```

### Log Output

```json
{"timestamp":"2023-12-15T10:30:45.123Z","level":"INFO","logger":"churn_mlops.api","message":"Request started","module":"app","function":"logging_middleware","line":25,"request_id":"abc-123","method":"POST","path":"/predict"}

{"timestamp":"2023-12-15T10:30:45.234Z","level":"INFO","logger":"churn_mlops.api","message":"Making prediction","module":"app","function":"predict","line":42,"request_id":"abc-123","features":{"age":35,"tenure":12}}

{"timestamp":"2023-12-15T10:30:45.345Z","level":"INFO","logger":"churn_mlops.api","message":"Prediction successful","module":"app","function":"predict","line":52,"request_id":"abc-123","prediction":"no_churn","confidence":0.87,"model_version":"v1.2.3"}

{"timestamp":"2023-12-15T10:30:45.456Z","level":"INFO","logger":"churn_mlops.api","message":"Request completed","module":"app","function":"logging_middleware","line":32,"request_id":"abc-123","method":"POST","path":"/predict","status_code":200}
```

---

## LogQL Query Language

### Basic Syntax

```
{label_filters} |= "text search" | json | filter expressions
```

### Label Filters

```logql
# Single label
{app="churn-api"}

# Multiple labels (AND)
{namespace="churn-mlops", app="churn-api"}

# Regex match
{app=~"churn-.*"}

# Not equal
{app!="churn-api"}

# Regex not match
{app!~"test-.*"}
```

### Log Stream Selectors

```logql
# All logs from app
{app="churn-api"}

# Logs containing "error"
{app="churn-api"} |= "error"

# Logs NOT containing "health"
{app="churn-api"} != "health"

# Regex match in log line
{app="churn-api"} |~ "error|failed|exception"

# Case-insensitive
{app="churn-api"} |~ "(?i)error"
```

### JSON Parsing

```logql
# Parse JSON logs
{app="churn-api"}
  | json
  | level="ERROR"

# Extract specific fields
{app="churn-api"}
  | json
  | line_format "{{.message}} ({{.request_id}})"

# Filter by JSON field
{app="churn-api"}
  | json
  | confidence < 0.7
  | model_version="v1.2.3"
```

### Aggregations

```logql
# Count logs per second
rate({app="churn-api"}[5m])

# Count by level
sum by(level) (rate({app="churn-api"}[5m]))

# Count errors
sum(rate({app="churn-api"} |= "error"[5m]))

# Top 10 endpoints by log volume
topk(10, sum by(path) (rate({app="churn-api"} | json[5m])))

# Average confidence from logs
avg_over_time(
  {app="churn-api"}
    | json
    | unwrap confidence [5m]
)
```

### Example Queries

```logql
# 1. All errors in last hour
{app="churn-api", level="ERROR"}

# 2. Failed predictions
{app="churn-api"}
  | json
  | message =~ ".*failed.*"
  | request_id != ""

# 3. Low confidence predictions
{app="churn-api"}
  | json
  | confidence < 0.7

# 4. Predictions by model version
sum by(model_version) (
  rate({app="churn-api"}
    | json
    | message="Prediction successful"[5m]
  )
)

# 5. Errors per minute
sum(count_over_time({app="churn-api", level="ERROR"}[1m]))

# 6. Request latency from logs
quantile_over_time(0.95,
  {app="churn-api"}
    | json
    | unwrap latency_ms [5m]
) / 1000

# 7. Top error types
topk(5,
  sum by(error_type) (
    rate({app="churn-api"}
      | json
      | level="ERROR"[1h]
    )
  )
)

# 8. Trace request flow by ID
{app=~"churn-.*"}
  | json
  | request_id="abc-123"
```

---

## Correlating Logs and Metrics

### Grafana Panel with Logs and Metrics

```
Dashboard Panel Configuration:

1. Add Time Series Panel (Metrics)
   - Query: rate(churn_api_requests_total{status=~"5.."}[5m])
   - Title: "Error Rate"

2. Add Logs Panel (below)
   - Query: {app="churn-api", level="ERROR"}
   - Title: "Error Logs"
   - Options:
     * Time: Align with metrics panel
     * Wrap lines: Yes
     * Deduplication: Signature

Result: When error spike in metrics → See corresponding logs below
```

### Split View (Explore)

```bash
# Grafana → Explore

# Left pane (Metrics):
Data source: Prometheus
Query: rate(churn_api_errors_total[5m])

# Right pane (Logs):
Data source: Loki
Query: {app="churn-api"} |= "error"

# Link with time range:
Select time range in metrics → Logs auto-filter to same range
```

### Data Links (Click to Logs)

```json
// Panel configuration
{
  "fieldConfig": {
    "defaults": {
      "links": [
        {
          "title": "View logs",
          "url": "/explore?orgId=1&left={\"datasource\":\"Loki\",\"queries\":[{\"expr\":\"{app=\\\"churn-api\\\",request_id=\\\"${__field.labels.request_id}\\\"}\"}]}"
        }
      ]
    }
  }
}
```

### Example: Debugging High Latency

```
Workflow:

1. Prometheus Alert:
   ALERT: HighLatency
   P95 latency > 500ms

2. Grafana Dashboard:
   See latency spike at 10:30 AM

3. Click "View Logs" button

4. Loki Query (auto-populated):
   {app="churn-api"}
     | json
     | latency_ms > 500
     | __timestamp__ > 1702637400000
     | __timestamp__ < 1702637700000

5. Find logs:
   "Database connection timeout"
   "request_id: xyz-789"

6. Root cause identified:
   Database performance issue
```

---

## Log-Based Alerts

### Alerting on Log Patterns

```yaml
# grafana-alert-rules.yaml
groups:
  - name: log_alerts
    interval: 1m
    rules:
      # Alert on error rate from logs
      - alert: HighErrorRate
        expr: |
          sum(rate({app="churn-api", level="ERROR"}[5m])) > 10
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "{{ $value }} errors/sec in churn-api"
      
      # Alert on specific error message
      - alert: DatabaseConnectionError
        expr: |
          sum(count_over_time({app="churn-api"} |= "database connection"[5m])) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database connection errors"
          description: "Database connection failures detected"
      
      # Alert on low confidence predictions
      - alert: LowConfidencePredictions
        expr: |
          sum(rate({app="churn-api"} | json | confidence < 0.6[5m])) > 5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High rate of low-confidence predictions"
          description: "{{ $value }} predictions/sec with confidence < 0.6"
      
      # Alert on missing features
      - alert: MissingFeatures
        expr: |
          sum by(feature) (
            rate({app="churn-api"} | json | message="Missing feature"[5m])
          ) > 1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Missing features detected"
          description: "Feature {{ $labels.feature }} missing in requests"
```

---

## Code Walkthrough

### Complete Logging Setup

```python
# src/churn_mlops/utils/logging_config.py
import logging
import json
import sys
from datetime import datetime
from typing import Any, Dict, Optional
from contextvars import ContextVar
import uuid

# Context variable for request ID
request_id_ctx: ContextVar[Optional[str]] = ContextVar('request_id', default=None)


class StructuredFormatter(logging.Formatter):
    """JSON formatter for structured logs."""
    
    RESERVED_ATTRS = {
        'name', 'msg', 'args', 'created', 'filename', 'funcName',
        'levelname', 'levelno', 'lineno', 'module', 'msecs',
        'message', 'pathname', 'process', 'processName',
        'relativeCreated', 'thread', 'threadName', 'exc_info',
        'exc_text', 'stack_info'
    }
    
    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON."""
        log_data: Dict[str, Any] = {
            "timestamp": datetime.utcfromtimestamp(
                record.created
            ).isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # Add request ID from context
        request_id = request_id_ctx.get()
        if request_id:
            log_data["request_id"] = request_id
        
        # Add exception
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
            log_data["exception_type"] = record.exc_info[0].__name__
        
        # Add custom fields
        for key, value in record.__dict__.items():
            if key not in self.RESERVED_ATTRS and not key.startswith('_'):
                log_data[key] = value
        
        return json.dumps(log_data, default=str)


def setup_logging(
    level: str = "INFO",
    structured: bool = True
) -> None:
    """Configure application logging."""
    handler = logging.StreamHandler(sys.stdout)
    
    if structured:
        handler.setFormatter(StructuredFormatter())
    else:
        handler.setFormatter(
            logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
        )
    
    logging.root.handlers = []
    logging.root.addHandler(handler)
    logging.root.setLevel(level)
    
    # Reduce noise from libraries
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.error").setLevel(logging.INFO)


def get_logger(name: str) -> logging.Logger:
    """Get logger with name."""
    return logging.getLogger(name)


# src/churn_mlops/api/app.py
from fastapi import FastAPI, Request
from churn_mlops.utils.logging_config import (
    setup_logging,
    get_logger,
    request_id_ctx
)
import uuid
import time

setup_logging(level="INFO", structured=True)
logger = get_logger(__name__)

app = FastAPI()


@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    """Add request context and logging."""
    # Generate request ID
    request_id = str(uuid.uuid4())
    request_id_ctx.set(request_id)
    
    # Add to request state
    request.state.request_id = request_id
    
    # Log request start
    logger.info(
        "Request started",
        extra={
            "method": request.method,
            "path": request.url.path,
            "client_host": request.client.host if request.client else None,
        }
    )
    
    start_time = time.perf_counter()
    
    try:
        response = await call_next(request)
        
        # Log request completion
        latency_ms = (time.perf_counter() - start_time) * 1000
        logger.info(
            "Request completed",
            extra={
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "latency_ms": round(latency_ms, 2),
            }
        )
        
        return response
    
    except Exception as e:
        latency_ms = (time.perf_counter() - start_time) * 1000
        logger.error(
            "Request failed",
            exc_info=True,
            extra={
                "method": request.method,
                "path": request.url.path,
                "latency_ms": round(latency_ms, 2),
                "error_type": type(e).__name__,
            }
        )
        raise


@app.post("/predict")
def predict(request: PredictionRequest):
    """Make prediction with detailed logging."""
    logger.info(
        "Prediction requested",
        extra={"feature_count": len(request.features)}
    )
    
    try:
        # Validate features
        missing_features = model.check_missing_features(request.features)
        if missing_features:
            logger.warning(
                "Missing features",
                extra={"missing_features": missing_features}
            )
        
        # Make prediction
        result = model.predict(request.features)
        
        logger.info(
            "Prediction successful",
            extra={
                "prediction": result["prediction"],
                "confidence": result["confidence"],
                "model_version": model.version,
            }
        )
        
        # Check confidence
        if result["confidence"] < 0.7:
            logger.warning(
                "Low confidence prediction",
                extra={
                    "confidence": result["confidence"],
                    "threshold": 0.7,
                }
            )
        
        return result
    
    except ValueError as e:
        logger.error(
            "Invalid features",
            exc_info=True,
            extra={"error_message": str(e)}
        )
        raise
    
    except Exception as e:
        logger.error(
            "Prediction error",
            exc_info=True,
            extra={
                "error_type": type(e).__name__,
                "error_message": str(e),
            }
        )
        raise
```

---

## Hands-On Exercise

### Exercise 1: Install Loki

```bash
# Install Loki stack
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi

# Check pods
kubectl get pods -n monitoring | grep loki

# Add Loki data source to Grafana
# UI → Configuration → Data Sources → Add Loki
# URL: http://loki:3100
```

### Exercise 2: Configure Structured Logging

```python
# Add to src/churn_mlops/api/app.py
from churn_mlops.utils.logging_config import setup_logging, get_logger

setup_logging(level="INFO", structured=True)
logger = get_logger(__name__)

# Test logging
@app.get("/test-logs")
def test_logs():
    logger.info("Info log", extra={"custom_field": "value"})
    logger.warning("Warning log", extra={"threshold": 100})
    logger.error("Error log", extra={"error_code": 500})
    return {"status": "logged"}
```

### Exercise 3: Query Logs in Grafana

```bash
# Grafana → Explore → Loki

# Query 1: All app logs
{app="churn-api"}

# Query 2: Only errors
{app="churn-api"} | json | level="ERROR"

# Query 3: Specific request
{app="churn-api"} | json | request_id="abc-123"

# Query 4: Low confidence
{app="churn-api"} | json | confidence < 0.7

# Query 5: Error rate
sum(rate({app="churn-api"} | json | level="ERROR"[5m]))
```

### Exercise 4: Create Logs Panel

```bash
# Create dashboard with logs panel:
1. New Dashboard → Add Panel
2. Data source: Loki
3. Query: {app="churn-api"} | json
4. Visualization: Logs
5. Options:
   - Show time: Yes
   - Wrap lines: Yes
   - Show labels: request_id, level, message
6. Save panel
```

### Exercise 5: Set Up Log Alert

```bash
# Create alert rule:
1. Alerting → Alert rules → New alert rule
2. Query:
   sum(rate({app="churn-api"} | json | level="ERROR"[5m])) > 5
3. Condition: WHEN last() IS ABOVE 5
4. For: 2 minutes
5. Contact point: Slack/Email
6. Save
```

---

## Assessment Questions

### Question 1: Multiple Choice
What's the main difference between Loki and Elasticsearch for logging?

A) Loki is faster  
B) **Loki indexes only labels, not full content** ✅  
C) Loki supports more languages  
D) Loki has better UI  

---

### Question 2: True/False
**Statement**: LogQL queries can aggregate logs into metrics (e.g., count errors per minute).

**Answer**: True ✅  
**Explanation**: LogQL supports metric queries like `rate()`, `sum()`, `count_over_time()` to convert log streams into metrics, enabling log-based alerts and visualizations.

---

### Question 3: Short Answer
Why is structured (JSON) logging better than plain text logs?

**Answer**:
1. **Queryable fields**: Can filter by `level="ERROR"` or `confidence < 0.7`
2. **Consistent format**: Easier to parse programmatically
3. **Rich context**: Include request_id, user, model_version in every log
4. **Aggregation**: Calculate metrics from log fields
5. **Indexing**: Loki/ELK can index specific fields efficiently

---

### Question 4: Code Analysis
What does this LogQL query return?

```logql
topk(5,
  sum by(error_type) (
    rate({app="churn-api"} | json | level="ERROR"[1h])
  )
)
```

**Answer**:
- **Top 5 error types** by frequency in the last hour
- Groups errors by `error_type` field from JSON logs
- Calculates rate (errors/sec) for each type
- Returns 5 most frequent error types
- Example output: `ValueError: 2.3/sec`, `KeyError: 1.8/sec`, ...

---

### Question 5: Design Challenge
Design a logging strategy for ML prediction debugging.

**Answer**:

```python
# Logging levels:
# INFO - Normal operations
# WARNING - Potential issues (low confidence, missing features)
# ERROR - Failures

# Required fields in every log:
{
  "timestamp": "ISO8601",
  "level": "INFO|WARNING|ERROR",
  "request_id": "UUID",  # Trace request flow
  "user_id": "string",   # User tracking
  "model_version": "v1.2.3",  # Model tracking
  "message": "descriptive text"
}

# Prediction flow logs:
1. Request received:
   {"message": "Prediction requested", "feature_count": 15}

2. Feature validation:
   {"message": "Features validated", "missing_features": []}
   OR {"level": "WARNING", "message": "Missing features", "missing": ["age"]}

3. Model inference:
   {"message": "Model inference started", "model_version": "v1.2.3"}

4. Prediction result:
   {
     "message": "Prediction successful",
     "prediction": "churn",
     "confidence": 0.87,
     "latency_ms": 45.3
   }

5. Low confidence warning:
   If confidence < 0.7:
   {
     "level": "WARNING",
     "message": "Low confidence prediction",
     "confidence": 0.62,
     "threshold": 0.7
   }

# Error handling:
6. Prediction failure:
   {
     "level": "ERROR",
     "message": "Prediction failed",
     "error_type": "ValueError",
     "error_message": "Invalid feature format",
     "exception": "full traceback"
   }

# LogQL queries for debugging:
# Find failed requests:
{app="churn-api"} | json | level="ERROR"

# Find specific request:
{app="churn-api"} | json | request_id="abc-123"

# Find low confidence:
{app="churn-api"} | json | confidence < 0.7

# Error rate by type:
sum by(error_type) (rate({app="churn-api"} | json | level="ERROR"[5m]))
```

---

## Key Takeaways

### ✅ What You Learned

1. **Observability Pillars**
   - Metrics (what)
   - Logs (why)
   - Traces (how)

2. **Grafana Loki**
   - Label-based indexing
   - Cost-effective storage
   - Prometheus-like queries

3. **Structured Logging**
   - JSON format
   - Queryable fields
   - Context propagation (request_id)

4. **LogQL**
   - Label filters
   - JSON parsing
   - Aggregations
   - Metric queries from logs

5. **Log-Metric Correlation**
   - Split views
   - Data links
   - Combined dashboards

---

## Next Steps

Continue to **[Section 29: Alerting and Incident Response](./section-29-alerting-incident-response.md)**

In the next section, we'll:
- Configure Alertmanager
- Create alert rules
- Set up notification channels (Slack, email)
- Define SLOs/SLIs
- Build runbooks

---

## Additional Resources

- [Grafana Loki Documentation](https://grafana.com/docs/loki/)
- [LogQL Reference](https://grafana.com/docs/loki/latest/logql/)
- [Structured Logging Best Practices](https://www.structlog.org/)
- [Python Logging Cookbook](https://docs.python.org/3/howto/logging-cookbook.html)

---

**Progress**: 26/34 sections complete (76%) → **27/34 (79%)**
