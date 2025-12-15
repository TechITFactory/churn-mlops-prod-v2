# Section 17: Helm Charts

**Duration**: 2.5 hours  
**Level**: Intermediate  
**Prerequisites**: Section 16 (Kubernetes Fundamentals)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand Helm architecture and benefits
- ✅ Create Helm charts from scratch
- ✅ Use templates and values effectively
- ✅ Manage releases and rollbacks
- ✅ Override values for different environments
- ✅ Package and distribute charts

---

## 📚 Table of Contents

1. [What is Helm?](#what-is-helm)
2. [Helm Architecture](#helm-architecture)
3. [Chart Structure](#chart-structure)
4. [Templates](#templates)
5. [Values](#values)
6. [Helpers and Functions](#helpers-and-functions)
7. [Code Walkthrough](#code-walkthrough)
8. [Hands-On Exercise](#hands-on-exercise)
9. [Assessment Questions](#assessment-questions)

---

## What is Helm?

### Problem: Managing Kubernetes YAMLs

```
Without Helm:

Project has 20+ YAML files:
├── namespace.yaml
├── configmap-dev.yaml
├── configmap-prod.yaml
├── deployment-api-dev.yaml
├── deployment-api-prod.yaml
├── service-api.yaml
├── deployment-ml-dev.yaml
├── deployment-ml-prod.yaml
├── cronjob-batch-dev.yaml
├── cronjob-batch-prod.yaml
└── ... (10 more files)

Problems:
❌ Duplication (dev/staging/prod copies)
❌ Hard to maintain (change image → update 5 files)
❌ No versioning (which YAML version deployed?)
❌ Manual dependency management
❌ Complex deployments (20 kubectl apply commands)
```

### Solution: Helm

> **Helm**: Package manager for Kubernetes (like apt/yum for Linux, npm for Node.js)

**Benefits**:
```
✅ Templating: One template → Multiple environments
✅ Versioning: Track releases (v1.0, v1.1, rollback)
✅ Dependencies: Chart depends on other charts
✅ Simple deployment: helm install (1 command)
✅ Reusability: Share charts (Helm Hub)
```

**Analogy**: Helm Chart = Recipe, Helm Release = Cooked meal
- Chart: Template (how to deploy)
- Release: Deployed instance (running application)

---

## Helm Architecture

### Components

```
┌─────────────────────────────────────────┐
│         Helm Architecture               │
├─────────────────────────────────────────┤
│                                         │
│  Developer                              │
│    │                                    │
│    │ writes                             │
│    ↓                                    │
│  Helm Chart                             │
│  ┌──────────────────────────┐          │
│  │ templates/               │          │
│  │ ├── deployment.yaml      │          │
│  │ ├── service.yaml         │          │
│  │ values.yaml              │          │
│  │ Chart.yaml               │          │
│  └──────────────────────────┘          │
│    │                                    │
│    │ helm install                       │
│    ↓                                    │
│  Helm CLI                               │
│    │                                    │
│    │ renders templates + values         │
│    │ → Kubernetes YAML                  │
│    ↓                                    │
│  Kubernetes Cluster                     │
│  ┌──────────────────────────┐          │
│  │ Release: my-app-v1       │          │
│  │ ├── Deployment           │          │
│  │ ├── Service              │          │
│  │ └── ConfigMap            │          │
│  └──────────────────────────┘          │
└─────────────────────────────────────────┘
```

### Helm Concepts

| Concept | Description |
|---------|-------------|
| **Chart** | Package (templates + defaults) |
| **Release** | Deployed instance of chart |
| **Repository** | Chart storage (Helm Hub, Artifact Hub) |
| **Values** | Configuration overrides |
| **Template** | YAML with Go template syntax |

**Example**:
```bash
# Install chart → Creates release
helm install my-api ./churn-mlops-chart

# Chart: churn-mlops-chart (package)
# Release: my-api (deployed instance)
```

---

## Chart Structure

### Directory Layout

```
churn-mlops/                  # Chart root
├── Chart.yaml                # Chart metadata
├── values.yaml               # Default values
├── values-staging.yaml       # Staging overrides
├── values-production.yaml    # Production overrides
├── templates/                # K8s templates
│   ├── deployment.yaml       # Deployment template
│   ├── service.yaml          # Service template
│   ├── configmap.yaml        # ConfigMap template
│   ├── _helpers.tpl          # Template helpers
│   └── NOTES.txt             # Post-install notes
├── charts/                   # Dependencies
└── README.md                 # Documentation
```

### Chart.yaml

```yaml
apiVersion: v2
name: churn-mlops
description: A production-grade MLOps Helm chart for customer churn prediction
type: application
version: 1.0.0           # Chart version (SemVer)
appVersion: "0.1.0"      # Application version

keywords:
  - mlops
  - machine-learning
  - churn-prediction

maintainers:
  - name: TechITFactory
    email: contact@techitfactory.com

# Dependencies (other charts)
dependencies:
  - name: postgresql
    version: "12.1.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

**Key Fields**:
- `version`: Chart version (increment on changes)
- `appVersion`: Application version (Docker image tag)
- `dependencies`: External charts this chart needs

### values.yaml (Default Values)

```yaml
# Default configuration
images:
  api:
    repository: techitfactory/churn-api
    tag: "latest"
    pullPolicy: IfNotPresent

replicaCount: 2

resources:
  api:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

service:
  port: 8000
  type: ClusterIP

# Can be overridden with:
# helm install --set replicaCount=5
# helm install -f values-prod.yaml
```

---

## Templates

### Template Syntax (Go Templates)

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-api
  # .Release.Name = release name from helm install
  
spec:
  replicas: {{ .Values.replicaCount }}
  # .Values.replicaCount = from values.yaml
  
  template:
    spec:
      containers:
        - name: api
          image: {{ .Values.images.api.repository }}:{{ .Values.images.api.tag }}
          # .Values.images.api.repository = techitfactory/churn-api
          # .Values.images.api.tag = latest
          
          resources:
            {{- toYaml .Values.resources.api | nindent 12 }}
            # toYaml: Convert to YAML
            # nindent: Indent 12 spaces
```

**Template Variables**:
| Variable | Description |
|----------|-------------|
| `.Values` | Values from values.yaml |
| `.Release.Name` | Release name |
| `.Release.Namespace` | Namespace |
| `.Chart.Name` | Chart name |
| `.Chart.Version` | Chart version |

### Control Structures

```yaml
# If/Else
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
# ...
{{- end }}

# Range (loop)
env:
  {{- range .Values.env }}
  - name: {{ .name }}
    value: {{ .value }}
  {{- end }}

# With (scope)
{{- with .Values.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

### Template Functions

```yaml
# String manipulation
name: {{ .Release.Name | upper }}            # UPPERCASE
name: {{ .Release.Name | quote }}            # "quoted"
name: {{ .Release.Name | default "api" }}    # default value

# YAML conversion
resources:
  {{- toYaml .Values.resources | nindent 2 }}

# Conditionals
{{- if eq .Values.env "production" }}
replicas: 5
{{- else }}
replicas: 2
{{- end }}

# Include templates
{{- include "churn-mlops.labels" . | nindent 4 }}
```

---

## Values

### Default Values (values.yaml)

```yaml
# Global defaults
replicaCount: 2

images:
  api:
    repository: techitfactory/churn-api
    tag: "latest"
    pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8000

resources:
  api:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

env: development
```

### Environment-Specific Overrides

**values-staging.yaml**:
```yaml
# Override for staging
replicaCount: 1

images:
  api:
    tag: "staging"

env: staging
```

**values-production.yaml**:
```yaml
# Override for production
replicaCount: 5

images:
  api:
    tag: "v1.0.0"  # Specific version
    pullPolicy: Always

service:
  type: LoadBalancer

resources:
  api:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 2Gi

env: production
```

### Using Values

```bash
# Use default values.yaml
helm install my-app ./churn-mlops

# Override with staging values
helm install my-app ./churn-mlops -f values-staging.yaml

# Override with production values
helm install my-app ./churn-mlops -f values-production.yaml

# Override specific value
helm install my-app ./churn-mlops --set replicaCount=10

# Override nested value
helm install my-app ./churn-mlops --set images.api.tag=v1.2.0
```

---

## Helpers and Functions

### _helpers.tpl

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "churn-mlops.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "churn-mlops.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "churn-mlops.labels" -}}
helm.sh/chart: {{ include "churn-mlops.name" . }}
{{ include "churn-mlops.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "churn-mlops.selectorLabels" -}}
app.kubernetes.io/name: {{ include "churn-mlops.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
API image
*/}}
{{- define "churn-mlops.apiImage" -}}
{{- printf "%s:%s" .Values.images.api.repository (.Values.images.api.tag | default .Chart.AppVersion) }}
{{- end }}
```

### Using Helpers

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "churn-mlops.fullname" . }}-api
  labels:
    {{- include "churn-mlops.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "churn-mlops.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "churn-mlops.labels" . | nindent 8 }}
    spec:
      containers:
        - name: api
          image: {{ include "churn-mlops.apiImage" . | quote }}
```

---

## Code Walkthrough

### File: `k8s/helm/churn-mlops/Chart.yaml`

```yaml
apiVersion: v2
name: churn-mlops
description: A production-grade MLOps Helm chart for customer churn prediction
type: application
version: 1.0.0
appVersion: "0.1.0"

keywords:
  - mlops
  - machine-learning
  - churn-prediction
  - fastapi

maintainers:
  - name: TechITFactory
    email: contact@techitfactory.com
```

### File: `k8s/helm/churn-mlops/values.yaml`

```yaml
images:
  api:
    repository: techitfactory/churn-api
    tag: "latest"
    pullPolicy: IfNotPresent
  
  ml:
    repository: techitfactory/churn-ml
    tag: "latest"
    pullPolicy: IfNotPresent

# PVC configuration
pvc:
  name: churn-mlops-data
  accessModes:
    - ReadWriteOnce
  size: 10Gi

# Service configuration
service:
  name: churn-mlops-api
  port: 8000
  type: ClusterIP

# Resource limits
resources:
  api:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
  
  ml:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 2Gi

# API configuration
api:
  replicaCount: 2
  
  env:
    - name: CHURN_MLOPS_CONFIG
      value: /app/config/config.yaml
    - name: LOG_LEVEL
      value: INFO

# Batch scoring
batchScore:
  enabled: true
  schedule: "0 2 * * *"  # 2 AM daily
```

### File: `k8s/helm/churn-mlops/templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "churn-mlops.fullname" . }}-api
  labels:
    {{- include "churn-mlops.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.api.replicaCount }}
  
  selector:
    matchLabels:
      app: churn-api
      {{- include "churn-mlops.selectorLabels" . | nindent 6 }}
  
  template:
    metadata:
      labels:
        app: churn-api
        {{- include "churn-mlops.labels" . | nindent 8 }}
    spec:
      containers:
        - name: churn-api
          image: {{ include "churn-mlops.apiImage" . | quote }}
          imagePullPolicy: {{ .Values.images.api.pullPolicy }}
          
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
          
          env:
            {{- toYaml .Values.api.env | nindent 12 }}
          
          resources:
            {{- toYaml .Values.resources.api | nindent 12 }}
          
          livenessProbe:
            httpGet:
              path: /live
              port: {{ .Values.service.port }}
            initialDelaySeconds: 10
            periodSeconds: 20
          
          readinessProbe:
            httpGet:
              path: /ready
              port: {{ .Values.service.port }}
            initialDelaySeconds: 5
            periodSeconds: 10
          
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
            claimName: {{ .Values.pvc.name }}
```

---

## Hands-On Exercise

### Exercise 1: Create Simple Chart

```bash
# Create chart
helm create my-chart

# Inspect structure
tree my-chart/

# Install
helm install my-release my-chart

# Check
kubectl get all

# Uninstall
helm uninstall my-release
```

### Exercise 2: Install Churn MLOps Chart

```bash
# Navigate to chart directory
cd k8s/helm

# Dry run (preview YAML)
helm install churn-mlops ./churn-mlops --dry-run --debug

# Install
helm install churn-mlops ./churn-mlops

# Check
helm list
kubectl get all

# Test API
kubectl port-forward svc/churn-mlops-api 8000:8000
curl http://localhost:8000/health
```

### Exercise 3: Override Values

```bash
# Install with staging values
helm install churn-staging ./churn-mlops -f churn-mlops/values-staging.yaml

# Install with production values
helm install churn-prod ./churn-mlops -f churn-mlops/values-production.yaml

# Override specific value
helm install churn-custom ./churn-mlops --set api.replicaCount=10
```

### Exercise 4: Upgrade Release

```bash
# Install initial version
helm install my-app ./churn-mlops

# Modify values.yaml (change replicaCount: 5)
vim churn-mlops/values.yaml

# Upgrade
helm upgrade my-app ./churn-mlops

# Check rollout
kubectl get pods

# Rollback
helm rollback my-app 1
```

### Exercise 5: Template Rendering

```bash
# Render templates (see generated YAML)
helm template my-app ./churn-mlops

# Render with values
helm template my-app ./churn-mlops -f churn-mlops/values-production.yaml

# Show specific template
helm template my-app ./churn-mlops --show-only templates/deployment.yaml
```

---

## Assessment Questions

### Question 1: Multiple Choice
What is a Helm Chart?

A) Running application  
B) **Package of Kubernetes templates** ✅  
C) Docker image  
D) Kubernetes cluster  

**Explanation**: Chart = Package (templates + defaults), Release = Deployed instance

---

### Question 2: True/False
**Statement**: `helm install` creates a release (deployed instance of a chart).

**Answer**: True ✅  
**Explanation**: `helm install <release-name> <chart>` deploys chart and creates release.

---

### Question 3: Short Answer
How do you override default values when installing a chart?

**Answer**:
```bash
# Override with file
helm install my-app ./chart -f values-prod.yaml

# Override specific value
helm install my-app ./chart --set replicaCount=5

# Override nested value
helm install my-app ./chart --set images.api.tag=v1.0
```

---

### Question 4: Code Analysis
What will this template produce?

```yaml
# values.yaml
replicaCount: 3

# template
replicas: {{ .Values.replicaCount }}
```

**Answer**:
```yaml
replicas: 3
```

Helm substitutes `.Values.replicaCount` with value from values.yaml.

---

### Question 5: Design Challenge
Create Helm chart structure for API with dev/prod values.

**Answer**:
```
churn-api/
├── Chart.yaml
│   apiVersion: v2
│   name: churn-api
│   version: 1.0.0
│
├── values.yaml (defaults)
│   replicaCount: 2
│   image:
│     tag: latest
│
├── values-dev.yaml
│   replicaCount: 1
│   image:
│     tag: dev
│
├── values-prod.yaml
│   replicaCount: 5
│   image:
│     tag: v1.0.0
│
└── templates/
    ├── deployment.yaml
    │   replicas: {{ .Values.replicaCount }}
    │   image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
    └── service.yaml

Usage:
helm install api-dev ./churn-api -f values-dev.yaml
helm install api-prod ./churn-api -f values-prod.yaml
```

---

## Key Takeaways

### ✅ What You Learned

1. **Helm Benefits**
   - Templating (DRY)
   - Versioning (releases)
   - Reusability (charts)
   - Simple deployment (1 command)

2. **Chart Structure**
   - `Chart.yaml`: Metadata
   - `values.yaml`: Defaults
   - `templates/`: K8s templates
   - `_helpers.tpl`: Reusable functions

3. **Template Syntax**
   - `.Values`: Access values
   - `.Release.Name`: Release name
   - `{{ }}`: Interpolation
   - `{{- }}`: Trim whitespace

4. **Helm Commands**
   - `helm install`: Deploy chart
   - `helm upgrade`: Update release
   - `helm rollback`: Revert release
   - `helm list`: List releases
   - `helm template`: Render templates

5. **Values Override**
   - `-f values-prod.yaml`
   - `--set key=value`
   - Precedence: --set > -f > values.yaml

---

## Next Steps

Continue to **[Section 18: ConfigMaps & Secrets](section-18-configmaps-secrets.md)**

In the next section, we'll:
- Manage configuration with ConfigMaps
- Secure sensitive data with Secrets
- Use environment variables
- Mount config files

---

## Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Artifact Hub](https://artifacthub.io/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)

---

**Progress**: 15/34 sections complete (44%) → **16/34 (47%)**
