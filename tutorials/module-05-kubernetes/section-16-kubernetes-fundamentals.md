# Section 16: Kubernetes Fundamentals

**Duration**: 3 hours  
**Level**: Intermediate  
**Prerequisites**: Module 4 (Containerization)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand Kubernetes architecture
- ✅ Deploy Pods and manage containers
- ✅ Create Deployments for scalability
- ✅ Expose services with Service resources
- ✅ Use kubectl effectively
- ✅ Implement health checks and probes
- ✅ Manage resource limits

---

## 📚 Table of Contents

1. [What is Kubernetes?](#what-is-kubernetes)
2. [Kubernetes Architecture](#kubernetes-architecture)
3. [Core Concepts](#core-concepts)
4. [Pods](#pods)
5. [Deployments](#deployments)
6. [Services](#services)
7. [kubectl Commands](#kubectl-commands)
8. [Code Walkthrough](#code-walkthrough)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## What is Kubernetes?

### The Container Orchestration Problem

```
Without Kubernetes:

Docker Compose (single host):
✅ Works for development
✅ Easy to use
❌ Single point of failure
❌ No auto-scaling
❌ No load balancing across hosts
❌ Manual updates (downtime)

Example:
- Host crashes → All containers down
- Need 10 API replicas → Can't scale beyond 1 host
- Update API → Stop → Update → Start (downtime!)
```

### Kubernetes Solution

> **Kubernetes (K8s)**: Container orchestration platform for automating deployment, scaling, and management of containerized applications.

**Key Features**:
```
✅ Self-healing: Restarts failed containers automatically
✅ Auto-scaling: Scales based on CPU/memory/custom metrics
✅ Load balancing: Distributes traffic across replicas
✅ Rolling updates: Zero-downtime deployments
✅ Service discovery: Containers find each other automatically
✅ Multi-host: Runs across cluster of machines
✅ Declarative: Describe desired state, K8s makes it happen
```

**Analogy**: Kubernetes is like a data center operating system
- You: "I want 10 API containers"
- K8s: "Sure, I'll distribute them across hosts, monitor health, restart failures"

---

## Kubernetes Architecture

### Cluster Components

```
┌─────────────────────────────────────────────────────────┐
│              Kubernetes Cluster                          │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Control Plane (Master)                                  │
│  ┌────────────────────────────────────────────────┐    │
│  │ API Server: REST API for all operations        │    │
│  │ etcd: Distributed key-value store (state)      │    │
│  │ Scheduler: Assigns pods to nodes               │    │
│  │ Controller Manager: Maintains desired state    │    │
│  └────────────────────────────────────────────────┘    │
│                        │                                 │
│                        │ (manages)                       │
│                        ↓                                 │
│  Worker Nodes                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Node 1       │  │ Node 2       │  │ Node 3       │ │
│  │              │  │              │  │              │ │
│  │ kubelet      │  │ kubelet      │  │ kubelet      │ │
│  │ (node agent) │  │ (node agent) │  │ (node agent) │ │
│  │              │  │              │  │              │ │
│  │ Pods:        │  │ Pods:        │  │ Pods:        │ │
│  │ ┌─────┐      │  │ ┌─────┐      │  │ ┌─────┐      │ │
│  │ │API  │      │  │ │API  │      │  │ │DB   │      │ │
│  │ │v1.0 │      │  │ │v1.0 │      │  │ │     │      │ │
│  │ └─────┘      │  │ └─────┘      │  │ └─────┘      │ │
│  │ ┌─────┐      │  │ ┌─────┐      │  │              │ │
│  │ │ML   │      │  │ │API  │      │  │              │ │
│  │ │Job  │      │  │ │v1.0 │      │  │              │ │
│  │ └─────┘      │  │ └─────┘      │  │              │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Purpose |
|-----------|---------|
| **API Server** | Central hub, all operations go through it (kubectl → API Server) |
| **etcd** | Stores cluster state (configuration, secrets, etc.) |
| **Scheduler** | Decides which node runs each pod (based on resources) |
| **Controller Manager** | Ensures desired state (e.g., 3 replicas → Keeps 3 running) |
| **kubelet** | Node agent, manages pods on that node |
| **kube-proxy** | Network proxy, enables service communication |

---

## Core Concepts

### 1. Pod

> **Pod**: Smallest deployable unit in Kubernetes (1+ containers)

```
Pod = Wrapper around container(s)

Single container pod:
┌─────────────┐
│ Pod         │
│ ┌─────────┐ │
│ │ API     │ │
│ │Container│ │
│ └─────────┘ │
└─────────────┘

Multi-container pod (sidecar pattern):
┌──────────────────────┐
│ Pod                  │
│ ┌────────┐ ┌───────┐│
│ │ API    │ │ Proxy ││
│ │Main    │ │Sidecar││
│ └────────┘ └───────┘│
└──────────────────────┘
```

**Key Points**:
- Containers in same pod share network (localhost)
- Containers in same pod share storage volumes
- Ephemeral (deleted/recreated frequently)

### 2. Deployment

> **Deployment**: Manages multiple replicas of pods (desired state)

```
Deployment (desired state: 3 replicas)
│
├─ ReplicaSet (manages pods)
│  │
│  ├─ Pod 1 (churn-api-abc123)
│  ├─ Pod 2 (churn-api-def456)
│  └─ Pod 3 (churn-api-ghi789)
```

**Benefits**:
- ✅ Scaling: `replicas: 3` → K8s maintains 3 pods
- ✅ Self-healing: Pod crashes → K8s starts new one
- ✅ Rolling updates: Update image → Zero downtime
- ✅ Rollback: Bad deployment → Revert to previous version

### 3. Service

> **Service**: Stable network endpoint for pods (load balancer)

```
Problem: Pods have dynamic IPs (change on restart)

Client → How to reach API pods?
         Pod 1: 10.0.1.15 (changes!)
         Pod 2: 10.0.1.22 (changes!)
         Pod 3: 10.0.1.31 (changes!)

Solution: Service (stable IP + DNS name)

Client → Service (churn-api.default.svc)
         │  Stable IP: 10.96.0.100
         │  DNS: churn-api
         │
         ├─→ Pod 1 (load balanced)
         ├─→ Pod 2 (load balanced)
         └─→ Pod 3 (load balanced)
```

### 4. Namespace

> **Namespace**: Virtual cluster (isolation boundary)

```
Cluster
│
├─ default (default namespace)
│  ├─ churn-api
│  └─ churn-ml
│
├─ churn-mlops (custom namespace)
│  ├─ churn-api
│  └─ churn-ml
│
└─ monitoring
   ├─ prometheus
   └─ grafana
```

**Use Cases**:
- Separate environments (dev/staging/prod)
- Team isolation
- Resource quotas per namespace

---

## Pods

### Pod YAML

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: churn-api-pod
  labels:
    app: churn-api
    version: v1.0
spec:
  containers:
    - name: api
      image: techitfactory/churn-api:v1.0.0
      ports:
        - containerPort: 8000
      env:
        - name: LOG_LEVEL
          value: "info"
      resources:
        requests:
          memory: "512Mi"
          cpu: "500m"
        limits:
          memory: "1Gi"
          cpu: "1000m"
```

**Create pod**:
```bash
kubectl apply -f pod.yaml
```

### Pod Lifecycle

```
Pending → Running → Succeeded/Failed

Pending: 
- Waiting for node assignment
- Pulling image
- Initializing

Running:
- Container(s) running
- Health checks passing

Succeeded:
- Container(s) completed (exit code 0)
- Job/CronJob pods

Failed:
- Container(s) crashed (non-zero exit)
- Image pull failed
- Resource limits exceeded
```

### Resource Requests & Limits

```yaml
resources:
  requests:
    memory: "512Mi"   # Minimum guaranteed
    cpu: "500m"       # 0.5 CPU cores
  limits:
    memory: "1Gi"     # Maximum allowed
    cpu: "1000m"      # 1 CPU core
```

**How it works**:
- **Requests**: Scheduler ensures node has this much available
- **Limits**: Container killed if exceeds (OOMKilled for memory)

**Units**:
- Memory: `Mi` (mebibytes), `Gi` (gibibytes)
- CPU: `m` (millicores), `1000m` = 1 core

---

## Deployments

### Deployment YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-api
  labels:
    app: churn-api
spec:
  replicas: 3  # Desired number of pods
  
  selector:
    matchLabels:
      app: churn-api  # Pods to manage (by label)
  
  template:
    metadata:
      labels:
        app: churn-api  # Must match selector
    spec:
      containers:
        - name: api
          image: techitfactory/churn-api:v1.0.0
          ports:
            - containerPort: 8000
          
          # Health checks
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
          
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
```

**Create deployment**:
```bash
kubectl apply -f deployment.yaml

# Check status
kubectl get deployments
kubectl get pods

# Scale
kubectl scale deployment churn-api --replicas=5

# Update image
kubectl set image deployment/churn-api api=techitfactory/churn-api:v1.1.0

# Rollback
kubectl rollout undo deployment/churn-api
```

### Health Checks (Probes)

| Probe | Purpose | Action if Fails |
|-------|---------|-----------------|
| **livenessProbe** | Is container alive? | Restart container |
| **readinessProbe** | Is container ready for traffic? | Remove from load balancer |
| **startupProbe** | Has container started? | Wait longer before checking liveness |

**Example**:
```yaml
livenessProbe:
  httpGet:
    path: /live
    port: 8000
  initialDelaySeconds: 10  # Wait 10s after start
  periodSeconds: 20        # Check every 20s
  timeoutSeconds: 5        # 5s timeout
  failureThreshold: 3      # Restart after 3 failures

readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
```

**Probe Types**:
```yaml
# HTTP GET
httpGet:
  path: /health
  port: 8000

# TCP Socket
tcpSocket:
  port: 5432

# Command execution
exec:
  command:
    - cat
    - /tmp/healthy
```

### Rolling Updates

```
Rolling Update Strategy:

Old version (v1.0):  ●●●●●
                     
Update to v1.1:
Step 1: Start 1 new   ●●●●● ○
Step 2: Old ready     ●●●●  ●
Step 3: Start 2 new   ●●●●  ●○
Step 4: Old ready     ●●●   ●●
Step 5: Start 3 new   ●●●   ●●○
Step 6: Old ready     ●●    ●●●
...
Final: All v1.1       ●●●●●

● = v1.0 (old)
○ = v1.1 (new, starting)
● = v1.1 (new, ready)

Zero downtime! Always have healthy pods.
```

**Configuration**:
```yaml
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 1 extra pod during update
      maxUnavailable: 1  # Max 1 pod down during update
```

---

## Services

### Service Types

| Type | Purpose | Use Case |
|------|---------|----------|
| **ClusterIP** | Internal only (default) | Microservices communication |
| **NodePort** | Exposes on each node's IP | Development, testing |
| **LoadBalancer** | Cloud load balancer | Production (AWS/GCP/Azure) |
| **ExternalName** | DNS CNAME | External service alias |

### ClusterIP Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: churn-api
spec:
  type: ClusterIP  # Default
  selector:
    app: churn-api  # Targets pods with this label
  ports:
    - name: http
      port: 8000        # Service port
      targetPort: 8000  # Container port
```

**Access**:
```bash
# Within cluster
curl http://churn-api:8000/health
curl http://churn-api.default.svc.cluster.local:8000/health

# From outside cluster
kubectl port-forward svc/churn-api 8000:8000
curl http://localhost:8000/health
```

### NodePort Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: churn-api
spec:
  type: NodePort
  selector:
    app: churn-api
  ports:
    - port: 8000
      targetPort: 8000
      nodePort: 30080  # Optional (auto-assigned if omitted)
```

**Access**:
```bash
# From outside cluster
curl http://<node-ip>:30080/health
```

### LoadBalancer Service (Cloud)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: churn-api
spec:
  type: LoadBalancer
  selector:
    app: churn-api
  ports:
    - port: 80
      targetPort: 8000
```

**How it works**:
```
Cloud Provider → Creates load balancer → Assigns public IP
                                          ↓
                                    External IP: 34.123.45.67
                                          ↓
                          Load balances to → Node 1 (churn-api pod)
                                          → Node 2 (churn-api pod)
                                          → Node 3 (churn-api pod)
```

---

## kubectl Commands

### Basic Commands

```bash
# Get resources
kubectl get pods
kubectl get deployments
kubectl get services
kubectl get all

# Describe (detailed info)
kubectl describe pod churn-api-abc123
kubectl describe deployment churn-api

# Logs
kubectl logs churn-api-abc123
kubectl logs -f churn-api-abc123  # Follow
kubectl logs deployment/churn-api  # All pods in deployment

# Execute command in pod
kubectl exec -it churn-api-abc123 -- bash
kubectl exec churn-api-abc123 -- python --version

# Port forwarding
kubectl port-forward pod/churn-api-abc123 8000:8000
kubectl port-forward svc/churn-api 8000:8000

# Delete
kubectl delete pod churn-api-abc123
kubectl delete deployment churn-api
kubectl delete -f deployment.yaml
```

### Apply & Manage

```bash
# Create/update resources
kubectl apply -f deployment.yaml
kubectl apply -f k8s/  # All files in directory

# Dry run (preview)
kubectl apply -f deployment.yaml --dry-run=client

# Diff (show changes)
kubectl diff -f deployment.yaml

# Delete
kubectl delete -f deployment.yaml
```

### Scaling & Updates

```bash
# Scale
kubectl scale deployment churn-api --replicas=5

# Update image
kubectl set image deployment/churn-api api=techitfactory/churn-api:v1.1.0

# Rollout status
kubectl rollout status deployment/churn-api

# Rollout history
kubectl rollout history deployment/churn-api

# Rollback
kubectl rollout undo deployment/churn-api
kubectl rollout undo deployment/churn-api --to-revision=2
```

### Debugging

```bash
# Check events
kubectl get events
kubectl get events --sort-by='.lastTimestamp'

# Describe pod (common issues)
kubectl describe pod churn-api-abc123

# Logs
kubectl logs churn-api-abc123
kubectl logs churn-api-abc123 --previous  # Previous container (crashed)

# Shell into pod
kubectl exec -it churn-api-abc123 -- bash

# Check resource usage
kubectl top nodes
kubectl top pods
```

---

## Code Walkthrough

### File: `k8s/api-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-api
  labels:
    app: churn-api
spec:
  replicas: 2  # 2 replicas for high availability
  
  selector:
    matchLabels:
      app: churn-api
  
  template:
    metadata:
      labels:
        app: churn-api
    spec:
      # Init container (runs before main container)
      initContainers:
        - name: init-dirs
          image: busybox:1.36
          command: ["sh", "-c", "mkdir -p /pvc/data /pvc/artifacts"]
          volumeMounts:
            - name: mlops-storage
              mountPath: /pvc
      
      # Main container
      containers:
        - name: churn-api
          image: techitfactory/churn-api:0.1.0
          imagePullPolicy: IfNotPresent
          
          ports:
            - name: http
              containerPort: 8000
          
          env:
            - name: CHURN_MLOPS_CONFIG
              value: /app/config/config.yaml
          
          # Resource limits
          resources:
            limits:
              cpu: 1000m
              memory: 1Gi
            requests:
              cpu: 500m
              memory: 512Mi
          
          # Health checks
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
          
          # Volume mounts
          volumeMounts:
            - name: mlops-storage
              mountPath: /app/data
              subPath: data
            - name: mlops-storage
              mountPath: /app/artifacts
              subPath: artifacts
            - name: config
              mountPath: /app/config/config.yaml
              subPath: config.yaml
      
      # Volumes
      volumes:
        - name: config
          configMap:
            name: churn-mlops-config
        - name: mlops-storage
          persistentVolumeClaim:
            claimName: churn-mlops-pvc
```

### File: `k8s/api-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: churn-api
  namespace: churn-mlops
  labels:
    app: churn-api
  annotations:
    # Prometheus scraping
    prometheus.io/scrape: "true"
    prometheus.io/path: "/metrics"
    prometheus.io/port: "8000"
spec:
  selector:
    app: churn-api  # Routes to pods with this label
  ports:
    - name: http
      port: 8000
      targetPort: 8000
```

---

## Hands-On Exercise

### Exercise 1: Deploy Simple Pod

```yaml
# pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
```

**Commands**:
```bash
# Create pod
kubectl apply -f pod.yaml

# Check status
kubectl get pods

# View logs
kubectl logs nginx-pod

# Test (port forward)
kubectl port-forward nginx-pod 8080:80
curl http://localhost:8080

# Delete
kubectl delete pod nginx-pod
```

### Exercise 2: Create Deployment

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

**Commands**:
```bash
# Create deployment
kubectl apply -f deployment.yaml

# Check
kubectl get deployments
kubectl get pods

# Scale
kubectl scale deployment nginx-deployment --replicas=5
kubectl get pods  # Should see 5 pods

# Delete one pod (self-healing)
kubectl delete pod <pod-name>
kubectl get pods  # New pod automatically created!
```

### Exercise 3: Expose with Service

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

**Commands**:
```bash
# Create service
kubectl apply -f service.yaml

# Check
kubectl get services

# Test
kubectl port-forward svc/nginx-service 8080:80
curl http://localhost:8080
```

### Exercise 4: Deploy Churn API

```bash
# Create namespace
kubectl create namespace churn-mlops

# Apply all resources
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/pvc.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/api-service.yaml

# Check
kubectl get all -n churn-mlops

# Test API
kubectl port-forward -n churn-mlops svc/churn-api 8000:8000
curl http://localhost:8000/health
```

### Exercise 5: Rolling Update

```bash
# Current version
kubectl get deployment churn-api -o wide

# Update image
kubectl set image deployment/churn-api churn-api=techitfactory/churn-api:v1.1.0

# Watch rollout
kubectl rollout status deployment/churn-api

# Check history
kubectl rollout history deployment/churn-api

# Rollback if needed
kubectl rollout undo deployment/churn-api
```

---

## Assessment Questions

### Question 1: Multiple Choice
What is the smallest deployable unit in Kubernetes?

A) Container  
B) **Pod** ✅  
C) Deployment  
D) Service  

**Explanation**: Pod wraps 1+ containers. You deploy pods, not containers directly.

---

### Question 2: True/False
**Statement**: A Deployment manages multiple replicas of pods and provides rolling updates.

**Answer**: True ✅  
**Explanation**: Deployments maintain desired replica count and handle zero-downtime updates.

---

### Question 3: Short Answer
What's the difference between livenessProbe and readinessProbe?

**Answer**:
- **livenessProbe**: Checks if container is alive → Restart if fails
- **readinessProbe**: Checks if container is ready for traffic → Remove from load balancer if fails

---

### Question 4: Code Analysis
What's wrong with this Service?

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api-server  # Label: api-server
  ports:
    - port: 8000

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  template:
    metadata:
      labels:
        app: api  # Label: api (different!)
```

**Answer**:
- Service selector (`app: api-server`) doesn't match Deployment labels (`app: api`)
- Service won't route traffic to pods
- Fix: Make labels match

---

### Question 5: Design Challenge
Design Deployment + Service for API with 3 replicas, 500Mi memory, health checks.

**Answer**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-api
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
        - name: api
          image: techitfactory/churn-api:v1.0
          resources:
            requests:
              memory: "500Mi"
          livenessProbe:
            httpGet:
              path: /live
              port: 8000
          readinessProbe:
            httpGet:
              path: /ready
              port: 8000
---
apiVersion: v1
kind: Service
metadata:
  name: churn-api
spec:
  selector:
    app: churn-api
  ports:
    - port: 8000
```

---

## Key Takeaways

### ✅ What You Learned

1. **Kubernetes Architecture**
   - Control Plane (API Server, etcd, Scheduler, Controller Manager)
   - Worker Nodes (kubelet, pods)

2. **Core Resources**
   - **Pod**: Smallest unit (1+ containers)
   - **Deployment**: Manages replicas, rolling updates
   - **Service**: Stable network endpoint, load balancer

3. **Health Checks**
   - **livenessProbe**: Restart if fails
   - **readinessProbe**: Remove from LB if fails

4. **kubectl Commands**
   - `kubectl apply`: Create/update
   - `kubectl get`: List resources
   - `kubectl describe`: Detailed info
   - `kubectl logs`: View logs
   - `kubectl exec`: Run commands

5. **Key Features**
   - Self-healing
   - Auto-scaling
   - Rolling updates
   - Service discovery

---

## Next Steps

Continue to **[Section 17: Helm Charts](section-17-helm-charts.md)**

In the next section, we'll:
- Package applications with Helm
- Create reusable charts
- Manage releases
- Use values for configuration

---

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubernetes Patterns](https://k8spatterns.io/)

---

**Progress**: 14/34 sections complete (41%) → **15/34 (44%)**
