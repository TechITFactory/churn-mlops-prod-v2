# Section 34: MLOps Capstone Project - Part 2: Deployment & API

**Duration**: 4 hours  
**Level**: Advanced  
**Prerequisites**: Section 33 (Capstone Part 1)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Deploy model with FastAPI real-time API
- ✅ Implement batch scoring pipeline
- ✅ Configure Kubernetes deployments
- ✅ Set up CI/CD with GitHub Actions
- ✅ Implement GitOps with ArgoCD
- ✅ Configure monitoring and alerting

---

## Phase 3: Model Deployment

### Step 1: Real-Time API

```python
# src/churn_mlops/api/main.py
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, Field, validator
from typing import List, Optional
import mlflow
import numpy as np
import pandas as pd
from contextlib import asynccontextmanager
import logging
from prometheus_client import Counter, Histogram, generate_latest
import time

logger = logging.getLogger(__name__)

# Prometheus metrics
PREDICTION_COUNTER = Counter(
    'churn_predictions_total',
    'Total predictions made',
    ['model_version']
)

PREDICTION_LATENCY = Histogram(
    'churn_prediction_latency_seconds',
    'Prediction latency in seconds',
    buckets=[0.01, 0.05, 0.1, 0.5, 1.0, 2.0]
)

# Pydantic models
class PredictionRequest(BaseModel):
    """Request schema for churn prediction."""
    
    customer_id: str = Field(..., description="Unique customer identifier")
    age: int = Field(..., ge=18, le=100, description="Customer age")
    gender: str = Field(..., description="Customer gender")
    location: str = Field(..., description="Customer location")
    contract_type: str = Field(..., description="Contract type")
    payment_method: str = Field(..., description="Payment method")
    avg_data_usage: float = Field(..., ge=0, description="Average data usage in GB")
    avg_call_minutes: float = Field(..., ge=0, description="Average call minutes")
    usage_days: int = Field(..., ge=0, description="Number of usage days")
    avg_monthly_charges: float = Field(..., gt=0, description="Average monthly charges")
    late_payments: int = Field(..., ge=0, description="Number of late payments")
    tenure: int = Field(..., ge=0, description="Tenure in months")
    
    @validator('gender')
    def validate_gender(cls, v):
        allowed = ['Male', 'Female', 'Other']
        if v not in allowed:
            raise ValueError(f'Gender must be one of {allowed}')
        return v
    
    @validator('contract_type')
    def validate_contract(cls, v):
        allowed = ['Month-to-month', 'One year', 'Two year']
        if v not in allowed:
            raise ValueError(f'Contract type must be one of {allowed}')
        return v
    
    class Config:
        schema_extra = {
            "example": {
                "customer_id": "CUST-12345",
                "age": 35,
                "gender": "Female",
                "location": "New York",
                "contract_type": "Month-to-month",
                "payment_method": "Credit card",
                "avg_data_usage": 15.5,
                "avg_call_minutes": 450.0,
                "usage_days": 28,
                "avg_monthly_charges": 75.50,
                "late_payments": 0,
                "tenure": 24
            }
        }

class PredictionResponse(BaseModel):
    """Response schema for churn prediction."""
    
    customer_id: str
    churn_probability: float = Field(..., ge=0, le=1)
    will_churn: bool
    risk_category: str
    confidence: float
    model_version: str
    prediction_timestamp: str

class BatchPredictionRequest(BaseModel):
    """Request schema for batch predictions."""
    
    customers: List[PredictionRequest]

class HealthResponse(BaseModel):
    """Health check response."""
    
    status: str
    model_loaded: bool
    model_version: Optional[str]
    uptime_seconds: float

# FastAPI app
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle."""
    # Startup: Load model
    logger.info("Loading model...")
    
    # Load latest production model from MLflow
    model_uri = "models:/churn-model/Production"
    app.state.model = mlflow.pyfunc.load_model(model_uri)
    app.state.model_version = mlflow.tracking.MlflowClient().get_model_version_by_alias(
        "churn-model", "Production"
    ).version
    
    app.state.start_time = time.time()
    logger.info(f"Model loaded: version {app.state.model_version}")
    
    yield
    
    # Shutdown
    logger.info("Shutting down...")

app = FastAPI(
    title="Churn Prediction API",
    description="Real-time customer churn prediction service",
    version="1.0.0",
    lifespan=lifespan
)

# Routes
@app.get("/", response_model=dict)
async def root():
    """Root endpoint."""
    return {
        "service": "Churn Prediction API",
        "version": "1.0.0",
        "docs": "/docs"
    }

@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint."""
    return HealthResponse(
        status="healthy",
        model_loaded=hasattr(app.state, 'model'),
        model_version=getattr(app.state, 'model_version', None),
        uptime_seconds=time.time() - app.state.start_time
    )

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """
    Predict churn for a single customer.
    
    Returns:
        Churn probability and risk assessment
    """
    start_time = time.time()
    
    try:
        # Convert to DataFrame
        df = pd.DataFrame([request.dict()])
        
        # Predict
        probability = app.state.model.predict(df)[0]
        will_churn = probability > 0.5
        
        # Risk categorization
        if probability < 0.3:
            risk_category = "low"
        elif probability < 0.7:
            risk_category = "medium"
        else:
            risk_category = "high"
        
        # Confidence (distance from decision boundary)
        confidence = abs(probability - 0.5) * 2
        
        # Record metrics
        PREDICTION_COUNTER.labels(model_version=app.state.model_version).inc()
        PREDICTION_LATENCY.observe(time.time() - start_time)
        
        return PredictionResponse(
            customer_id=request.customer_id,
            churn_probability=float(probability),
            will_churn=will_churn,
            risk_category=risk_category,
            confidence=float(confidence),
            model_version=app.state.model_version,
            prediction_timestamp=pd.Timestamp.now().isoformat()
        )
    
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict/batch", response_model=List[PredictionResponse])
async def predict_batch(request: BatchPredictionRequest):
    """
    Predict churn for multiple customers.
    
    Returns:
        List of predictions
    """
    predictions = []
    
    for customer in request.customers:
        prediction = await predict(customer)
        predictions.append(prediction)
    
    return predictions

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    return generate_latest()

# Run with: uvicorn churn_mlops.api.main:app --host 0.0.0.0 --port 8000
```

### Step 2: API Dockerfile

```dockerfile
# docker/Dockerfile.api
FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements/base.txt requirements/api.txt ./
RUN pip install --no-cache-dir -r api.txt

# Copy application code
COPY src/ ./src/
COPY config/ ./config/

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')"

# Run application
CMD ["uvicorn", "src.churn_mlops.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Step 3: Kubernetes Deployment

```yaml
# k8s/api-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-api
  namespace: churn-mlops
  labels:
    app: churn-api
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: churn-api
  template:
    metadata:
      labels:
        app: churn-api
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: api
          image: churn-mlops-api:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8000
              name: http
          env:
            - name: MLFLOW_TRACKING_URI
              value: "http://mlflow:5000"
            - name: LOG_LEVEL
              value: "INFO"
          resources:
            requests:
              cpu: 200m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 20
            periodSeconds: 5
            timeoutSeconds: 3
            successThreshold: 1
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
---
apiVersion: v1
kind: Service
metadata:
  name: churn-api
  namespace: churn-mlops
spec:
  selector:
    app: churn-api
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000
  type: ClusterIP
---
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
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60
```

---

## Phase 4: Batch Scoring

### Step 4: Batch Scoring Script

```python
# src/churn_mlops/scoring/batch_score.py
import pandas as pd
import mlflow
from pathlib import Path
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class BatchScorer:
    """Batch scoring for churn prediction."""
    
    def __init__(self, model_uri: str = "models:/churn-model/Production"):
        self.model_uri = model_uri
        self.model = None
    
    def load_model(self):
        """Load model from MLflow."""
        logger.info(f"Loading model: {self.model_uri}")
        self.model = mlflow.pyfunc.load_model(self.model_uri)
        
        # Get model version
        client = mlflow.tracking.MlflowClient()
        self.model_version = client.get_model_version_by_alias(
            "churn-model", "Production"
        ).version
        
        logger.info(f"Loaded model version: {self.model_version}")
    
    def score(self, input_path: Path, output_path: Path):
        """
        Score batch of customers.
        
        Args:
            input_path: Path to input features
            output_path: Path to save predictions
        """
        logger.info(f"Scoring batch: {input_path}")
        
        # Load model if not loaded
        if self.model is None:
            self.load_model()
        
        # Load data
        df = pd.read_parquet(input_path)
        logger.info(f"Loaded {len(df)} customers")
        
        # Keep customer IDs
        customer_ids = df['customer_id']
        
        # Drop non-feature columns
        X = df.drop('customer_id', axis=1)
        
        # Predict
        probabilities = self.model.predict(X)
        
        # Create predictions DataFrame
        predictions = pd.DataFrame({
            'customer_id': customer_ids,
            'churn_probability': probabilities,
            'will_churn': probabilities > 0.5,
            'risk_category': pd.cut(
                probabilities,
                bins=[0, 0.3, 0.7, 1.0],
                labels=['low', 'medium', 'high']
            ),
            'model_version': self.model_version,
            'scored_at': datetime.now()
        })
        
        # Save predictions
        output_path.parent.mkdir(parents=True, exist_ok=True)
        predictions.to_parquet(output_path, index=False)
        logger.info(f"Saved predictions to {output_path}")
        
        # Log statistics
        churn_rate = (predictions['will_churn'].sum() / len(predictions)) * 100
        logger.info(f"Predicted churn rate: {churn_rate:.2f}%")
        logger.info(f"Risk distribution:\n{predictions['risk_category'].value_counts()}")
        
        return predictions

# Run batch scoring
if __name__ == "__main__":
    scorer = BatchScorer()
    
    predictions = scorer.score(
        input_path=Path("data/features/features_latest.parquet"),
        output_path=Path("data/predictions/predictions_latest.parquet")
    )
    
    print(f"✅ Scored {len(predictions)} customers")
```

### Step 5: Batch CronJob

```yaml
# k8s/cronjobs/batch-score.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: batch-score
  namespace: churn-mlops
spec:
  schedule: "0 1 * * *"  # Daily at 1 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: scorer
              image: churn-mlops:latest
              command:
                - python
                - -m
                - churn_mlops.scoring.batch_score
              env:
                - name: MLFLOW_TRACKING_URI
                  value: "http://mlflow:5000"
              volumeMounts:
                - name: data
                  mountPath: /app/data
              resources:
                requests:
                  cpu: 500m
                  memory: 2Gi
                limits:
                  cpu: 2000m
                  memory: 4Gi
          volumes:
            - name: data
              persistentVolumeClaim:
                claimName: ml-data-pvc
          restartPolicy: OnFailure
```

---

## Phase 5: CI/CD Pipeline

### Step 6: GitHub Actions Workflow

```yaml
# .github/workflows/ci-cd.yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Install dependencies
        run: |
          pip install -r requirements/dev.txt
      
      - name: Run linting
        run: |
          ruff check src/ tests/
      
      - name: Run tests
        run: |
          pytest tests/ --cov=src --cov-report=xml
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml

  build:
    name: Build Docker Images
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Log in to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}
      
      - name: Build and push ML image
        uses: docker/build-push-action@v4
        with:
          context: .
          file: docker/Dockerfile.ml
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
      
      - name: Build and push API image
        uses: docker/build-push-action@v4
        with:
          context: .
          file: docker/Dockerfile.api
          push: true
          tags: ${{ steps.meta.outputs.tags }}-api
          labels: ${{ steps.meta.outputs.labels }}

  deploy-staging:
    name: Deploy to Staging
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Update staging manifest
        run: |
          cd argocd/staging
          kustomize edit set image churn-api=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:develop-${{ github.sha }}
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git commit -am "Deploy to staging: ${{ github.sha }}"
          git push

  deploy-production:
    name: Deploy to Production
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://churn-api.example.com
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Update production manifest
        run: |
          cd argocd/production
          kustomize edit set image churn-api=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:main-${{ github.sha }}
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git commit -am "Deploy to production: ${{ github.sha }}"
          git push
```

---

## Phase 6: GitOps with ArgoCD

### Step 7: ArgoCD Application

```yaml
# argocd/production/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: churn-mlops-production
  namespace: argocd
spec:
  project: churn-mlops
  
  source:
    repoURL: https://github.com/your-org/churn-mlops-prod.git
    targetRevision: main
    path: argocd/production
  
  destination:
    server: https://kubernetes.default.svc
    namespace: churn-mlops
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  revisionHistoryLimit: 10
  
  # Health assessment
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

---

## Exercise: Complete Your Deployment

### Task 1: Test API Locally

```bash
# Build and run API
docker build -t churn-api:local -f docker/Dockerfile.api .
docker run -p 8000:8000 churn-api:local

# Test prediction
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "TEST-001",
    "age": 35,
    "gender": "Female",
    "location": "New York",
    "contract_type": "Month-to-month",
    "payment_method": "Credit card",
    "avg_data_usage": 15.5,
    "avg_call_minutes": 450.0,
    "usage_days": 28,
    "avg_monthly_charges": 75.50,
    "late_payments": 0,
    "tenure": 24
  }'
```

### Task 2: Deploy to Kubernetes

```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/cronjobs/batch-score.yaml

# Verify deployment
kubectl get pods -n churn-mlops
kubectl logs -n churn-mlops -l app=churn-api

# Test API
kubectl port-forward -n churn-mlops svc/churn-api 8000:80
curl http://localhost:8000/health
```

### Task 3: Set Up ArgoCD

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create application
kubectl apply -f argocd/production/application.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Login with: admin / <get password>
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## Key Takeaways

✅ Deployed FastAPI real-time API with monitoring  
✅ Implemented batch scoring pipeline  
✅ Configured Kubernetes with HPA autoscaling  
✅ Set up CI/CD with GitHub Actions  
✅ Implemented GitOps with ArgoCD

---

## Next Steps

Continue to **[Section 35: MLOps Capstone - Part 3: Monitoring & Operations](./section-35-capstone-part3.md)**

---

**Progress**: 32/34 sections complete (94%) → **33/34 (97%)**
