# Section 27: Grafana Dashboards and Visualization

**Duration**: 2.5 hours  
**Level**: Intermediate  
**Prerequisites**: Section 26 (Prometheus Metrics)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Install and configure Grafana in Kubernetes
- ✅ Connect Grafana to Prometheus data source
- ✅ Create custom dashboards for ML monitoring
- ✅ Build visualization panels (graphs, gauges, tables)
- ✅ Use dashboard variables and templating
- ✅ Set up dashboard alerts
- ✅ Export and version control dashboards

---

## 📚 Table of Contents

1. [What is Grafana?](#what-is-grafana)
2. [Installing Grafana](#installing-grafana)
3. [Connecting Data Sources](#connecting-data-sources)
4. [Dashboard Basics](#dashboard-basics)
5. [Creating Panels](#creating-panels)
6. [Variables and Templating](#variables-and-templating)
7. [ML-Specific Dashboards](#ml-specific-dashboards)
8. [Dashboard as Code](#dashboard-as-code)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## What is Grafana?

> **Grafana**: Open-source analytics and visualization platform for monitoring time-series data

```
Data Flow:
Prometheus (metrics) → Grafana (visualization) → Dashboard (insights)
```

### Key Features

| Feature | Description |
|---------|-------------|
| **Multi-data source** | Prometheus, Loki, PostgreSQL, etc. |
| **Rich visualizations** | Graphs, gauges, heatmaps, tables |
| **Templating** | Dynamic dashboards with variables |
| **Alerting** | Alert on metric thresholds |
| **Sharing** | Export/import JSON dashboards |
| **Permissions** | Role-based access control |

### Why Grafana for MLOps?

```
MLOps Dashboard Needs:

📊 Real-time Monitoring:
- API request rate & latency
- Prediction throughput
- Error rates

🤖 Model Performance:
- Inference time
- Confidence scores
- Model version tracking

📈 Data Quality:
- Feature distributions
- Drift detection
- Missing values

🚨 Alerting:
- High latency warnings
- Low confidence alerts
- Data drift notifications
```

---

## Installing Grafana

### Using Helm (kube-prometheus-stack)

Grafana is included in the kube-prometheus-stack:

```bash
# Already installed with Prometheus
helm list -n monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Get admin password
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d

# Open browser: http://localhost:3000
# Username: admin
# Password: <from command above>
```

### Standalone Installation

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Grafana
helm install grafana grafana/grafana \
  --namespace monitoring \
  --set adminPassword=admin \
  --set service.type=LoadBalancer

# Check installation
kubectl get pods -n monitoring
```

### Configuration

```yaml
# grafana-values.yaml
persistence:
  enabled: true
  size: 10Gi

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-kube-prometheus-prometheus:9090
        access: proxy
        isDefault: true

dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default

dashboards:
  default:
    churn-api:
      json: |
        # Dashboard JSON here

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

---

## Connecting Data Sources

### Add Prometheus Data Source

```bash
# Via UI:
1. Configuration (⚙️) → Data Sources
2. Add data source
3. Select "Prometheus"
4. Configure:
   - URL: http://prometheus-kube-prometheus-prometheus:9090
   - Access: Server (default)
5. Save & Test
```

### Data Source Configuration (JSON)

```json
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "http://prometheus-kube-prometheus-prometheus:9090",
  "access": "proxy",
  "basicAuth": false,
  "isDefault": true,
  "jsonData": {
    "httpMethod": "POST",
    "timeInterval": "30s"
  }
}
```

### Test Connection

```bash
# Query test
PromQL: up
Result: Should show all targets with up=1
```

---

## Dashboard Basics

### Creating a Dashboard

```
1. Dashboard → New Dashboard
2. Add panel
3. Configure:
   - Query (PromQL)
   - Visualization type
   - Panel title
   - Legend
4. Save dashboard
```

### Dashboard Structure

```
Dashboard
├── Variables (dropdowns for filtering)
├── Rows (organize panels)
└── Panels (visualizations)
    ├── Time series (graphs)
    ├── Gauge (current value)
    ├── Stat (single number)
    ├── Table (tabular data)
    ├── Heatmap (distribution over time)
    └── Bar chart
```

### Dashboard JSON

```json
{
  "dashboard": {
    "title": "Churn API Monitoring",
    "uid": "churn-api",
    "timezone": "browser",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(churn_api_requests_total[5m])",
            "legendFormat": "{{method}} {{path}}"
          }
        ]
      }
    ]
  }
}
```

---

## Creating Panels

### 1. Time Series Panel (Graphs)

**Use case**: Show metrics over time

```
Panel Configuration:
- Title: "Request Rate"
- Visualization: Time series
- Query: rate(churn_api_requests_total[5m])
- Legend: {{method}} {{path}} - {{status}}

Display:
- Line width: 2
- Fill opacity: 10
- Gradient mode: Opacity
- Show points: Never
- Line interpolation: Linear
```

**PromQL Example**:
```promql
# Request rate by endpoint
sum by(path) (rate(churn_api_requests_total[5m]))
```

### 2. Gauge Panel

**Use case**: Show current value with thresholds

```
Panel Configuration:
- Title: "Active Requests"
- Visualization: Gauge
- Query: churn_api_active_requests

Thresholds:
- Green: 0-50
- Yellow: 51-100
- Red: >100

Display:
- Show threshold labels: Yes
- Show threshold markers: Yes
```

### 3. Stat Panel (Single Number)

**Use case**: Display single metric prominently

```
Panel Configuration:
- Title: "Total Predictions (Last Hour)"
- Visualization: Stat
- Query: increase(churn_api_predictions_total[1h])

Value:
- Font size: 80
- Color mode: Value
- Graph mode: Area (sparkline)

Thresholds:
- Green: >1000
- Yellow: 500-1000
- Red: <500
```

### 4. Table Panel

**Use case**: Show multiple metrics in rows

```
Panel Configuration:
- Title: "Endpoint Statistics"
- Visualization: Table
- Queries:
  1. sum by(path) (rate(churn_api_requests_total[5m]))
  2. histogram_quantile(0.95, rate(churn_api_request_latency_seconds_bucket[5m]))

Columns:
- Path
- Requests/sec
- P95 Latency
```

### 5. Heatmap Panel

**Use case**: Show distribution over time

```
Panel Configuration:
- Title: "Latency Distribution"
- Visualization: Heatmap
- Query: rate(churn_api_request_latency_seconds_bucket[5m])

Settings:
- Data format: Time series buckets
- Y-axis: Latency (seconds)
- Color scheme: Spectral
```

---

## Variables and Templating

### Dashboard Variables

Variables make dashboards dynamic and reusable:

```
Variable Types:
1. Query: From Prometheus labels
2. Constant: Fixed value
3. Interval: Time range
4. Custom: Manual list
5. Data source: Select data source
```

### Creating Variables

**Example 1: Environment Variable**

```
Name: environment
Type: Query
Data source: Prometheus
Query: label_values(churn_api_requests_total, environment)
Refresh: On dashboard load
Multi-value: No
Include All option: Yes
```

**Example 2: Namespace Variable**

```
Name: namespace
Type: Query
Query: label_values(kube_pod_info, namespace)
Regex: churn.*
Sort: Alphabetical (asc)
```

**Example 3: Endpoint Variable**

```
Name: endpoint
Type: Query
Query: label_values(churn_api_requests_total{namespace="$namespace"}, path)
Multi-value: Yes
Include All option: Yes
```

### Using Variables in Queries

```promql
# Without variables
rate(churn_api_requests_total{namespace="churn-mlops", path="/predict"}[5m])

# With variables
rate(churn_api_requests_total{namespace="$namespace", path=~"$endpoint"}[5m])

# Variable syntax:
# $variable       → Single value
# ${variable}     → Single value (explicit)
# ${variable:csv} → Comma-separated list
# ${variable:pipe} → Pipe-separated regex (path1|path2|path3)
```

### Advanced Templating

```promql
# Multi-select endpoint variable
sum by(path) (
  rate(churn_api_requests_total{path=~"$endpoint"}[5m])
)

# Dynamic aggregation
$aggregation by($group_by) (
  rate(churn_api_requests_total[5m])
)

# Where:
# $aggregation variable: sum, avg, max, min
# $group_by variable: path, method, status
```

---

## ML-Specific Dashboards

### Churn API Performance Dashboard

```json
{
  "dashboard": {
    "title": "Churn API - Performance",
    "uid": "churn-api-performance",
    "panels": [
      {
        "id": 1,
        "title": "Requests per Second",
        "type": "timeseries",
        "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "sum(rate(churn_api_requests_total[5m]))",
            "legendFormat": "Total RPS"
          }
        ]
      },
      {
        "id": 2,
        "title": "P95 Latency",
        "type": "timeseries",
        "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(churn_api_request_latency_seconds_bucket[5m]))",
            "legendFormat": "P95"
          },
          {
            "expr": "histogram_quantile(0.99, rate(churn_api_request_latency_seconds_bucket[5m]))",
            "legendFormat": "P99"
          }
        ]
      },
      {
        "id": 3,
        "title": "Error Rate",
        "type": "timeseries",
        "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "sum(rate(churn_api_requests_total{status=~\"5..\"}[5m])) / sum(rate(churn_api_requests_total[5m])) * 100",
            "legendFormat": "5xx Error %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 1, "color": "yellow"},
                {"value": 5, "color": "red"}
              ]
            }
          }
        }
      },
      {
        "id": 4,
        "title": "Active Requests",
        "type": "gauge",
        "gridPos": {"x": 12, "y": 8, "w": 6, "h": 8},
        "targets": [
          {
            "expr": "churn_api_active_requests"
          }
        ]
      },
      {
        "id": 5,
        "title": "Predictions per Minute",
        "type": "stat",
        "gridPos": {"x": 18, "y": 8, "w": 6, "h": 8},
        "targets": [
          {
            "expr": "rate(churn_api_predictions_total[5m]) * 60"
          }
        ]
      }
    ]
  }
}
```

### ML Model Monitoring Dashboard

```
Dashboard Panels:

Row 1: Throughput
┌────────────────────────┬────────────────────────┐
│ Predictions/sec        │ Prediction Latency P95 │
│ (Time series)          │ (Time series)          │
└────────────────────────┴────────────────────────┘

Row 2: Model Performance
┌────────────────────────┬────────────────────────┐
│ Average Confidence     │ Low Confidence Count   │
│ (Gauge)                │ (Stat)                 │
└────────────────────────┴────────────────────────┘

Row 3: Data Quality
┌────────────────────────┬────────────────────────┐
│ Data Drift Score       │ Missing Features       │
│ (Time series)          │ (Table)                │
└────────────────────────┴────────────────────────┘

Row 4: Model Versions
┌─────────────────────────────────────────────────┐
│ Predictions by Model Version                    │
│ (Stacked area chart)                            │
└─────────────────────────────────────────────────┘
```

**Panel Queries**:

```promql
# Predictions per second
rate(churn_api_predictions_total[5m])

# Prediction latency P95
histogram_quantile(0.95, rate(churn_api_prediction_latency_seconds_bucket[5m]))

# Average confidence
avg(churn_api_model_confidence)

# Low confidence predictions
sum(rate(churn_api_low_confidence_predictions_total[5m]))

# Data drift score
churn_data_drift_score

# Missing features
sum by(feature) (rate(churn_missing_features_total[5m]))

# Predictions by version
sum by(version) (rate(churn_api_predictions_total[5m]))
```

### Infrastructure Dashboard

```
Panels:

1. CPU Usage
Query: rate(container_cpu_usage_seconds_total{namespace="churn-mlops"}[5m])
Visualization: Time series

2. Memory Usage
Query: container_memory_usage_bytes{namespace="churn-mlops"} / 1024^3
Visualization: Time series
Unit: GB

3. Pod Restarts
Query: rate(kube_pod_container_status_restarts_total{namespace="churn-mlops"}[5m])
Visualization: Table

4. Network I/O
Query: rate(container_network_receive_bytes_total{namespace="churn-mlops"}[5m])
Visualization: Time series
Unit: Bps
```

---

## Dashboard as Code

### Exporting Dashboards

```bash
# Via UI:
Dashboard → Share → Export → Save to file

# Via API:
curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
  http://localhost:3000/api/dashboards/uid/churn-api > dashboard.json
```

### Importing Dashboards

```bash
# Via UI:
Dashboard → Import → Upload JSON file

# Via API:
curl -X POST \
  -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -H "Content-Type: application/json" \
  -d @dashboard.json \
  http://localhost:3000/api/dashboards/db
```

### Dashboard ConfigMap

```yaml
# k8s/monitoring/grafana-dashboard-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: churn-api-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  churn-api.json: |
    {
      "dashboard": {
        "title": "Churn API Monitoring",
        "uid": "churn-api",
        "panels": [
          ...
        ]
      }
    }
```

### Grafana Dashboard Provisioning

```yaml
# grafana-dashboards-values.yaml
dashboards:
  default:
    churn-api-performance:
      url: https://raw.githubusercontent.com/.../churn-api-dashboard.json
    
    churn-ml-monitoring:
      gnetId: 12345  # Grafana.com dashboard ID
      revision: 1
      datasource: Prometheus
```

---

## Hands-On Exercise

### Exercise 1: Create Basic Dashboard

```bash
# 1. Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# 2. Login (admin / <password>)

# 3. Create dashboard:
- New Dashboard → Add Panel
- Query: rate(churn_api_requests_total[5m])
- Title: "Request Rate"
- Legend: {{method}} {{path}}
- Save dashboard: "Churn API Monitoring"
```

### Exercise 2: Add Variables

```bash
# Add namespace variable:
1. Dashboard settings (⚙️)
2. Variables → Add variable
3. Name: namespace
4. Type: Query
5. Query: label_values(churn_api_requests_total, namespace)
6. Update

# Add endpoint variable:
1. Add variable
2. Name: endpoint
3. Query: label_values(churn_api_requests_total{namespace="$namespace"}, path)
4. Multi-value: Yes
5. Include All: Yes

# Update panel query:
rate(churn_api_requests_total{namespace="$namespace", path=~"$endpoint"}[5m])
```

### Exercise 3: Create ML Dashboard

```bash
# Create new dashboard with 5 panels:

# Panel 1: Predictions per Second
Query: rate(churn_api_predictions_total[5m])
Type: Time series

# Panel 2: P95 Prediction Latency
Query: histogram_quantile(0.95, rate(churn_api_prediction_latency_seconds_bucket[5m]))
Type: Time series
Unit: seconds

# Panel 3: Active Requests
Query: churn_api_active_requests
Type: Gauge
Thresholds: 0-50 (green), 51-100 (yellow), >100 (red)

# Panel 4: Error Rate
Query: sum(rate(churn_api_requests_total{status=~"5.."}[5m])) / sum(rate(churn_api_requests_total[5m])) * 100
Type: Stat
Unit: percent

# Panel 5: Total Predictions (1h)
Query: increase(churn_api_predictions_total[1h])
Type: Stat
```

### Exercise 4: Set Up Alerts

```bash
# Create alert in panel:
1. Edit panel
2. Alert tab
3. Create alert rule
4. Condition:
   - WHEN: avg() OF query(A, 5m, now)
   - IS ABOVE: 100
5. Contact point: Email/Slack
6. Save
```

### Exercise 5: Export and Version Control

```bash
# Export dashboard
curl -H "Authorization: Bearer $API_KEY" \
  http://localhost:3000/api/dashboards/uid/churn-api \
  | jq '.dashboard' > churn-api-dashboard.json

# Add to Git
git add k8s/monitoring/dashboards/churn-api-dashboard.json
git commit -m "Add Churn API dashboard"
git push

# Import in another environment
kubectl create configmap churn-api-dashboard \
  --from-file=churn-api-dashboard.json \
  -n monitoring \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## Assessment Questions

### Question 1: Multiple Choice
Which panel type is best for showing the current number of active requests?

A) Time series  
B) Table  
C) **Gauge** ✅  
D) Heatmap  

---

### Question 2: True/False
**Statement**: Grafana can only connect to Prometheus as a data source.

**Answer**: False ❌  
**Explanation**: Grafana supports multiple data sources including Prometheus, Loki, PostgreSQL, InfluxDB, Elasticsearch, and many more.

---

### Question 3: Short Answer
What's the difference between a Stat panel and a Time series panel?

**Answer**:
- **Stat panel**: Shows a **single current value** prominently (e.g., "Total: 1,523"). Optional sparkline. Used for KPIs.
- **Time series panel**: Shows **metric evolution over time** as a graph. Used for trends and patterns.

---

### Question 4: Code Analysis
What does this variable configuration do?

```
Name: endpoint
Query: label_values(churn_api_requests_total{namespace="$namespace"}, path)
Multi-value: Yes
Include All: Yes
```

**Answer**:
- Creates dropdown variable named `endpoint`
- Populates values from `path` label of matching metrics
- Filters by previously selected `namespace` variable
- Allows selecting **multiple endpoints** at once
- Includes "All" option to select everything
- Used in queries as: `path=~"$endpoint"`

---

### Question 5: Design Challenge
Design a dashboard for ML model monitoring with 4 key metrics.

**Answer**:

```
Dashboard: ML Model Health

Row 1: Throughput
┌──────────────────────┬──────────────────────┐
│ Predictions/sec      │ Prediction Latency   │
│ (Time series)        │ (Time series - P95)  │
│ rate(predictions[5m])│ histogram_quantile   │
└──────────────────────┴──────────────────────┘

Row 2: Quality
┌──────────────────────┬──────────────────────┐
│ Avg Confidence       │ Low Confidence %     │
│ (Gauge: 0-1)         │ (Stat with trend)    │
│ avg(confidence)      │ (confidence < 0.7)   │
└──────────────────────┴──────────────────────┘

Row 3: Data Health
┌──────────────────────┬──────────────────────┐
│ Data Drift Score     │ Missing Features     │
│ (Time series)        │ (Table by feature)   │
│ data_drift_score     │ sum by(feature)      │
└──────────────────────┴──────────────────────┘

Row 4: Versions
┌────────────────────────────────────────────┐
│ Predictions by Model Version               │
│ (Stacked area chart)                       │
│ sum by(version) (rate(predictions[5m]))    │
└────────────────────────────────────────────┘

Variables:
- environment: prod, stage, dev
- model_version: v1.0.0, v1.1.0, v1.2.0
- time_range: 5m, 15m, 1h, 6h, 24h

Alerts:
- P95 latency > 500ms (Warning)
- Error rate > 1% (Critical)
- Data drift score > 0.3 (Warning)
- Low confidence > 10% (Warning)
```

---

## Key Takeaways

### ✅ What You Learned

1. **Grafana Basics**
   - Installation with Helm
   - Data source configuration
   - Dashboard structure

2. **Panels**
   - Time series (trends)
   - Gauge (current value with thresholds)
   - Stat (single number)
   - Table (multiple metrics)
   - Heatmap (distributions)

3. **Variables**
   - Query-based variables
   - Multi-select
   - Using in PromQL queries

4. **ML Dashboards**
   - API performance monitoring
   - Model metrics tracking
   - Data quality visualization

5. **Dashboard as Code**
   - Export/import JSON
   - ConfigMaps for provisioning
   - Version control

---

## Next Steps

Continue to **[Section 28: Logging with Loki](./section-28-logging-loki.md)**

In the next section, we'll:
- Install Grafana Loki for log aggregation
- Configure structured logging
- Query logs with LogQL
- Correlate logs with metrics

---

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
- [Panel Examples](https://play.grafana.org/)
- [Community Dashboards](https://grafana.com/grafana/dashboards/)

---

**Progress**: 25/34 sections complete (74%) → **26/34 (76%)**
