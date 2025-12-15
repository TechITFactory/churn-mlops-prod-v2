# Section 18: ConfigMaps & Secrets

**Duration**: 2 hours  
**Level**: Intermediate  
**Prerequisites**: Sections 16-17 (Kubernetes Fundamentals, Helm Charts)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Manage configuration with ConfigMaps
- ✅ Secure sensitive data with Secrets
- ✅ Use environment variables effectively
- ✅ Mount configuration files
- ✅ Implement external configuration
- ✅ Apply security best practices

---

## 📚 Table of Contents

1. [Configuration in Kubernetes](#configuration-in-kubernetes)
2. [ConfigMaps](#configmaps)
3. [Secrets](#secrets)
4. [Using ConfigMaps and Secrets](#using-configmaps-and-secrets)
5. [External Secrets](#external-secrets)
6. [Best Practices](#best-practices)
7. [Code Walkthrough](#code-walkthrough)
8. [Hands-On Exercise](#hands-on-exercise)
9. [Assessment Questions](#assessment-questions)

---

## Configuration in Kubernetes

### The Configuration Problem

```
Hardcoded Configuration (BAD):

# Dockerfile
ENV DATABASE_URL=postgres://user:pass@db:5432/mydb
ENV API_KEY=sk-1234567890abcdef

Problems:
❌ Rebuild image for config changes
❌ Secrets in image (visible in layers!)
❌ Same image can't run in dev/staging/prod
❌ No separation of concerns
```

### Kubernetes Configuration Options

| Method | Use Case | Example |
|--------|----------|---------|
| **ConfigMap** | Non-sensitive config | App settings, feature flags |
| **Secret** | Sensitive data | Passwords, API keys, certificates |
| **Environment Variables** | Simple values | LOG_LEVEL=info |
| **Volume Mounts** | Configuration files | config.yaml, nginx.conf |

---

## ConfigMaps

### What is a ConfigMap?

> **ConfigMap**: Kubernetes object for storing non-sensitive configuration data (key-value pairs or files)

```
ConfigMap:
  app_name: churn-mlops
  log_level: INFO
  feature_flags:
    enable_monitoring: true
    enable_cache: false
  config.yaml: |
    database:
      host: postgres
      port: 5432
```

### Creating ConfigMaps

**Method 1: From Literal Values**
```bash
kubectl create configmap app-config \
  --from-literal=LOG_LEVEL=info \
  --from-literal=DEBUG=false
```

**Method 2: From File**
```bash
# config.yaml
app:
  name: churn-mlops
  log_level: INFO

kubectl create configmap app-config --from-file=config.yaml
```

**Method 3: YAML Definition**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: churn-mlops-config
  namespace: churn-mlops
data:
  # Key-value pairs
  LOG_LEVEL: "INFO"
  DEBUG: "false"
  
  # File content
  config.yaml: |
    app:
      name: churn-mlops
      env: dev
      log_level: INFO
    
    paths:
      data: /app/data
      models: /app/artifacts/models
    
    features:
      windows_days: [7, 14, 30]
```

**Create**:
```bash
kubectl apply -f configmap.yaml
```

### ConfigMap Structure

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
  namespace: default
data:
  # Simple key-value (must be strings)
  key1: "value1"
  key2: "value2"
  
  # Multi-line value (YAML literal block)
  config.yaml: |
    line1
    line2
    line3
  
  # JSON
  config.json: |
    {
      "key": "value"
    }
```

---

## Secrets

### What is a Secret?

> **Secret**: Kubernetes object for storing sensitive data (base64-encoded)

**Important**: Secrets are **not encrypted** by default, only base64-encoded!
- Use RBAC to restrict access
- Use external secret managers (AWS Secrets Manager, HashiCorp Vault) for production

### Creating Secrets

**Method 1: From Literal**
```bash
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secretpass123
```

**Method 2: From File**
```bash
echo -n 'admin' > username.txt
echo -n 'secretpass123' > password.txt

kubectl create secret generic db-secret \
  --from-file=username=username.txt \
  --from-file=password=password.txt
```

**Method 3: YAML Definition**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: churn-mlops
type: Opaque
data:
  # Base64-encoded values
  username: YWRtaW4=          # echo -n 'admin' | base64
  password: c2VjcmV0cGFzczEyMw==  # echo -n 'secretpass123' | base64
```

**Create**:
```bash
kubectl apply -f secret.yaml
```

### Secret Types

| Type | Use Case |
|------|----------|
| `Opaque` | Generic (default) |
| `kubernetes.io/service-account-token` | Service account tokens |
| `kubernetes.io/dockerconfigjson` | Docker registry credentials |
| `kubernetes.io/tls` | TLS certificates |

### Docker Registry Secret

```bash
# Create secret for private registry
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myusername \
  --docker-password=mypassword \
  --docker-email=email@example.com

# Use in Pod
spec:
  imagePullSecrets:
    - name: regcred
```

### TLS Secret

```bash
# Create TLS secret
kubectl create secret tls tls-secret \
  --cert=path/to/cert.crt \
  --key=path/to/key.key
```

---

## Using ConfigMaps and Secrets

### Method 1: Environment Variables

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      image: my-app:latest
      
      # From ConfigMap
      env:
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: LOG_LEVEL
        
        - name: DEBUG
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DEBUG
      
      # From Secret
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: username
        
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
```

### Method 2: All Keys as Environment Variables

```yaml
spec:
  containers:
    - name: app
      image: my-app:latest
      
      # Import all ConfigMap keys as env vars
      envFrom:
        - configMapRef:
            name: app-config
      
      # Import all Secret keys as env vars
        - secretRef:
            name: db-secret
```

**Result**:
```bash
# Inside container
echo $LOG_LEVEL    # info
echo $DEBUG        # false
echo $DB_USERNAME  # admin
echo $DB_PASSWORD  # secretpass123
```

### Method 3: Volume Mounts (Files)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      image: my-app:latest
      
      volumeMounts:
        # Mount ConfigMap as file
        - name: config-volume
          mountPath: /app/config/config.yaml
          subPath: config.yaml
        
        # Mount Secret as file
        - name: secret-volume
          mountPath: /app/secrets
          readOnly: true
  
  volumes:
    # ConfigMap volume
    - name: config-volume
      configMap:
        name: app-config
    
    # Secret volume
    - name: secret-volume
      secret:
        secretName: db-secret
```

**Result**:
```bash
# Inside container
cat /app/config/config.yaml
# app:
#   name: churn-mlops
#   log_level: INFO

ls /app/secrets/
# username password

cat /app/secrets/username
# admin

cat /app/secrets/password
# secretpass123
```

### Comparison

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **Env Vars** | Simple values | ✅ Easy access in code | ❌ Visible in `kubectl describe` |
| **Volume Mounts** | Config files | ✅ File-based apps | ⚠️ More complex |
| **envFrom** | Many env vars | ✅ Import all at once | ⚠️ Key naming conventions |

---

## External Secrets

### Problem: Secrets in Git

```
❌ BAD: Secrets in Git

# secret.yaml (committed to Git)
apiVersion: v1
kind: Secret
data:
  password: c2VjcmV0cGFzczEyMw==  # Base64, easily decoded!

Problems:
- Secrets visible in Git history
- Anyone with repo access sees secrets
- Hard to rotate secrets
```

### Solution: External Secret Managers

```
✅ GOOD: External Secret Manager

Developer → Stores secret → AWS Secrets Manager
                          ↓
Kubernetes ← Fetches ← External Secrets Operator
             (runtime)
```

**Popular Solutions**:
- AWS Secrets Manager
- Azure Key Vault
- Google Secret Manager
- HashiCorp Vault
- Sealed Secrets (encrypts secrets for Git)

### Sealed Secrets (GitOps-Friendly)

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Install kubeseal CLI
brew install kubeseal  # Mac
choco install kubeseal  # Windows

# Create regular secret (not applied)
kubectl create secret generic db-secret \
  --from-literal=password=secretpass123 \
  --dry-run=client -o yaml > secret.yaml

# Seal secret (encrypted)
kubeseal -f secret.yaml -w sealed-secret.yaml

# sealed-secret.yaml is safe to commit!
git add sealed-secret.yaml
git commit -m "Add sealed secret"

# Apply sealed secret
kubectl apply -f sealed-secret.yaml
# Controller decrypts and creates real Secret
```

**Sealed Secret Example**:
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-secret
spec:
  encryptedData:
    password: AgBQxK7j2... (long encrypted string)
  # Can safely commit to Git!
```

---

## Best Practices

### 1. Never Hardcode Secrets

```yaml
# ❌ BAD
env:
  - name: API_KEY
    value: "sk-1234567890"  # Hardcoded!

# ✅ GOOD
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: api-secret
        key: api-key
```

### 2. Use Separate ConfigMaps per Environment

```
config/
├── configmap-dev.yaml
├── configmap-staging.yaml
└── configmap-prod.yaml

# Deploy to dev
kubectl apply -f configmap-dev.yaml

# Deploy to prod
kubectl apply -f configmap-prod.yaml
```

### 3. Immutable ConfigMaps (K8s 1.21+)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
immutable: true  # Can't be changed (must delete/recreate)
data:
  LOG_LEVEL: "INFO"
```

**Benefits**:
- Prevents accidental changes
- Forces pod restart on config change
- Improves performance (kube-apiserver doesn't watch)

### 4. RBAC for Secrets

```yaml
# Limit who can read secrets
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
subjects:
  - kind: User
    name: developer
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

### 5. Encrypt Secrets at Rest

```bash
# Enable encryption at rest (requires cluster admin)
# Add to kube-apiserver:
--encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

---

## Code Walkthrough

### File: `k8s/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: churn-mlops-config
  namespace: churn-mlops
data:
  config.yaml: |
    app:
      name: churn-mlops
      env: dev
      log_level: INFO
    
    paths:
      data: /app/data
      raw: /app/data/raw
      processed: /app/data/processed
      features: /app/data/features
      predictions: /app/data/predictions
      
      artifacts: /app/artifacts
      models: /app/artifacts/models
      metrics: /app/artifacts/metrics
    
    features:
      windows_days: [7, 14, 30]
    
    churn:
      window_days: 30
```

### File: `k8s/api-deployment.yaml` (Using ConfigMap)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-api
spec:
  template:
    spec:
      containers:
        - name: churn-api
          image: techitfactory/churn-api:0.1.0
          
          env:
            - name: CHURN_MLOPS_CONFIG
              value: /app/config/config.yaml
          
          volumeMounts:
            # Mount ConfigMap as file
            - name: config
              mountPath: /app/config/config.yaml
              subPath: config.yaml
      
      volumes:
        - name: config
          configMap:
            name: churn-mlops-config
```

---

## Hands-On Exercise

### Exercise 1: Create ConfigMap

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "DEBUG"
  DEBUG: "true"
  config.yaml: |
    app:
      name: my-app
      version: v1.0
```

**Commands**:
```bash
# Create
kubectl apply -f configmap.yaml

# View
kubectl get configmap app-config
kubectl describe configmap app-config

# Edit
kubectl edit configmap app-config

# Delete
kubectl delete configmap app-config
```

### Exercise 2: Create Secret

```bash
# From literal
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secretpass

# View (base64 encoded)
kubectl get secret db-secret -o yaml

# Decode
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 --decode
# Output: secretpass
```

### Exercise 3: Use ConfigMap in Pod

```yaml
# pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
    - name: app
      image: busybox
      command: ["sh", "-c", "echo LOG_LEVEL=$LOG_LEVEL && sleep 3600"]
      env:
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: LOG_LEVEL
```

**Commands**:
```bash
kubectl apply -f pod.yaml
kubectl logs test-pod
# Output: LOG_LEVEL=DEBUG
```

### Exercise 4: Mount ConfigMap as File

```yaml
# pod-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-pod
spec:
  containers:
    - name: app
      image: busybox
      command: ["sh", "-c", "cat /config/config.yaml && sleep 3600"]
      volumeMounts:
        - name: config-volume
          mountPath: /config
  volumes:
    - name: config-volume
      configMap:
        name: app-config
```

**Commands**:
```bash
kubectl apply -f pod-volume.yaml
kubectl logs config-pod
# Output: config.yaml content

kubectl exec -it config-pod -- ls /config
# config.yaml
```

### Exercise 5: Update ConfigMap (Hot Reload)

```bash
# Create ConfigMap
kubectl create configmap app-config --from-literal=MESSAGE="Hello v1"

# Create pod that reads it
kubectl run test --image=busybox --restart=Never -- sh -c 'while true; do cat /config/MESSAGE; sleep 5; done' --overrides='
{
  "spec": {
    "containers": [{
      "name": "test",
      "image": "busybox",
      "command": ["sh", "-c", "while true; do cat /config/MESSAGE && echo; sleep 5; done"],
      "volumeMounts": [{
        "name": "config",
        "mountPath": "/config"
      }]
    }],
    "volumes": [{
      "name": "config",
      "configMap": {
        "name": "app-config"
      }
    }]
  }
}'

# Watch logs
kubectl logs -f test
# Output: Hello v1

# Update ConfigMap
kubectl create configmap app-config --from-literal=MESSAGE="Hello v2" --dry-run=client -o yaml | kubectl apply -f -

# Wait ~60 seconds (kubelet sync period)
# Logs should show: Hello v2
```

---

## Assessment Questions

### Question 1: Multiple Choice
What's the difference between ConfigMap and Secret?

A) ConfigMap is for files, Secret is for key-value  
B) **ConfigMap is for non-sensitive data, Secret is for sensitive data** ✅  
C) ConfigMap is larger, Secret is smaller  
D) They are the same  

**Explanation**: ConfigMaps store config, Secrets store sensitive data (base64-encoded).

---

### Question 2: True/False
**Statement**: Secrets are encrypted by default in Kubernetes.

**Answer**: False ❌  
**Explanation**: Secrets are base64-encoded, not encrypted. Use encryption at rest or external secret managers for production.

---

### Question 3: Short Answer
How do you use a ConfigMap key as an environment variable?

**Answer**:
```yaml
env:
  - name: LOG_LEVEL
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: LOG_LEVEL
```

---

### Question 4: Code Fix
What's wrong?

```yaml
env:
  - name: PASSWORD
    value: "secretpass123"  # Problem!
```

**Answer**:
- Hardcoded secret (visible in Git, kubectl describe)
- Fix: Use Secret
  ```yaml
  env:
    - name: PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
  ```

---

### Question 5: Design Challenge
Design ConfigMap + Secret for API with database credentials and app config.

**Answer**:
```yaml
# ConfigMap (non-sensitive)
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "INFO"
  DB_HOST: "postgres"
  DB_PORT: "5432"
  DB_NAME: "churn"

---
# Secret (sensitive)
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: YWRtaW4=          # admin
  password: c2VjcmV0cGFzcw==  # secretpass

---
# Deployment
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: api
          env:
            # From ConfigMap
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: LOG_LEVEL
            - name: DB_HOST
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: DB_HOST
            
            # From Secret
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: password
```

---

## Key Takeaways

### ✅ What You Learned

1. **ConfigMaps**
   - Store non-sensitive config
   - Key-value or files
   - Use as env vars or volume mounts

2. **Secrets**
   - Store sensitive data
   - Base64-encoded (not encrypted!)
   - Use external secret managers for production

3. **Usage Patterns**
   - Env vars: Simple values
   - Volume mounts: Config files
   - envFrom: Import all keys

4. **Best Practices**
   - Never hardcode secrets
   - Separate ConfigMaps per environment
   - Use RBAC to restrict access
   - Consider external secret managers

5. **External Secrets**
   - AWS Secrets Manager
   - Sealed Secrets (GitOps)
   - HashiCorp Vault

---

## Next Steps

Continue to **[Section 19: Production Deployments](section-19-production-deployments.md)**

In the next section, we'll:
- Deploy to production clusters
- Implement monitoring and logging
- Set up CronJobs for batch scoring
- Handle persistent volumes

---

## Additional Resources

- [ConfigMaps Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)

---

**Progress**: 16/34 sections complete (47%) → **17/34 (50%)**
