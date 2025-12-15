# Section 29: Alerting and Incident Response

**Duration**: 2.5 hours  
**Level**: Intermediate  
**Prerequisites**: Section 26-28 (Prometheus, Grafana, Loki)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Configure Prometheus Alertmanager
- ✅ Create alert rules for ML systems
- ✅ Set up notification channels (Slack, email, PagerDuty)
- ✅ Define SLIs, SLOs, and SLAs
- ✅ Build incident runbooks
- ✅ Implement alert grouping and routing
- ✅ Handle alert fatigue

---

## 📚 Table of Contents

1. [Alerting Fundamentals](#alerting-fundamentals)
2. [Prometheus Alertmanager](#prometheus-alertmanager)
3. [Alert Rules](#alert-rules)
4. [Notification Channels](#notification-channels)
5. [SLIs, SLOs, and SLAs](#slis-slos-and-slas)
6. [Alert Design Patterns](#alert-design-patterns)
7. [Incident Response](#incident-response)
8. [Runbooks](#runbooks)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## Alerting Fundamentals

### Why Alerting?

```
Without Alerts:
😴 System degrading → No notification → Users complain → Reactive fix
   (Detection delay: hours or days)

With Alerts:
🚨 System degrading → Alert → Proactive investigation → Fix before impact
   (Detection delay: minutes)
```

### Good Alerts vs Bad Alerts

| Good Alert | Bad Alert |
|------------|-----------|
| **Actionable**: Clear what to do | **Vague**: "Something is wrong" |
| **High signal**: Real issues | **Noisy**: False positives |
| **Urgent**: Needs immediate action | **Informational**: FYI only |
| **Context**: Includes debug links | **No context**: Just a number |
| **Appropriate severity**: Critical/Warning | **Always critical**: Alert fatigue |

### Alert Severity Levels

```
🔴 CRITICAL (P0)
- User-facing outage
- Data loss
- Security breach
Action: Wake up on-call engineer
Example: API down, 50% error rate

🟠 WARNING (P1)
- Degraded performance
- Approaching thresholds
- Non-critical failure
Action: Notify during business hours
Example: High latency, low confidence predictions

🟡 INFO (P2)
- Anomaly detected
- Maintenance needed
Action: Log for review
Example: Increased traffic, model drift detected
```

### Alert Lifecycle

```
┌──────────────────────────────────────────────────┐
│  Alert Lifecycle                                  │
├──────────────────────────────────────────────────┤
│                                                   │
│  1. PENDING                                       │
│     Condition met, waiting for "for" duration    │
│     ↓                                             │
│  2. FIRING                                        │
│     Alert active, notifications sent              │
│     ↓                                             │
│  3. ACKNOWLEDGED (optional)                       │
│     Engineer notified, investigating              │
│     ↓                                             │
│  4. RESOLVED                                      │
│     Condition no longer met                       │
│     ↓                                             │
│  5. RESOLVED NOTIFICATION                         │
│     Confirm issue fixed                           │
│                                                   │
└──────────────────────────────────────────────────┘
```

---

## Prometheus Alertmanager

### Architecture

```
┌────────────────────────────────────────────────┐
│  Alerting Architecture                          │
├────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────────────────────────────┐  │
│  │  Prometheus                              │  │
│  │  - Evaluates alert rules                 │  │
│  │  - Sends alerts to Alertmanager          │  │
│  └─────────────────────────────────────────┘  │
│                    ↓                            │
│  ┌─────────────────────────────────────────┐  │
│  │  Alertmanager                            │  │
│  │  - Groups alerts                         │  │
│  │  - Deduplicates                          │  │
│  │  - Routes to receivers                   │  │
│  │  - Silences                              │  │
│  └─────────────────────────────────────────┘  │
│                    ↓                            │
│  ┌─────────────────────────────────────────┐  │
│  │  Receivers                               │  │
│  │  - Slack                                 │  │
│  │  - Email                                 │  │
│  │  - PagerDuty                             │  │
│  │  - Webhook                               │  │
│  └─────────────────────────────────────────┘  │
│                                                 │
└────────────────────────────────────────────────┘
```

### Configuration

```yaml
# alertmanager-config.yaml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

# Group alerts by these labels
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s        # Wait before sending initial notification
  group_interval: 10s    # Wait before sending more from same group
  repeat_interval: 12h   # Re-send after this time if still firing
  receiver: 'default'
  
  routes:
    # Critical alerts to PagerDuty
    - match:
        severity: critical
      receiver: pagerduty
      continue: true  # Also send to other receivers
    
    # ML-specific alerts to ML team
    - match_re:
        alertname: (DataDrift|LowConfidence|ModelError)
      receiver: ml-team-slack
    
    # Infrastructure alerts to ops team
    - match_re:
        alertname: (HighCPU|HighMemory|PodDown)
      receiver: ops-team-slack
    
    # Warning alerts to email (business hours only)
    - match:
        severity: warning
      receiver: email
      active_time_intervals:
        - business_hours

# Notification channels
receivers:
  - name: 'default'
    slack_configs:
      - channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
  
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
        description: '{{ .GroupLabels.alertname }}: {{ .GroupLabels.instance }}'
  
  - name: 'ml-team-slack'
    slack_configs:
      - channel: '#ml-alerts'
        color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
        title: '🤖 ML Alert: {{ .GroupLabels.alertname }}'
        text: |
          *Status:* {{ .Status }}
          *Severity:* {{ .CommonLabels.severity }}
          {{ range .Alerts }}
          *Description:* {{ .Annotations.description }}
          *Runbook:* {{ .Annotations.runbook_url }}
          {{ end }}
  
  - name: 'ops-team-slack'
    slack_configs:
      - channel: '#ops-alerts'
        title: '⚙️ Infrastructure Alert: {{ .GroupLabels.alertname }}'
  
  - name: 'email'
    email_configs:
      - to: 'team@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alerts@example.com'
        auth_password: 'YOUR_PASSWORD'

# Time intervals
time_intervals:
  - name: business_hours
    time_intervals:
      - times:
          - start_time: '09:00'
            end_time: '17:00'
        weekdays: ['monday:friday']

# Inhibition rules (suppress alerts)
inhibit_rules:
  # If cluster is down, don't alert on individual pods
  - source_match:
      alertname: 'ClusterDown'
    target_match:
      alertname: 'PodDown'
    equal: ['cluster']
  
  # If API is down, don't alert on high latency
  - source_match:
      alertname: 'APIDown'
    target_match:
      alertname: 'HighLatency'
    equal: ['service']
```

### Deploying Alertmanager

```bash
# Already installed with kube-prometheus-stack
kubectl get pods -n monitoring | grep alertmanager

# Update configuration
kubectl create secret generic alertmanager-config \
  --from-file=alertmanager.yaml=alertmanager-config.yaml \
  -n monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Alertmanager
kubectl rollout restart statefulset alertmanager-prometheus-kube-prometheus-alertmanager \
  -n monitoring
```

---

## Alert Rules

### Alert Rule Structure

```yaml
groups:
  - name: group_name
    interval: 30s  # How often to evaluate
    rules:
      - alert: AlertName
        expr: PromQL expression
        for: 5m  # Duration before firing
        labels:
          severity: warning|critical
          team: ml|ops
        annotations:
          summary: Short description
          description: Detailed description with {{ $value }}
          runbook_url: https://runbooks.example.com/AlertName
```

### API Alerts

```yaml
# k8s/monitoring/alert-rules-api.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: churn-api-alerts
  namespace: churn-mlops
  labels:
    prometheus: kube-prometheus
spec:
  groups:
    - name: churn_api
      interval: 30s
      rules:
        # API is down
        - alert: ChurnAPIDown
          expr: up{job="churn-api"} == 0
          for: 1m
          labels:
            severity: critical
            team: ops
          annotations:
            summary: "Churn API is down"
            description: "Churn API has been down for more than 1 minute"
            runbook_url: "https://runbooks.example.com/ChurnAPIDown"
        
        # High error rate
        - alert: HighErrorRate
          expr: |
            (
              sum(rate(churn_api_requests_total{status=~"5.."}[5m]))
              /
              sum(rate(churn_api_requests_total[5m]))
            ) * 100 > 5
          for: 5m
          labels:
            severity: critical
            team: ops
          annotations:
            summary: "High error rate on Churn API"
            description: "Error rate is {{ $value | humanizePercentage }} (threshold: 5%)"
            runbook_url: "https://runbooks.example.com/HighErrorRate"
        
        # High latency
        - alert: HighLatency
          expr: |
            histogram_quantile(0.95,
              rate(churn_api_request_latency_seconds_bucket[5m])
            ) > 0.5
          for: 10m
          labels:
            severity: warning
            team: ops
          annotations:
            summary: "High P95 latency on Churn API"
            description: "P95 latency is {{ $value | humanizeDuration }} (threshold: 500ms)"
            runbook_url: "https://runbooks.example.com/HighLatency"
        
        # Low throughput (potential issue)
        - alert: LowThroughput
          expr: |
            sum(rate(churn_api_predictions_total[5m])) < 1
          for: 15m
          labels:
            severity: warning
            team: ml
          annotations:
            summary: "Low prediction throughput"
            description: "Prediction rate is {{ $value | humanize }} req/s (threshold: 1 req/s)"
            runbook_url: "https://runbooks.example.com/LowThroughput"
```

### ML Model Alerts

```yaml
# k8s/monitoring/alert-rules-ml.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: churn-ml-alerts
  namespace: churn-mlops
  labels:
    prometheus: kube-prometheus
spec:
  groups:
    - name: churn_ml
      interval: 30s
      rules:
        # Low confidence predictions
        - alert: HighLowConfidencePredictions
          expr: |
            (
              sum(rate(churn_api_low_confidence_predictions_total[5m]))
              /
              sum(rate(churn_api_predictions_total[5m]))
            ) * 100 > 10
          for: 10m
          labels:
            severity: warning
            team: ml
          annotations:
            summary: "High rate of low-confidence predictions"
            description: "{{ $value | humanizePercentage }} of predictions have confidence < 0.7 (threshold: 10%)"
            runbook_url: "https://runbooks.example.com/LowConfidence"
        
        # Data drift detected
        - alert: DataDriftDetected
          expr: churn_data_drift_score > 0.3
          for: 5m
          labels:
            severity: warning
            team: ml
          annotations:
            summary: "Data drift detected"
            description: "Data drift score is {{ $value }} (threshold: 0.3)"
            runbook_url: "https://runbooks.example.com/DataDrift"
        
        # High prediction latency
        - alert: HighPredictionLatency
          expr: |
            histogram_quantile(0.95,
              rate(churn_api_prediction_latency_seconds_bucket[5m])
            ) > 0.1
          for: 10m
          labels:
            severity: warning
            team: ml
          annotations:
            summary: "High model inference latency"
            description: "P95 prediction latency is {{ $value | humanizeDuration }} (threshold: 100ms)"
            runbook_url: "https://runbooks.example.com/HighPredictionLatency"
        
        # Missing features
        - alert: HighMissingFeatureRate
          expr: |
            sum by(feature) (
              rate(churn_missing_features_total[5m])
            ) > 1
          for: 5m
          labels:
            severity: warning
            team: ml
          annotations:
            summary: "High rate of missing feature: {{ $labels.feature }}"
            description: "Feature {{ $labels.feature }} missing in {{ $value }} req/s"
            runbook_url: "https://runbooks.example.com/MissingFeatures"
        
        # Model not updated recently
        - alert: ModelNotUpdated
          expr: |
            (time() - churn_model_last_updated_timestamp) > 604800
          for: 1h
          labels:
            severity: info
            team: ml
          annotations:
            summary: "Model hasn't been updated in 7 days"
            description: "Last model update was {{ $value | humanizeDuration }} ago"
            runbook_url: "https://runbooks.example.com/ModelNotUpdated"
```

### Infrastructure Alerts

```yaml
# k8s/monitoring/alert-rules-infra.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: churn-infra-alerts
  namespace: churn-mlops
spec:
  groups:
    - name: churn_infrastructure
      interval: 30s
      rules:
        # High CPU
        - alert: HighCPU
          expr: |
            sum by(pod) (
              rate(container_cpu_usage_seconds_total{
                namespace="churn-mlops",
                container!=""
              }[5m])
            ) > 0.8
          for: 10m
          labels:
            severity: warning
            team: ops
          annotations:
            summary: "High CPU usage on {{ $labels.pod }}"
            description: "CPU usage is {{ $value | humanizePercentage }}"
        
        # High memory
        - alert: HighMemory
          expr: |
            sum by(pod) (
              container_memory_usage_bytes{
                namespace="churn-mlops",
                container!=""
              }
            ) / sum by(pod) (
              container_spec_memory_limit_bytes{
                namespace="churn-mlops",
                container!=""
              }
            ) > 0.9
          for: 5m
          labels:
            severity: warning
            team: ops
          annotations:
            summary: "High memory usage on {{ $labels.pod }}"
            description: "Memory usage is {{ $value | humanizePercentage }}"
        
        # Pod restart
        - alert: PodRestarting
          expr: |
            rate(kube_pod_container_status_restarts_total{
              namespace="churn-mlops"
            }[15m]) > 0
          for: 5m
          labels:
            severity: warning
            team: ops
          annotations:
            summary: "Pod {{ $labels.pod }} is restarting"
            description: "Pod has restarted {{ $value }} times in 15 minutes"
        
        # PVC almost full
        - alert: PVCAlmostFull
          expr: |
            (
              kubelet_volume_stats_used_bytes{
                namespace="churn-mlops"
              } /
              kubelet_volume_stats_capacity_bytes{
                namespace="churn-mlops"
              }
            ) > 0.85
          for: 5m
          labels:
            severity: warning
            team: ops
          annotations:
            summary: "PVC {{ $labels.persistentvolumeclaim }} is {{ $value | humanizePercentage }} full"
            description: "Consider increasing PVC size"
```

---

## Notification Channels

### Slack Integration

```yaml
# Slack webhook configuration
receivers:
  - name: 'slack-ml-team'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#ml-alerts'
        username: 'Alertmanager'
        icon_emoji: ':warning:'
        color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
        title: |
          [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .GroupLabels.alertname }}
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Labels.alertname }}
          *Severity:* {{ .Labels.severity }}
          *Description:* {{ .Annotations.description }}
          *Runbook:* {{ .Annotations.runbook_url }}
          {{ end }}
        send_resolved: true
```

**Slack message example**:
```
🚨 [FIRING:3] HighErrorRate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Alert: HighErrorRate
Severity: critical
Description: Error rate is 8.5% (threshold: 5%)
Runbook: https://runbooks.example.com/HighErrorRate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[View in Grafana] [View in Prometheus]
```

### Email Notifications

```yaml
receivers:
  - name: 'email-team'
    email_configs:
      - to: 'ml-team@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alerts@example.com'
        auth_password: 'YOUR_APP_PASSWORD'
        headers:
          Subject: '[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}'
        html: |
          <h2>{{ .GroupLabels.alertname }}</h2>
          <p><strong>Status:</strong> {{ .Status }}</p>
          {{ range .Alerts }}
          <h3>{{ .Labels.alertname }}</h3>
          <p><strong>Severity:</strong> {{ .Labels.severity }}</p>
          <p><strong>Description:</strong> {{ .Annotations.description }}</p>
          <p><a href="{{ .Annotations.runbook_url }}">Runbook</a></p>
          {{ end }}
```

### PagerDuty Integration

```yaml
receivers:
  - name: 'pagerduty-critical'
    pagerduty_configs:
      - routing_key: 'YOUR_PAGERDUTY_INTEGRATION_KEY'
        description: '{{ .GroupLabels.alertname }}: {{ .GroupLabels.instance }}'
        severity: '{{ .CommonLabels.severity }}'
        client: 'Prometheus Alertmanager'
        client_url: 'https://grafana.example.com'
        details:
          firing: '{{ .Alerts.Firing | len }}'
          resolved: '{{ .Alerts.Resolved | len }}'
          alertname: '{{ .GroupLabels.alertname }}'
          summary: '{{ .CommonAnnotations.summary }}'
```

### Custom Webhook

```yaml
receivers:
  - name: 'custom-webhook'
    webhook_configs:
      - url: 'https://api.example.com/alerts'
        send_resolved: true
        http_config:
          bearer_token: 'YOUR_TOKEN'
```

**Webhook payload**:
```json
{
  "receiver": "custom-webhook",
  "status": "firing",
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "HighErrorRate",
        "severity": "critical",
        "team": "ops"
      },
      "annotations": {
        "summary": "High error rate on Churn API",
        "description": "Error rate is 8.5% (threshold: 5%)",
        "runbook_url": "https://runbooks.example.com/HighErrorRate"
      },
      "startsAt": "2023-12-15T10:30:00Z",
      "endsAt": "0001-01-01T00:00:00Z",
      "fingerprint": "abc123def456"
    }
  ],
  "groupLabels": {"alertname": "HighErrorRate"},
  "commonLabels": {"severity": "critical"},
  "commonAnnotations": {},
  "externalURL": "http://alertmanager:9093"
}
```

---

## SLIs, SLOs, and SLAs

### Definitions

| Term | Definition | Example |
|------|------------|---------|
| **SLI** (Service Level Indicator) | Metric measuring service quality | Request success rate, latency |
| **SLO** (Service Level Objective) | Target for SLI | 99.9% success rate, P95 < 500ms |
| **SLA** (Service Level Agreement) | Contract with consequences | 99.5% uptime or refund |

### ML System SLIs

```yaml
# SLI definitions
slis:
  # Availability
  - name: prediction_availability
    description: "Percentage of successful prediction requests"
    query: |
      sum(rate(churn_api_requests_total{status=~"2.."}[5m]))
      /
      sum(rate(churn_api_requests_total[5m]))
    target: 0.999  # 99.9%
  
  # Latency
  - name: prediction_latency_p95
    description: "95th percentile prediction latency"
    query: |
      histogram_quantile(0.95,
        rate(churn_api_request_latency_seconds_bucket[5m])
      )
    target: 0.5  # 500ms
  
  - name: prediction_latency_p99
    description: "99th percentile prediction latency"
    query: |
      histogram_quantile(0.99,
        rate(churn_api_request_latency_seconds_bucket[5m])
      )
    target: 1.0  # 1 second
  
  # Throughput
  - name: prediction_throughput
    description: "Predictions per second"
    query: rate(churn_api_predictions_total[5m])
    target: 10  # minimum 10 req/s
  
  # Quality
  - name: prediction_confidence
    description: "Average prediction confidence"
    query: avg(churn_api_model_confidence)
    target: 0.8  # 80%
  
  # Data quality
  - name: data_completeness
    description: "Percentage of requests with complete features"
    query: |
      1 - (
        sum(rate(churn_missing_features_total[5m]))
        /
        sum(rate(churn_api_predictions_total[5m]))
      )
    target: 0.95  # 95%
```

### SLO-Based Alerts

```yaml
# Alert when SLO is at risk
groups:
  - name: slo_alerts
    interval: 30s
    rules:
      # Error budget: 0.1% (from 99.9% SLO)
      # Alert when burning through budget too fast
      - alert: ErrorBudgetBurn
        expr: |
          (
            1 - (
              sum(rate(churn_api_requests_total{status=~"2.."}[1h]))
              /
              sum(rate(churn_api_requests_total[1h]))
            )
          ) > 0.001
        for: 5m
        labels:
          severity: critical
          team: ops
        annotations:
          summary: "Burning error budget too fast"
          description: "Current error rate {{ $value | humanizePercentage }} exceeds 0.1% budget"
      
      # Multi-window burn rate
      - alert: ErrorBudgetBurnFast
        expr: |
          (
            sum(rate(churn_api_requests_total{status=~"5.."}[5m]))
            /
            sum(rate(churn_api_requests_total[5m]))
          ) > 0.001
          and
          (
            sum(rate(churn_api_requests_total{status=~"5.."}[1h]))
            /
            sum(rate(churn_api_requests_total[1h]))
          ) > 0.001
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Fast error budget burn"
          description: "Error rate above threshold in both 5m and 1h windows"
```

### Error Budget Tracking

```
Error Budget Calculation:

SLO: 99.9% availability over 30 days
Error budget: 100% - 99.9% = 0.1%

30 days = 30 × 24 × 60 = 43,200 minutes
Error budget = 43,200 × 0.001 = 43.2 minutes downtime allowed

Current month (15 days elapsed):
- Downtime so far: 15 minutes
- Budget used: 15 / 43.2 = 34.7%
- Budget remaining: 65.3%
- Projected: On track ✅

Dashboard panel query:
1 - (
  sum(increase(churn_api_requests_total{status=~"2.."}[30d]))
  /
  sum(increase(churn_api_requests_total[30d]))
)
```

---

## Alert Design Patterns

### 1. Symptom-Based Alerts

```yaml
# ✅ GOOD: Alert on symptoms (user impact)
- alert: HighLatency
  expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
  # Users are experiencing slow responses

# ❌ BAD: Alert on causes (infrastructure)
- alert: HighCPU
  expr: cpu_usage > 0.8
  # CPU high doesn't necessarily mean user impact
```

### 2. Threshold Selection

```yaml
# ✅ GOOD: Based on SLO
- alert: ErrorRateHigh
  expr: error_rate > 0.001  # 0.1% (from 99.9% SLO)

# ❌ BAD: Arbitrary threshold
- alert: SomeErrors
  expr: errors > 0  # Any error triggers alert
```

### 3. Appropriate "for" Duration

```yaml
# ✅ GOOD: Wait to avoid flapping
- alert: HighLatency
  expr: latency > 0.5
  for: 10m  # Sustained issue

# ❌ BAD: No "for" duration
- alert: HighLatency
  expr: latency > 0.5  # Triggers on every spike
```

### 4. Alert Grouping

```yaml
# ✅ GOOD: Group related alerts
route:
  group_by: ['alertname', 'cluster', 'service']
  # Sends one notification for multiple instances

# ❌ BAD: No grouping
route:
  group_by: []
  # Spam: 100 notifications for 100 pods
```

### 5. Alert Context

```yaml
# ✅ GOOD: Includes context and links
annotations:
  summary: "High error rate on {{ $labels.service }}"
  description: "Error rate is {{ $value | humanizePercentage }} (threshold: 5%)"
  dashboard_url: "https://grafana.example.com/d/api-overview"
  runbook_url: "https://runbooks.example.com/HighErrorRate"
  logs_url: "https://grafana.example.com/explore?left={\"datasource\":\"Loki\",\"queries\":[{\"expr\":\"{service=\\\"{{ $labels.service }}\\\"} |= \\\"error\\\"\"}]}"

# ❌ BAD: No context
annotations:
  summary: "Alert"
  # No information about what's wrong
```

---

## Incident Response

### Incident Workflow

```
1. DETECTION
   Alert fires → Notification sent
   ↓
2. TRIAGE
   On-call reviews → Assess severity → Escalate if needed
   ↓
3. INVESTIGATION
   Check dashboard → Query metrics/logs → Identify root cause
   ↓
4. MITIGATION
   Apply fix → Rollback → Scale resources
   ↓
5. RESOLUTION
   Confirm fix → Alert resolves → Notify stakeholders
   ↓
6. POST-MORTEM
   Document incident → Action items → Prevent recurrence
```

### Incident Severity

| Severity | Definition | Response Time | Example |
|----------|------------|---------------|---------|
| **SEV-1** | Critical user impact | Immediate | API down, data loss |
| **SEV-2** | Significant degradation | < 15 minutes | High latency, errors |
| **SEV-3** | Minor impact | < 1 hour | Non-critical feature broken |
| **SEV-4** | No user impact | Next business day | Monitoring gap, tech debt |

### On-Call Rotation

```yaml
# PagerDuty schedule example
schedules:
  - name: "ML Team Primary"
    time_zone: "America/New_York"
    layers:
      - rotation_virtual_start: "2023-12-01T00:00:00-05:00"
        rotation_turn_length_seconds: 604800  # 1 week
        users:
          - user: alice@example.com
          - user: bob@example.com
          - user: charlie@example.com
  
  - name: "ML Team Backup"
    time_zone: "America/New_York"
    layers:
      - rotation_virtual_start: "2023-12-01T00:00:00-05:00"
        rotation_turn_length_seconds: 604800
        users:
          - user: david@example.com
          - user: eve@example.com

escalation_policies:
  - name: "ML Escalation"
    escalation_rules:
      - escalation_delay_in_minutes: 15
        targets:
          - type: schedule
            id: "ML Team Primary"
      
      - escalation_delay_in_minutes: 15
        targets:
          - type: schedule
            id: "ML Team Backup"
      
      - escalation_delay_in_minutes: 30
        targets:
          - type: user
            id: "engineering-manager@example.com"
```

---

## Runbooks

### Runbook Template

```markdown
# Runbook: HighErrorRate

## Alert Details
- **Alert Name**: HighErrorRate
- **Severity**: Critical
- **Team**: Operations
- **SLO Impact**: Yes (affects 99.9% availability SLO)

## Symptoms
- Error rate > 5% for 5 minutes
- Users receiving 500 errors
- Increased latency

## Impact
- **User Impact**: HIGH - Users cannot get predictions
- **Business Impact**: HIGH - Revenue impact
- **SLO Impact**: Burns error budget rapidly

## Possible Causes
1. Application bug (recent deployment)
2. Database connection issues
3. Downstream service failure
4. Resource exhaustion (CPU/memory)
5. Network issues

## Investigation Steps

### 1. Check Grafana Dashboard
```bash
# Open dashboard
https://grafana.example.com/d/churn-api-overview

# Look for:
- Error rate spike
- Latency increase
- Resource usage
```

### 2. Check Recent Deployments
```bash
# List recent deployments
kubectl rollout history deployment churn-api -n churn-mlops

# Check current version
kubectl get deployment churn-api -n churn-mlops -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### 3. Check Application Logs
```bash
# In Grafana Explore (Loki)
{app="churn-api", level="ERROR"}

# Or via kubectl
kubectl logs -n churn-mlops deployment/churn-api --tail=100 --timestamps
```

### 4. Check Pod Status
```bash
# Check pod health
kubectl get pods -n churn-mlops -l app=churn-api

# Check events
kubectl get events -n churn-mlops --sort-by='.lastTimestamp'
```

### 5. Check Dependencies
```bash
# Check database connection
kubectl exec -n churn-mlops deployment/churn-api -- nc -zv postgres 5432

# Check model registry
kubectl exec -n churn-mlops deployment/churn-api -- curl -I http://mlflow:5000/health
```

## Mitigation Steps

### If Recent Deployment
```bash
# Rollback to previous version
kubectl rollout undo deployment churn-api -n churn-mlops

# Monitor error rate
watch 'kubectl top pods -n churn-mlops'
```

### If Resource Exhaustion
```bash
# Scale up replicas
kubectl scale deployment churn-api -n churn-mlops --replicas=6

# Or increase resources
kubectl set resources deployment churn-api -n churn-mlops \
  --limits=cpu=2000m,memory=2Gi \
  --requests=cpu=1000m,memory=1Gi
```

### If Database Issues
```bash
# Check database pod
kubectl get pods -n churn-mlops -l app=postgres

# Check database logs
kubectl logs -n churn-mlops -l app=postgres --tail=100

# Restart database (last resort)
kubectl rollout restart statefulset postgres -n churn-mlops
```

### If Bug in Code
```bash
# Apply hotfix
kubectl set image deployment/churn-api \
  churn-api=churn-api:hotfix-123 \
  -n churn-mlops

# Or disable problematic feature
kubectl set env deployment/churn-api \
  FEATURE_X_ENABLED=false \
  -n churn-mlops
```

## Verification
```bash
# Check error rate (should drop below 5%)
# Prometheus query:
sum(rate(churn_api_requests_total{status=~"5.."}[5m])) /
sum(rate(churn_api_requests_total[5m])) * 100

# Check alert status
# https://prometheus.example.com/alerts
# HighErrorRate should be "resolved"

# Test manually
curl -X POST https://api.example.com/predict \
  -H "Content-Type: application/json" \
  -d '{"features": {...}}'
```

## Communication Template
```
Incident Update - HighErrorRate

Status: [INVESTIGATING|IDENTIFIED|MONITORING|RESOLVED]
Impact: High error rate (X%) on Churn API
Users Affected: All prediction requests
ETA: [Time or "Unknown"]

Details:
[What happened and what we're doing]

Next Update: [Time]
```

## Post-Incident
- [ ] Write post-mortem
- [ ] Identify root cause
- [ ] Create action items (Jira tickets)
- [ ] Update runbook if needed
- [ ] Review and improve monitoring

## Related Runbooks
- [HighLatency](./HighLatency.md)
- [APIDown](./APIDown.md)
- [DatabaseConnectionError](./DatabaseConnectionError.md)

## Contact
- **Primary On-Call**: [PagerDuty rotation]
- **Escalation**: [Manager contact]
- **Slack**: #incidents
```

---

## Hands-On Exercise

### Exercise 1: Deploy Alert Rules

```bash
# Apply API alerts
kubectl apply -f k8s/monitoring/alert-rules-api.yaml

# Apply ML alerts
kubectl apply -f k8s/monitoring/alert-rules-ml.yaml

# Apply infra alerts
kubectl apply -f k8s/monitoring/alert-rules-infra.yaml

# Check rules loaded
kubectl get prometheusrules -n churn-mlops
```

### Exercise 2: Configure Slack Notifications

```bash
# Create Slack webhook: https://api.slack.com/messaging/webhooks

# Update Alertmanager config
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-config
  namespace: monitoring
stringData:
  alertmanager.yaml: |
    global:
      slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK'
    
    route:
      receiver: 'slack-notifications'
    
    receivers:
      - name: 'slack-notifications'
        slack_configs:
          - channel: '#alerts'
            title: '{{ .GroupLabels.alertname }}'
EOF

# Restart Alertmanager
kubectl rollout restart statefulset alertmanager-prometheus-kube-prometheus-alertmanager -n monitoring
```

### Exercise 3: Test Alert

```bash
# Trigger HighErrorRate alert by introducing errors
kubectl exec -n churn-mlops deployment/churn-api -- \
  curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"features": "invalid"}' \
  & # Repeat many times

# Check alert status
# Prometheus UI → Alerts
# Should see HighErrorRate in PENDING → FIRING

# Check Slack for notification
```

### Exercise 4: Create Runbook

```bash
# Create runbook for HighErrorRate
cat > runbooks/HighErrorRate.md <<'EOF'
# HighErrorRate Runbook

## Investigation
1. Check Grafana dashboard
2. Check recent deployments
3. Check logs: {app="churn-api", level="ERROR"}

## Mitigation
- Rollback: kubectl rollout undo deployment churn-api -n churn-mlops
- Scale up: kubectl scale deployment churn-api --replicas=6 -n churn-mlops

## Verification
- Error rate < 5%
- Alert resolved
EOF

# Link in alert annotation
# annotations:
#   runbook_url: "https://github.com/yourorg/runbooks/blob/main/HighErrorRate.md"
```

### Exercise 5: Silence Alert

```bash
# Silence alert during maintenance
# Alertmanager UI → Silences → New Silence
# 
# Matchers:
#   alertname = HighErrorRate
# Duration: 2 hours
# Comment: "Planned maintenance"
```

---

## Assessment Questions

### Question 1: Multiple Choice
What's the appropriate "for" duration for a critical user-facing alert?

A) 0 seconds (immediate)  
B) **2-5 minutes** ✅  
C) 30 minutes  
D) 1 hour  

**Explanation**: 2-5 minutes balances fast response with avoiding false positives from transient spikes.

---

### Question 2: True/False
**Statement**: Every metric threshold breach should trigger an alert.

**Answer**: False ❌  
**Explanation**: Only alert on **symptoms that affect users or SLOs**. Not every threshold breach has user impact. This prevents alert fatigue.

---

### Question 3: Short Answer
What's the difference between SLI and SLO?

**Answer**:
- **SLI (Service Level Indicator)**: The **metric** measuring service quality (e.g., request success rate, latency)
- **SLO (Service Level Objective)**: The **target** for an SLI (e.g., 99.9% success rate, P95 latency < 500ms)

Example:
- SLI: `sum(rate(requests{status="200"})) / sum(rate(requests))`
- SLO: 99.9% (target)
- Alert: When SLI < 99.9%

---

### Question 4: Code Analysis
What does this alert rule do?

```yaml
- alert: ErrorBudgetBurn
  expr: |
    (1 - (
      sum(rate(http_requests_total{status=~"2.."}[1h]))
      /
      sum(rate(http_requests_total[1h]))
    )) > 0.001
  for: 5m
```

**Answer**:
- Calculates **error rate** over 1 hour window
- Alerts when error rate **exceeds 0.1%** (0.001)
- Sustained for 5 minutes
- **Purpose**: Protect 99.9% availability SLO (0.1% error budget)
- **Use case**: Early warning that we're burning error budget too fast

---

### Question 5: Design Challenge
Design an alerting strategy for an ML prediction API with 99.9% SLO.

**Answer**:

```yaml
# SLO: 99.9% availability (0.1% error budget)

# Tier 1: Critical User Impact (Page immediately)
- alert: APICompletelyDown
  expr: up{job="prediction-api"} == 0
  for: 1m
  severity: critical
  # ALL requests failing

- alert: MajorOutage
  expr: (error_rate > 0.1)  # 10%+ errors
  for: 2m
  severity: critical
  # Massive user impact

# Tier 2: SLO Violation (Page during business hours)
- alert: SLOViolation
  expr: (error_rate > 0.001)  # 0.1%+ errors
  for: 5m
  severity: warning
  # Exceeding error budget

- alert: HighLatency
  expr: (p95_latency > 0.5)  # 500ms
  for: 10m
  severity: warning
  # Violating latency SLO

# Tier 3: Early Warning (Slack notification)
- alert: IncreasingErrors
  expr: (error_rate > 0.0001)  # 0.01%
  for: 15m
  severity: info
  # Trend concerning but not critical yet

- alert: ModelDrift
  expr: (data_drift_score > 0.3)
  for: 1h
  severity: warning
  # Model quality degrading

# Tier 4: Capacity Planning (Email)
- alert: HighTraffic
  expr: (request_rate > 1000)
  for: 2h
  severity: info
  # Need to scale

# Notification routing:
route:
  routes:
    - match:
        severity: critical
      receiver: pagerduty
      continue: true
    
    - match:
        severity: warning
      receiver: slack-urgent
      active_time_intervals: [business_hours]
    
    - match:
        severity: info
      receiver: slack-general

# Runbooks:
- APICompletelyDown: Check pods, recent deployments, dependencies
- SLOViolation: Investigate logs, check for pattern, consider rollback
- HighLatency: Check resource usage, database performance, scale if needed
- ModelDrift: Review recent data, consider retraining

# Dashboards:
- API Overview: Request rate, error rate, latency
- SLO Tracking: Error budget burn rate, availability %
- ML Monitoring: Model confidence, drift score, feature quality
```

---

## Key Takeaways

### ✅ What You Learned

1. **Alert Fundamentals**
   - Actionable, high-signal alerts
   - Appropriate severity levels
   - Alert lifecycle

2. **Prometheus Alertmanager**
   - Configuration
   - Routing and grouping
   - Inhibition rules

3. **Alert Rules**
   - API monitoring
   - ML model alerts
   - Infrastructure alerts

4. **Notifications**
   - Slack, email, PagerDuty
   - Custom webhooks

5. **SLOs**
   - Defining SLIs/SLOs
   - Error budget tracking
   - SLO-based alerts

6. **Incident Response**
   - Triage workflow
   - Severity levels
   - Runbooks

---

## Next Steps

Continue to **[Module 9: Production Best Practices](../module-09-production/section-30-security.md)**

In the next module, we'll cover:
- Security best practices
- Performance optimization
- Cost management
- Documentation

---

## Additional Resources

- [Prometheus Alerting](https://prometheus.io/docs/alerting/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Google SRE Book - Alerting](https://sre.google/sre-book/monitoring-distributed-systems/)
- [The Art of SLOs](https://www.usenix.org/conference/srecon18asia/presentation/sridharan)

---

**Progress**: 27/34 sections complete (79%) → **28/34 (82%)**
