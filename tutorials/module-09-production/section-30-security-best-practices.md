# Section 30: Security Best Practices

**Duration**: 3 hours  
**Level**: Advanced  
**Prerequisites**: All previous modules

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Implement Kubernetes security best practices
- ✅ Secure ML model access and versioning
- ✅ Manage secrets and sensitive data
- ✅ Implement network policies and RBAC
- ✅ Scan containers for vulnerabilities
- ✅ Secure API authentication and authorization
- ✅ Implement data privacy and compliance measures

---

## 📚 Table of Contents

1. [Security Fundamentals](#security-fundamentals)
2. [Kubernetes Security](#kubernetes-security)
3. [Secret Management](#secret-management)
4. [Container Security](#container-security)
5. [API Security](#api-security)
6. [ML Model Security](#ml-model-security)
7. [Data Privacy](#data-privacy)
8. [Security Scanning](#security-scanning)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## Security Fundamentals

### Security Layers

```
┌────────────────────────────────────────────┐
│  Defense in Depth                           │
├────────────────────────────────────────────┤
│                                             │
│  Layer 1: Infrastructure Security           │
│  - Network isolation                        │
│  - Firewall rules                           │
│  - VPC configuration                        │
│                                             │
│  Layer 2: Cluster Security                  │
│  - RBAC policies                            │
│  - Network policies                         │
│  - Pod security standards                   │
│                                             │
│  Layer 3: Container Security                │
│  - Vulnerability scanning                   │
│  - Non-root users                           │
│  - Read-only filesystems                    │
│                                             │
│  Layer 4: Application Security              │
│  - Authentication/Authorization             │
│  - Input validation                         │
│  - Secure dependencies                      │
│                                             │
│  Layer 5: Data Security                     │
│  - Encryption at rest                       │
│  - Encryption in transit                    │
│  - Access logging                           │
│                                             │
└────────────────────────────────────────────┘
```

### OWASP Top 10 for MLOps

1. **Model Theft**: Unauthorized access to trained models
2. **Data Poisoning**: Malicious training data injection
3. **Model Inversion**: Extracting training data from model
4. **Adversarial Examples**: Crafted inputs causing misclassification
5. **Model Backdoors**: Hidden behaviors triggered by specific inputs
6. **Supply Chain Attacks**: Compromised dependencies
7. **Sensitive Data Exposure**: PII leakage in logs/metrics
8. **Insecure APIs**: Unauthenticated prediction endpoints
9. **Insufficient Logging**: Missing audit trails
10. **Denial of Service**: Resource exhaustion attacks

---

## Kubernetes Security

### RBAC (Role-Based Access Control)

```yaml
# k8s/security/rbac.yaml
---
# Service account for API pods
apiVersion: v1
kind: ServiceAccount
metadata:
  name: churn-api
  namespace: churn-mlops
automountServiceAccountToken: true

---
# Role: What can be done
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: churn-api-role
  namespace: churn-mlops
rules:
  # Allow reading ConfigMaps
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
  
  # Allow reading Secrets (model credentials)
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
    resourceNames: ["model-credentials"]
  
  # Deny writing to Secrets
  # (implicit - not listed means denied)

---
# RoleBinding: Who can do it
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: churn-api-rolebinding
  namespace: churn-mlops
subjects:
  - kind: ServiceAccount
    name: churn-api
    namespace: churn-mlops
roleRef:
  kind: Role
  name: churn-api-role
  apiGroup: rbac.authorization.k8s.io

---
# ClusterRole for monitoring (read-only across namespaces)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints"]
    verbs: ["get", "list", "watch"]
  
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]

---
# Service account for CI/CD
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-cd-deployer
  namespace: churn-mlops

---
# Role for CI/CD (can deploy but not delete)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-cd-deployer-role
  namespace: churn-mlops
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "create", "update", "patch"]
  
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "create", "update", "patch"]
  
  # No delete permissions
```

### Network Policies

```yaml
# k8s/security/network-policies.yaml
---
# Default deny all ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: churn-mlops
spec:
  podSelector: {}
  policyTypes:
    - Ingress

---
# Allow ingress to API from ingress controller only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-ingress
  namespace: churn-mlops
spec:
  podSelector:
    matchLabels:
      app: churn-api
  policyTypes:
    - Ingress
  ingress:
    # From ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8000
    
    # From Prometheus (for metrics)
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
        - podSelector:
            matchLabels:
              app: prometheus
      ports:
        - protocol: TCP
          port: 8000

---
# API can access database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-to-database
  namespace: churn-mlops
spec:
  podSelector:
    matchLabels:
      app: churn-api
  policyTypes:
    - Egress
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
    
    # Allow database
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    
    # Allow MLflow
    - to:
        - podSelector:
            matchLabels:
              app: mlflow
      ports:
        - protocol: TCP
          port: 5000
    
    # Allow external APIs (e.g., S3)
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443

---
# Database only accessible from API
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-access
  namespace: churn-mlops
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: churn-api
      ports:
        - protocol: TCP
          port: 5432
```

### Pod Security Standards

```yaml
# k8s/security/pod-security.yaml
---
# Pod Security admission controller
apiVersion: v1
kind: Namespace
metadata:
  name: churn-mlops
  labels:
    # Enforce restricted security standard
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

---
# Secure deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-api-secure
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
      # Use dedicated service account
      serviceAccountName: churn-api
      
      # Security context for pod
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      
      containers:
        - name: api
          image: churn-api:v1.2.3
          
          # Security context for container
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            runAsUser: 1000
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          
          # Resource limits (prevent DoS)
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 2000m
              memory: 2Gi
          
          # Liveness/readiness probes
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 30
            periodSeconds: 10
          
          readinessProbe:
            httpGet:
              path: /ready
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 5
          
          # Environment variables from secrets
          env:
            - name: DATABASE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: database-credentials
                  key: password
            
            - name: MLFLOW_TRACKING_TOKEN
              valueFrom:
                secretKeyRef:
                  name: mlflow-credentials
                  key: token
          
          # Writable tmp directory
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/.cache
      
      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}
```

---

## Secret Management

### Kubernetes Secrets

```yaml
# k8s/security/secrets.yaml
---
# Database credentials
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: churn-mlops
type: Opaque
stringData:
  username: churn_user
  password: "CHANGE_ME"  # Replace with actual password
  host: postgres.churn-mlops.svc.cluster.local
  port: "5432"
  database: churn_db

---
# MLflow credentials
apiVersion: v1
kind: Secret
metadata:
  name: mlflow-credentials
  namespace: churn-mlops
type: Opaque
stringData:
  tracking_uri: http://mlflow:5000
  token: "MLFLOW_TOKEN"

---
# API keys
apiVersion: v1
kind: Secret
metadata:
  name: api-keys
  namespace: churn-mlops
type: Opaque
stringData:
  api_key: "API_KEY_VALUE"
  jwt_secret: "JWT_SECRET_KEY"

---
# S3 credentials
apiVersion: v1
kind: Secret
metadata:
  name: s3-credentials
  namespace: churn-mlops
type: Opaque
stringData:
  access_key_id: "AWS_ACCESS_KEY_ID"
  secret_access_key: "AWS_SECRET_ACCESS_KEY"
  bucket: "churn-mlops-artifacts"
  region: "us-east-1"
```

### External Secret Operator

```yaml
# k8s/security/external-secret.yaml
---
# Install External Secrets Operator
# helm repo add external-secrets https://charts.external-secrets.io
# helm install external-secrets external-secrets/external-secrets -n external-secrets-system

# SecretStore (connects to AWS Secrets Manager)
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: churn-mlops
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa

---
# ExternalSecret (syncs from AWS)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: churn-mlops
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  
  target:
    name: database-credentials
    creationPolicy: Owner
  
  data:
    - secretKey: username
      remoteRef:
        key: churn-mlops/database
        property: username
    
    - secretKey: password
      remoteRef:
        key: churn-mlops/database
        property: password
```

### Sealed Secrets

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI
brew install kubeseal  # macOS
# or download from GitHub releases

# Create regular secret (not committed)
kubectl create secret generic database-credentials \
  --from-literal=password=SuperSecret123 \
  --dry-run=client -o yaml > secret.yaml

# Seal the secret
kubeseal -f secret.yaml -w sealed-secret.yaml

# sealed-secret.yaml can be safely committed to Git
```

```yaml
# k8s/security/sealed-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: database-credentials
  namespace: churn-mlops
spec:
  encryptedData:
    password: AgBxY3J5cHRlZF9kYXRhX2hlcmU...
  template:
    metadata:
      name: database-credentials
      namespace: churn-mlops
```

### Secret Usage in Python

```python
# src/churn_mlops/utils/secrets.py
import os
from typing import Optional
from pathlib import Path

class SecretManager:
    """Manage secrets from environment or files."""
    
    def __init__(self, secrets_dir: str = "/run/secrets"):
        self.secrets_dir = Path(secrets_dir)
    
    def get_secret(self, name: str) -> str:
        """Get secret from environment or file."""
        # 1. Try environment variable
        env_value = os.getenv(name)
        if env_value:
            return env_value
        
        # 2. Try file (Kubernetes mounted secret)
        secret_file = self.secrets_dir / name
        if secret_file.exists():
            return secret_file.read_text().strip()
        
        raise ValueError(f"Secret '{name}' not found")
    
    def get_database_url(self) -> str:
        """Build database URL from secrets."""
        username = self.get_secret("DATABASE_USERNAME")
        password = self.get_secret("DATABASE_PASSWORD")
        host = self.get_secret("DATABASE_HOST")
        port = self.get_secret("DATABASE_PORT")
        database = self.get_secret("DATABASE_NAME")
        
        return f"postgresql://{username}:{password}@{host}:{port}/{database}"


# Usage
secrets = SecretManager()
db_url = secrets.get_database_url()
mlflow_token = secrets.get_secret("MLFLOW_TRACKING_TOKEN")
```

---

## Container Security

### Dockerfile Security

```dockerfile
# docker/Dockerfile.api.secure
# Use specific version (not latest)
FROM python:3.11.6-slim AS builder

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Install dependencies as root
WORKDIR /build
COPY requirements/base.txt requirements/api.txt ./
RUN pip install --no-cache-dir --user -r api.txt

# Runtime stage
FROM python:3.11.6-slim

# Install security updates
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appuser && \
    useradd -r -g appuser appuser && \
    mkdir -p /app /tmp/app && \
    chown -R appuser:appuser /app /tmp/app

# Copy dependencies from builder
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# Copy application code
WORKDIR /app
COPY --chown=appuser:appuser src/ ./src/

# Set PATH for user packages
ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Switch to non-root user
USER appuser

# Expose port (non-privileged)
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8000/health')"

# Run application
CMD ["uvicorn", "churn_mlops.api.app:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Vulnerability Scanning

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  trivy-scan:
    name: Trivy Container Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build image
        run: docker build -f docker/Dockerfile.api -t churn-api:test .
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: churn-api:test
          format: sarif
          output: trivy-results.sarif
          severity: CRITICAL,HIGH
          exit-code: 1  # Fail on vulnerabilities
      
      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: trivy-results.sarif
  
  snyk-scan:
    name: Snyk Dependency Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Snyk to check for vulnerabilities
        uses: snyk/actions/python@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high --fail-on=all
      
      - name: Upload Snyk results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: snyk.sarif
  
  codeql-scan:
    name: CodeQL Analysis
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Initialize CodeQL
        uses: github/codeql-action/init@v2
        with:
          languages: python
      
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v2
```

### Image Signing

```bash
# Install Cosign
brew install cosign

# Generate key pair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key ghcr.io/yourorg/churn-api:v1.2.3

# Verify signature
cosign verify --key cosign.pub ghcr.io/yourorg/churn-api:v1.2.3

# Kubernetes admission controller to verify signatures
# Install Sigstore Policy Controller
kubectl apply -f https://github.com/sigstore/policy-controller/releases/download/v0.6.0/release.yaml

# Policy to require signed images
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: signed-images-policy
spec:
  images:
    - glob: "ghcr.io/yourorg/*"
  authorities:
    - keyless:
        url: https://fulcio.sigstore.dev
```

---

## API Security

### Authentication

```python
# src/churn_mlops/api/auth.py
from fastapi import Depends, HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional
import os

# JWT configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "CHANGE_ME")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

security = HTTPBearer()

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create JWT access token."""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)) -> dict:
    """Verify JWT token."""
    token = credentials.credentials
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        
        return payload
    
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

# Usage in endpoints
from fastapi import FastAPI

app = FastAPI()

@app.post("/predict")
async def predict(
    request: PredictionRequest,
    token_data: dict = Depends(verify_token)
):
    """Protected endpoint requiring authentication."""
    user_id = token_data.get("sub")
    
    # Log request with user
    logger.info(f"Prediction request from user {user_id}")
    
    # Make prediction
    result = model.predict(request.features)
    
    return result
```

### API Key Authentication

```python
# src/churn_mlops/api/api_key_auth.py
from fastapi import Security, HTTPException
from fastapi.security import APIKeyHeader
import os
import hashlib

API_KEY_HEADER = APIKeyHeader(name="X-API-Key")

# Store hashed API keys
VALID_API_KEYS = {
    hashlib.sha256("key1".encode()).hexdigest(): "user1",
    hashlib.sha256("key2".encode()).hexdigest(): "user2",
}

def verify_api_key(api_key: str = Security(API_KEY_HEADER)) -> str:
    """Verify API key and return user."""
    key_hash = hashlib.sha256(api_key.encode()).hexdigest()
    
    if key_hash not in VALID_API_KEYS:
        raise HTTPException(status_code=401, detail="Invalid API key")
    
    return VALID_API_KEYS[key_hash]

# Usage
@app.post("/predict")
async def predict(
    request: PredictionRequest,
    user: str = Depends(verify_api_key)
):
    logger.info(f"Prediction from {user}")
    return model.predict(request.features)
```

### Rate Limiting

```python
# src/churn_mlops/api/rate_limit.py
from fastapi import HTTPException, Request
from datetime import datetime, timedelta
from collections import defaultdict
import asyncio

class RateLimiter:
    """Simple in-memory rate limiter."""
    
    def __init__(self, calls: int, period: int):
        self.calls = calls
        self.period = period  # seconds
        self.requests = defaultdict(list)
    
    async def check_rate_limit(self, key: str) -> None:
        """Check if request exceeds rate limit."""
        now = datetime.utcnow()
        cutoff = now - timedelta(seconds=self.period)
        
        # Remove old requests
        self.requests[key] = [
            req_time for req_time in self.requests[key]
            if req_time > cutoff
        ]
        
        # Check limit
        if len(self.requests[key]) >= self.calls:
            raise HTTPException(
                status_code=429,
                detail=f"Rate limit exceeded: {self.calls} calls per {self.period}s"
            )
        
        # Record request
        self.requests[key].append(now)

# Create rate limiter
rate_limiter = RateLimiter(calls=100, period=60)  # 100 calls per minute

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    """Apply rate limiting."""
    # Use API key or IP as identifier
    api_key = request.headers.get("X-API-Key", request.client.host)
    
    try:
        await rate_limiter.check_rate_limit(api_key)
    except HTTPException as e:
        return JSONResponse(
            status_code=e.status_code,
            content={"detail": e.detail}
        )
    
    response = await call_next(request)
    return response
```

### Input Validation

```python
# src/churn_mlops/api/models.py
from pydantic import BaseModel, Field, validator
from typing import Dict, Any

class PredictionRequest(BaseModel):
    """Validated prediction request."""
    
    features: Dict[str, Any] = Field(
        ...,
        description="Feature values",
        example={"age": 35, "tenure": 12, "monthly_charges": 65.5}
    )
    
    @validator("features")
    def validate_features(cls, v):
        """Validate feature values."""
        required_features = {"age", "tenure", "monthly_charges"}
        
        # Check required features
        missing = required_features - set(v.keys())
        if missing:
            raise ValueError(f"Missing required features: {missing}")
        
        # Validate types and ranges
        if not isinstance(v["age"], (int, float)) or v["age"] < 0 or v["age"] > 120:
            raise ValueError("age must be between 0 and 120")
        
        if not isinstance(v["tenure"], (int, float)) or v["tenure"] < 0:
            raise ValueError("tenure must be non-negative")
        
        if not isinstance(v["monthly_charges"], (int, float)) or v["monthly_charges"] < 0:
            raise ValueError("monthly_charges must be non-negative")
        
        return v
    
    class Config:
        schema_extra = {
            "example": {
                "features": {
                    "age": 35,
                    "tenure": 12,
                    "monthly_charges": 65.5
                }
            }
        }
```

---

## ML Model Security

### Model Access Control

```python
# src/churn_mlops/models/secure_loader.py
import mlflow
import hashlib
import os
from pathlib import Path

class SecureModelLoader:
    """Load models with integrity checks."""
    
    def __init__(self, mlflow_uri: str, token: str):
        mlflow.set_tracking_uri(mlflow_uri)
        os.environ["MLFLOW_TRACKING_TOKEN"] = token
    
    def load_model(
        self,
        model_name: str,
        version: str,
        expected_checksum: str
    ):
        """Load model and verify integrity."""
        # Download model
        model_uri = f"models:/{model_name}/{version}"
        model_path = mlflow.artifacts.download_artifacts(model_uri)
        
        # Calculate checksum
        checksum = self._calculate_checksum(model_path)
        
        # Verify
        if checksum != expected_checksum:
            raise ValueError(
                f"Model checksum mismatch: {checksum} != {expected_checksum}"
            )
        
        # Load model
        model = mlflow.pyfunc.load_model(model_uri)
        
        return model
    
    def _calculate_checksum(self, path: str) -> str:
        """Calculate SHA256 checksum of model directory."""
        hasher = hashlib.sha256()
        
        for file_path in sorted(Path(path).rglob("*")):
            if file_path.is_file():
                with open(file_path, "rb") as f:
                    hasher.update(f.read())
        
        return hasher.hexdigest()

# Usage
loader = SecureModelLoader(
    mlflow_uri="https://mlflow.example.com",
    token=os.getenv("MLFLOW_TOKEN")
)

model = loader.load_model(
    model_name="churn-model",
    version="3",
    expected_checksum="abc123def456..."
)
```

### Model Versioning Registry

```yaml
# k8s/security/model-versions.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-versions
  namespace: churn-mlops
data:
  models.json: |
    {
      "approved_models": [
        {
          "name": "churn-model",
          "version": "3",
          "checksum": "abc123def456789...",
          "approved_by": "ml-team@example.com",
          "approved_at": "2023-12-15T10:30:00Z",
          "performance": {
            "accuracy": 0.87,
            "precision": 0.85,
            "recall": 0.89
          }
        }
      ],
      "deprecated_models": [
        {
          "name": "churn-model",
          "version": "2",
          "deprecated_at": "2023-12-01T00:00:00Z",
          "reason": "Lower accuracy"
        }
      ]
    }
```

---

## Data Privacy

### PII Redaction

```python
# src/churn_mlops/utils/privacy.py
import re
from typing import Any, Dict

class PIIRedactor:
    """Redact personally identifiable information."""
    
    # Regex patterns
    EMAIL_PATTERN = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
    PHONE_PATTERN = r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'
    SSN_PATTERN = r'\b\d{3}-\d{2}-\d{4}\b'
    CREDIT_CARD_PATTERN = r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'
    
    @classmethod
    def redact_string(cls, text: str) -> str:
        """Redact PII from string."""
        # Email
        text = re.sub(cls.EMAIL_PATTERN, '[EMAIL]', text)
        
        # Phone
        text = re.sub(cls.PHONE_PATTERN, '[PHONE]', text)
        
        # SSN
        text = re.sub(cls.SSN_PATTERN, '[SSN]', text)
        
        # Credit card
        text = re.sub(cls.CREDIT_CARD_PATTERN, '[CREDIT_CARD]', text)
        
        return text
    
    @classmethod
    def redact_dict(cls, data: Dict[str, Any]) -> Dict[str, Any]:
        """Redact PII from dictionary."""
        redacted = {}
        
        pii_fields = {'email', 'phone', 'ssn', 'credit_card', 'address'}
        
        for key, value in data.items():
            if key.lower() in pii_fields:
                redacted[key] = '[REDACTED]'
            elif isinstance(value, str):
                redacted[key] = cls.redact_string(value)
            elif isinstance(value, dict):
                redacted[key] = cls.redact_dict(value)
            else:
                redacted[key] = value
        
        return redacted

# Usage in logging
import logging

logger = logging.getLogger(__name__)

@app.post("/predict")
def predict(request: PredictionRequest):
    # Redact before logging
    safe_features = PIIRedactor.redact_dict(request.features)
    logger.info(f"Prediction request: {safe_features}")
    
    result = model.predict(request.features)
    return result
```

### Data Encryption

```python
# src/churn_mlops/utils/encryption.py
from cryptography.fernet import Fernet
import os
import base64

class DataEncryptor:
    """Encrypt sensitive data at rest."""
    
    def __init__(self):
        # Get encryption key from environment
        key = os.getenv("ENCRYPTION_KEY")
        if not key:
            raise ValueError("ENCRYPTION_KEY not set")
        
        self.cipher = Fernet(key.encode())
    
    def encrypt(self, data: str) -> str:
        """Encrypt string data."""
        encrypted = self.cipher.encrypt(data.encode())
        return base64.urlsafe_b64encode(encrypted).decode()
    
    def decrypt(self, encrypted_data: str) -> str:
        """Decrypt string data."""
        decoded = base64.urlsafe_b64decode(encrypted_data.encode())
        decrypted = self.cipher.decrypt(decoded)
        return decrypted.decode()

# Generate key (once)
def generate_key():
    return Fernet.generate_key().decode()

# Usage
encryptor = DataEncryptor()

# Encrypt before storing
sensitive_data = "customer_id_12345"
encrypted = encryptor.encrypt(sensitive_data)
# Store encrypted value

# Decrypt when needed
decrypted = encryptor.decrypt(encrypted)
```

---

## Security Scanning

### Automated Security Checks

```bash
# scripts/security_check.sh
#!/bin/bash
set -e

echo "Running security checks..."

# 1. Dependency vulnerability scan
echo "Checking Python dependencies..."
pip-audit --strict

# 2. Code security analysis
echo "Running Bandit security linter..."
bandit -r src/ -ll

# 3. Secret scanning
echo "Scanning for secrets..."
trufflehog git file://. --only-verified

# 4. Container scan
echo "Scanning container image..."
docker build -f docker/Dockerfile.api -t churn-api:test .
trivy image --severity HIGH,CRITICAL churn-api:test

# 5. Infrastructure as Code scan
echo "Scanning Kubernetes manifests..."
kubesec scan k8s/*.yaml

echo "✅ All security checks passed"
```

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
  
  - repo: https://github.com/PyCQA/bandit
    rev: 1.7.5
    hooks:
      - id: bandit
        args: ['-ll']
  
  - repo: https://github.com/trufflesecurity/trufflehog
    rev: v3.63.0
    hooks:
      - id: trufflehog
        name: TruffleHog
        entry: bash -c 'trufflehog git file://. --only-verified --fail'
```

---

## Hands-On Exercise

### Exercise 1: Implement RBAC

```bash
# Create service account
kubectl apply -f k8s/security/rbac.yaml

# Update deployment to use it
kubectl patch deployment churn-api -n churn-mlops \
  -p '{"spec":{"template":{"spec":{"serviceAccountName":"churn-api"}}}}'

# Test permissions
kubectl auth can-i get secrets --as=system:serviceaccount:churn-mlops:churn-api -n churn-mlops
# yes

kubectl auth can-i delete secrets --as=system:serviceaccount:churn-mlops:churn-api -n churn-mlops
# no
```

### Exercise 2: Create Sealed Secret

```bash
# Install kubeseal
brew install kubeseal

# Create secret
kubectl create secret generic test-secret \
  --from-literal=password=secret123 \
  --dry-run=client -o yaml > test-secret.yaml

# Seal it
kubeseal -f test-secret.yaml -w test-sealed-secret.yaml

# Apply sealed secret
kubectl apply -f test-sealed-secret.yaml -n churn-mlops

# Verify unsealed
kubectl get secret test-secret -n churn-mlops -o jsonpath='{.data.password}' | base64 -d
```

### Exercise 3: Run Security Scan

```bash
# Install Trivy
brew install aquasecurity/trivy/trivy

# Build image
docker build -f docker/Dockerfile.api -t churn-api:test .

# Scan for vulnerabilities
trivy image churn-api:test

# Scan with severity filter
trivy image --severity HIGH,CRITICAL churn-api:test
```

### Exercise 4: Implement API Key Auth

```python
# Add to src/churn_mlops/api/app.py
from churn_mlops.api.api_key_auth import verify_api_key

@app.post("/predict")
async def predict(
    request: PredictionRequest,
    user: str = Depends(verify_api_key)
):
    logger.info(f"Prediction from {user}")
    result = model.predict(request.features)
    return result

# Test
curl -X POST http://localhost:8000/predict \
  -H "X-API-Key: key1" \
  -H "Content-Type: application/json" \
  -d '{"features": {...}}'
```

### Exercise 5: Apply Network Policies

```bash
# Apply network policies
kubectl apply -f k8s/security/network-policies.yaml

# Test connectivity
# Should work:
kubectl run test --rm -it --image=busybox -n churn-mlops -- wget -O- http://churn-api:8000/health

# Should fail:
kubectl run test --rm -it --image=busybox -n default -- wget -O- http://churn-api.churn-mlops:8000/health
```

---

## Assessment Questions

### Question 1: Multiple Choice
Which security practice is most important for ML model security?

A) Encrypting model files  
B) **Verifying model integrity with checksums** ✅  
C) Obfuscating model code  
D) Using proprietary formats  

---

### Question 2: True/False
**Statement**: Running containers as root is acceptable if the application requires it.

**Answer**: False ❌  
**Explanation**: Containers should **always run as non-root users**. If elevated privileges are needed, use capabilities or init containers instead of running as root.

---

### Question 3: Short Answer
What's the difference between RBAC Role and ClusterRole?

**Answer**:
- **Role**: Namespace-scoped permissions (e.g., access secrets in churn-mlops namespace)
- **ClusterRole**: Cluster-wide permissions (e.g., view pods in all namespaces)

Example:
- Role: CI/CD can deploy to churn-mlops namespace
- ClusterRole: Prometheus can read metrics from all namespaces

---

### Question 4: Code Analysis
What security issues exist in this code?

```python
@app.post("/predict")
def predict(customer_id: str, features: dict):
    logger.info(f"Prediction for {customer_id}: {features}")
    
    query = f"SELECT * FROM customers WHERE id = '{customer_id}'"
    result = db.execute(query)
    
    return model.predict(features)
```

**Answer**:

**Security Issues**:
1. **SQL Injection**: Direct string interpolation in query
2. **PII Logging**: Customer ID logged in plain text
3. **No Input Validation**: Features dict not validated
4. **No Authentication**: Endpoint is public
5. **No Rate Limiting**: Vulnerable to DoS

**Fixed Version**:
```python
from fastapi import Depends
from churn_mlops.api.auth import verify_api_key
from churn_mlops.api.models import PredictionRequest
from churn_mlops.utils.privacy import PIIRedactor

@app.post("/predict")
@rate_limiter(calls=100, period=60)
async def predict(
    request: PredictionRequest,
    user: str = Depends(verify_api_key)
):
    # Redact PII before logging
    safe_features = PIIRedactor.redact_dict(request.features)
    logger.info(f"Prediction from {user}: {safe_features}")
    
    # Parameterized query (prevents SQL injection)
    query = "SELECT * FROM customers WHERE id = :id"
    result = db.execute(query, {"id": request.customer_id})
    
    # Validated input
    return model.predict(request.features)
```

---

### Question 5: Design Challenge
Design a security strategy for an ML prediction API handling sensitive customer data.

**Answer**:

```yaml
# Comprehensive Security Strategy

1. Authentication & Authorization:
   - JWT tokens with 30-minute expiration
   - API keys for service-to-service
   - Rate limiting: 100 requests/minute per key
   - RBAC: Separate roles for read/write

2. Data Protection:
   - Encrypt sensitive features at rest (AES-256)
   - TLS 1.3 for all network traffic
   - PII redaction in logs
   - No PII in metrics/monitoring

3. Infrastructure Security:
   - Non-root containers
   - Read-only filesystem
   - Network policies (default deny)
   - Pod security standards (restricted)

4. Model Security:
   - Model integrity verification (SHA256)
   - Version control with approval process
   - Signed container images (Cosign)
   - Audit log of model loads

5. Vulnerability Management:
   - Daily Trivy scans
   - Automated dependency updates (Dependabot)
   - SAST/DAST in CI/CD
   - Secret scanning (TruffleHog)

6. Monitoring & Auditing:
   - Log all API access (who, when, what)
   - Alert on anomalous patterns
   - Retain logs for 90 days
   - Monthly security reviews

7. Compliance:
   - GDPR: Data minimization, right to deletion
   - HIPAA: Encryption, access controls
   - SOC 2: Audit trails, change management

8. Incident Response:
   - Runbooks for common scenarios
   - On-call rotation
   - Automated alerting
   - Post-incident reviews

Implementation:
```python
# app.py with full security
from fastapi import FastAPI, Depends
from churn_mlops.api.auth import verify_token
from churn_mlops.api.rate_limit import rate_limiter
from churn_mlops.api.models import PredictionRequest
from churn_mlops.utils.privacy import PIIRedactor
from churn_mlops.utils.encryption import DataEncryptor
from churn_mlops.models.secure_loader import SecureModelLoader

app = FastAPI()

# Middleware
app.middleware("http")(rate_limiter.middleware)
app.middleware("http")(audit_logger.middleware)

# Secure model loading
model = SecureModelLoader().load_model(
    name="churn-model",
    version="3",
    checksum="abc123..."
)

@app.post("/predict")
async def predict(
    request: PredictionRequest,
    token: dict = Depends(verify_token)
):
    user_id = token["sub"]
    
    # Audit log
    audit_logger.log("prediction_request", {
        "user_id": user_id,
        "timestamp": datetime.utcnow(),
        "ip": request.client.host
    })
    
    # Redact PII before processing
    safe_features = PIIRedactor.redact_dict(request.features)
    logger.info(f"Prediction: {safe_features}")
    
    # Make prediction
    result = model.predict(request.features)
    
    # Encrypt sensitive result
    if result["confidence"] < 0.7:
        result["warning"] = "Low confidence"
    
    return result
```

---

## Key Takeaways

### ✅ What You Learned

1. **Defense in Depth**
   - Multiple security layers
   - OWASP Top 10 for MLOps

2. **Kubernetes Security**
   - RBAC for access control
   - Network policies for isolation
   - Pod security standards

3. **Secret Management**
   - Kubernetes Secrets
   - External Secrets Operator
   - Sealed Secrets

4. **Container Security**
   - Non-root users
   - Vulnerability scanning
   - Image signing

5. **API Security**
   - Authentication (JWT, API keys)
   - Rate limiting
   - Input validation

6. **ML Model Security**
   - Integrity verification
   - Access control
   - Version registry

7. **Data Privacy**
   - PII redaction
   - Encryption
   - Compliance (GDPR, HIPAA)

---

## Next Steps

Continue to **[Section 31: Performance Optimization](./section-31-performance-optimization.md)**

In the next section, we'll cover:
- API performance tuning
- Model inference optimization
- Caching strategies
- Resource optimization

---

## Additional Resources

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [OWASP ML Security](https://owasp.org/www-project-machine-learning-security-top-10/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [NIST AI Risk Management](https://www.nist.gov/itl/ai-risk-management-framework)

---

**Progress**: 28/34 sections complete (82%) → **29/34 (85%)**
