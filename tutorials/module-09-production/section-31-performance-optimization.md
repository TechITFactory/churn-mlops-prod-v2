# Section 31: Performance Optimization

**Duration**: 3 hours  
**Level**: Advanced  
**Prerequisites**: Section 30 (Security)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Optimize API performance and reduce latency
- ✅ Implement caching strategies for predictions
- ✅ Optimize model inference speed
- ✅ Configure resource limits and autoscaling
- ✅ Implement connection pooling and async processing
- ✅ Monitor and profile application performance
- ✅ Reduce costs through resource optimization

---

## 📚 Table of Contents

1. [Performance Fundamentals](#performance-fundamentals)
2. [API Optimization](#api-optimization)
3. [Model Inference Optimization](#model-inference-optimization)
4. [Caching Strategies](#caching-strategies)
5. [Database Optimization](#database-optimization)
6. [Resource Optimization](#resource-optimization)
7. [Load Testing](#load-testing)
8. [Profiling and Debugging](#profiling-and-debugging)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## Performance Fundamentals

### Performance Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| **Latency (P50)** | Median response time | < 100ms |
| **Latency (P95)** | 95th percentile | < 500ms |
| **Latency (P99)** | 99th percentile | < 1000ms |
| **Throughput** | Requests per second | > 100 RPS |
| **Error Rate** | Failed requests | < 0.1% |
| **CPU Usage** | CPU utilization | 50-70% |
| **Memory Usage** | RAM utilization | < 80% |
| **Cost per Request** | $ per 1M requests | < $1 |

### Performance Bottlenecks

```
Common Bottlenecks:

1. Model Inference (40-60%)
   - Slow model loading
   - Inefficient preprocessing
   - Large model size

2. Database Queries (20-30%)
   - N+1 queries
   - Missing indexes
   - No connection pooling

3. Network I/O (10-20%)
   - External API calls
   - No request batching
   - Slow DNS resolution

4. Application Logic (5-10%)
   - Synchronous processing
   - Inefficient algorithms
   - No caching

5. Serialization (5-10%)
   - JSON parsing
   - Data validation
   - Response formatting
```

---

## API Optimization

### Async FastAPI

```python
# src/churn_mlops/api/app_optimized.py
from fastapi import FastAPI
from contextlib import asynccontextmanager
import asyncio

# Lifespan for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle."""
    # Startup
    print("Loading model...")
    app.state.model = load_model()
    
    print("Creating connection pool...")
    app.state.db_pool = await create_db_pool()
    
    print("Warming up cache...")
    await warmup_cache()
    
    yield
    
    # Shutdown
    print("Closing connections...")
    await app.state.db_pool.close()

app = FastAPI(lifespan=lifespan)

# Async endpoint
@app.post("/predict")
async def predict(request: PredictionRequest):
    """Async prediction endpoint."""
    # Run CPU-intensive task in thread pool
    result = await asyncio.get_event_loop().run_in_executor(
        None,
        app.state.model.predict,
        request.features
    )
    
    return result

# Batch endpoint
@app.post("/predict/batch")
async def predict_batch(requests: List[PredictionRequest]):
    """Batch predictions for efficiency."""
    # Process in parallel
    tasks = [
        asyncio.get_event_loop().run_in_executor(
            None,
            app.state.model.predict,
            req.features
        )
        for req in requests
    ]
    
    results = await asyncio.gather(*tasks)
    
    return {"predictions": results}
```

### Response Compression

```python
# src/churn_mlops/api/middleware.py
from fastapi import FastAPI
from starlette.middleware.gzip import GZipMiddleware

app = FastAPI()

# Enable GZIP compression
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Reduces response size by 60-80% for JSON
```

### Connection Pooling

```python
# src/churn_mlops/database/pool.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from contextlib import asynccontextmanager

class DatabasePool:
    """Async database connection pool."""
    
    def __init__(self, database_url: str):
        self.engine = create_async_engine(
            database_url,
            pool_size=20,          # Max connections
            max_overflow=10,       # Extra connections when pool full
            pool_pre_ping=True,    # Verify connection before use
            pool_recycle=3600,     # Recycle connections after 1 hour
            echo=False
        )
        
        self.SessionLocal = sessionmaker(
            self.engine,
            class_=AsyncSession,
            expire_on_commit=False
        )
    
    @asynccontextmanager
    async def get_session(self):
        """Get database session from pool."""
        async with self.SessionLocal() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise
    
    async def close(self):
        """Close all connections."""
        await self.engine.dispose()

# Usage
db_pool = DatabasePool("postgresql+asyncpg://user:pass@host/db")

@app.get("/customer/{customer_id}")
async def get_customer(customer_id: int):
    async with db_pool.get_session() as session:
        result = await session.execute(
            select(Customer).where(Customer.id == customer_id)
        )
        customer = result.scalar_one_or_none()
        return customer
```

### Request Batching

```python
# src/churn_mlops/api/batching.py
import asyncio
from collections import defaultdict
from typing import List, Any
import time

class RequestBatcher:
    """Batch requests for efficient processing."""
    
    def __init__(self, max_batch_size: int = 32, max_wait_ms: int = 10):
        self.max_batch_size = max_batch_size
        self.max_wait_ms = max_wait_ms / 1000
        self.pending_requests = []
        self.lock = asyncio.Lock()
    
    async def add_request(self, features: dict) -> Any:
        """Add request to batch."""
        future = asyncio.Future()
        
        async with self.lock:
            self.pending_requests.append((features, future))
            
            # Process if batch full
            if len(self.pending_requests) >= self.max_batch_size:
                await self._process_batch()
        
        # Wait for result
        return await future
    
    async def _process_batch(self):
        """Process accumulated requests."""
        if not self.pending_requests:
            return
        
        # Extract features and futures
        batch_features = [req[0] for req in self.pending_requests]
        batch_futures = [req[1] for req in self.pending_requests]
        self.pending_requests = []
        
        # Batch prediction
        results = model.predict_batch(batch_features)
        
        # Set results
        for future, result in zip(batch_futures, results):
            future.set_result(result)
    
    async def start_timer(self):
        """Process batch after timeout."""
        while True:
            await asyncio.sleep(self.max_wait_ms)
            
            async with self.lock:
                if self.pending_requests:
                    await self._process_batch()

# Usage
batcher = RequestBatcher(max_batch_size=32, max_wait_ms=10)

@app.on_event("startup")
async def start_batcher():
    asyncio.create_task(batcher.start_timer())

@app.post("/predict")
async def predict(request: PredictionRequest):
    result = await batcher.add_request(request.features)
    return result
```

---

## Model Inference Optimization

### Model Quantization

```python
# src/churn_mlops/models/quantization.py
from sklearn.ensemble import HistGradientBoostingClassifier
import joblib
import numpy as np

def quantize_model(model_path: str, output_path: str):
    """Quantize model to reduce size and improve speed."""
    model = joblib.load(model_path)
    
    # Convert float64 to float32
    for estimator in model.estimators_:
        for attr in ['value', 'threshold']:
            if hasattr(estimator, attr):
                values = getattr(estimator, attr)
                if values.dtype == np.float64:
                    setattr(estimator, attr, values.astype(np.float32))
    
    # Save quantized model
    joblib.dump(model, output_path, compress=3)
    
    # Check size reduction
    original_size = os.path.getsize(model_path) / 1024 / 1024
    quantized_size = os.path.getsize(output_path) / 1024 / 1024
    
    print(f"Original: {original_size:.2f} MB")
    print(f"Quantized: {quantized_size:.2f} MB")
    print(f"Reduction: {(1 - quantized_size/original_size)*100:.1f}%")

# Usage
quantize_model("model.pkl", "model_quantized.pkl")
# Original: 45.3 MB
# Quantized: 23.1 MB
# Reduction: 49.0%
```

### Feature Preprocessing Optimization

```python
# src/churn_mlops/features/preprocessor_optimized.py
import numpy as np
from typing import Dict
import polars as pl  # Faster than pandas

class OptimizedPreprocessor:
    """Optimized feature preprocessing."""
    
    def __init__(self):
        # Precompute transformations
        self.categorical_encodings = self._load_encodings()
        self.numerical_stats = self._load_stats()
    
    def transform(self, features: Dict[str, any]) -> np.ndarray:
        """Transform features efficiently."""
        # Use NumPy operations (faster than Python loops)
        result = np.zeros(len(self.feature_names), dtype=np.float32)
        
        for i, name in enumerate(self.feature_names):
            if name in self.categorical_encodings:
                # Categorical encoding (O(1) lookup)
                value = features.get(name)
                result[i] = self.categorical_encodings[name].get(value, 0)
            else:
                # Numerical scaling
                value = features.get(name, 0)
                mean = self.numerical_stats[name]['mean']
                std = self.numerical_stats[name]['std']
                result[i] = (value - mean) / std
        
        return result
    
    def transform_batch(self, features_list: List[Dict]) -> np.ndarray:
        """Batch transformation (vectorized)."""
        # Convert to DataFrame
        df = pl.DataFrame(features_list)
        
        # Vectorized operations
        for col in df.columns:
            if col in self.categorical_encodings:
                df = df.with_columns(
                    pl.col(col).map_dict(self.categorical_encodings[col])
                )
            else:
                mean = self.numerical_stats[col]['mean']
                std = self.numerical_stats[col]['std']
                df = df.with_columns(
                    ((pl.col(col) - mean) / std).alias(col)
                )
        
        return df.to_numpy(dtype=np.float32)
```

### Model Caching

```python
# src/churn_mlops/models/cached_model.py
from functools import lru_cache
import hashlib
import json

class CachedModel:
    """Model with prediction caching."""
    
    def __init__(self, model):
        self.model = model
        self.cache = {}
        self.cache_hits = 0
        self.cache_misses = 0
    
    def _hash_features(self, features: dict) -> str:
        """Create hash of features for cache key."""
        # Sort keys for consistent hashing
        sorted_features = json.dumps(features, sort_keys=True)
        return hashlib.md5(sorted_features.encode()).hexdigest()
    
    def predict(self, features: dict):
        """Predict with caching."""
        cache_key = self._hash_features(features)
        
        # Check cache
        if cache_key in self.cache:
            self.cache_hits += 1
            return self.cache[cache_key]
        
        # Cache miss - compute
        self.cache_misses += 1
        result = self.model.predict(features)
        
        # Store in cache (limit size)
        if len(self.cache) < 10000:
            self.cache[cache_key] = result
        
        return result
    
    def get_cache_stats(self):
        """Get cache performance metrics."""
        total = self.cache_hits + self.cache_misses
        hit_rate = self.cache_hits / total if total > 0 else 0
        
        return {
            "cache_hits": self.cache_hits,
            "cache_misses": self.cache_misses,
            "hit_rate": hit_rate,
            "cache_size": len(self.cache)
        }
```

---

## Caching Strategies

### Redis Caching

```python
# src/churn_mlops/cache/redis_cache.py
import redis.asyncio as redis
import json
from typing import Optional
import pickle

class RedisCache:
    """Redis-based distributed cache."""
    
    def __init__(self, redis_url: str):
        self.redis = redis.from_url(redis_url, decode_responses=False)
    
    async def get(self, key: str) -> Optional[dict]:
        """Get value from cache."""
        value = await self.redis.get(key)
        if value:
            return pickle.loads(value)
        return None
    
    async def set(
        self,
        key: str,
        value: dict,
        ttl: int = 3600  # 1 hour
    ):
        """Set value in cache with TTL."""
        await self.redis.setex(
            key,
            ttl,
            pickle.dumps(value)
        )
    
    async def delete(self, key: str):
        """Delete from cache."""
        await self.redis.delete(key)
    
    async def clear(self):
        """Clear all cache."""
        await self.redis.flushdb()

# Usage
cache = RedisCache("redis://localhost:6379")

@app.post("/predict")
async def predict(request: PredictionRequest):
    # Generate cache key
    cache_key = f"prediction:{hash(json.dumps(request.features, sort_keys=True))}"
    
    # Check cache
    cached_result = await cache.get(cache_key)
    if cached_result:
        return cached_result
    
    # Compute prediction
    result = model.predict(request.features)
    
    # Store in cache (1 hour TTL)
    await cache.set(cache_key, result, ttl=3600)
    
    return result
```

### Multi-Level Caching

```python
# src/churn_mlops/cache/multi_level_cache.py
from typing import Optional
from functools import lru_cache

class MultiLevelCache:
    """L1 (memory) + L2 (Redis) cache."""
    
    def __init__(self, redis_url: str, l1_size: int = 1000):
        self.l2 = RedisCache(redis_url)
        self.l1_size = l1_size
        self.l1_cache = {}
        self.l1_access_count = {}
    
    async def get(self, key: str) -> Optional[dict]:
        """Get from L1, then L2."""
        # L1 lookup (fast)
        if key in self.l1_cache:
            self.l1_access_count[key] = self.l1_access_count.get(key, 0) + 1
            return self.l1_cache[key]
        
        # L2 lookup (slower)
        value = await self.l2.get(key)
        if value:
            # Promote to L1
            self._add_to_l1(key, value)
        
        return value
    
    async def set(self, key: str, value: dict, ttl: int = 3600):
        """Set in both L1 and L2."""
        # L1
        self._add_to_l1(key, value)
        
        # L2
        await self.l2.set(key, value, ttl)
    
    def _add_to_l1(self, key: str, value: dict):
        """Add to L1 with LRU eviction."""
        if len(self.l1_cache) >= self.l1_size:
            # Evict least accessed
            lru_key = min(self.l1_access_count, key=self.l1_access_count.get)
            del self.l1_cache[lru_key]
            del self.l1_access_count[lru_key]
        
        self.l1_cache[key] = value
        self.l1_access_count[key] = 0
```

---

## Database Optimization

### Query Optimization

```python
# src/churn_mlops/database/optimized_queries.py
from sqlalchemy import select
from sqlalchemy.orm import selectinload

# ❌ BAD: N+1 queries
async def get_customers_bad():
    customers = await session.execute(select(Customer))
    
    for customer in customers:
        # Separate query for each customer!
        predictions = await session.execute(
            select(Prediction).where(Prediction.customer_id == customer.id)
        )
        customer.predictions = predictions.all()

# ✅ GOOD: Single query with join
async def get_customers_good():
    result = await session.execute(
        select(Customer)
        .options(selectinload(Customer.predictions))
    )
    customers = result.scalars().all()
    # All predictions loaded in single query

# ✅ GOOD: Use indexes
# CREATE INDEX idx_prediction_customer_id ON predictions(customer_id);
# CREATE INDEX idx_prediction_created_at ON predictions(created_at);

# Query with index
async def get_recent_predictions(customer_id: int):
    result = await session.execute(
        select(Prediction)
        .where(Prediction.customer_id == customer_id)
        .order_by(Prediction.created_at.desc())
        .limit(10)
    )
    return result.scalars().all()
```

### Database Connection Configuration

```yaml
# k8s/database-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: churn-mlops
data:
  postgresql.conf: |
    # Memory
    shared_buffers = 256MB
    effective_cache_size = 1GB
    work_mem = 4MB
    maintenance_work_mem = 64MB
    
    # Connections
    max_connections = 200
    
    # WAL
    wal_buffers = 16MB
    checkpoint_completion_target = 0.9
    
    # Query Planning
    random_page_cost = 1.1  # SSD
    effective_io_concurrency = 200
    
    # Logging (for slow queries)
    log_min_duration_statement = 1000  # Log queries > 1s
    log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d '
```

---

## Resource Optimization

### Horizontal Pod Autoscaler

```yaml
# k8s/hpa.yaml
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
    # CPU-based scaling
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    
    # Memory-based scaling
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    
    # Custom metric (requests per second)
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "100"
  
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
        - type: Pods
          value: 2
          periodSeconds: 60
      selectPolicy: Max
    
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
```

### Vertical Pod Autoscaler

```yaml
# k8s/vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: churn-api-vpa
  namespace: churn-mlops
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: churn-api
  
  updatePolicy:
    updateMode: "Auto"  # Automatically apply recommendations
  
  resourcePolicy:
    containerPolicies:
      - containerName: api
        minAllowed:
          cpu: 100m
          memory: 128Mi
        maxAllowed:
          cpu: 2000m
          memory: 4Gi
        controlledResources:
          - cpu
          - memory
```

### Resource Limits

```yaml
# k8s/api-deployment-optimized.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: churn-api
  namespace: churn-mlops
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: api
          image: churn-api:v1.2.3
          
          # Optimized resource limits
          resources:
            requests:
              cpu: 500m      # 0.5 CPU cores
              memory: 512Mi
            limits:
              cpu: 2000m     # 2 CPU cores (burst)
              memory: 2Gi
          
          # Quality of Service: Burstable
          # (requests < limits allows bursting)
```

---

## Load Testing

### Locust Load Test

```python
# tests/load/locustfile.py
from locust import HttpUser, task, between
import random

class ChurnAPIUser(HttpUser):
    """Load test for Churn API."""
    
    wait_time = between(1, 3)  # Wait 1-3 seconds between requests
    
    def on_start(self):
        """Login/setup before tests."""
        # Get auth token
        response = self.client.post("/auth/login", json={
            "username": "test_user",
            "password": "test_pass"
        })
        self.token = response.json()["access_token"]
    
    @task(3)
    def predict(self):
        """Make prediction (70% of requests)."""
        features = {
            "age": random.randint(18, 80),
            "tenure": random.randint(1, 72),
            "monthly_charges": random.uniform(20, 150)
        }
        
        self.client.post(
            "/predict",
            json={"features": features},
            headers={"Authorization": f"Bearer {self.token}"}
        )
    
    @task(1)
    def health_check(self):
        """Health check (30% of requests)."""
        self.client.get("/health")
    
    @task(1)
    def batch_predict(self):
        """Batch prediction."""
        batch = [
            {
                "features": {
                    "age": random.randint(18, 80),
                    "tenure": random.randint(1, 72),
                    "monthly_charges": random.uniform(20, 150)
                }
            }
            for _ in range(10)
        ]
        
        self.client.post(
            "/predict/batch",
            json=batch,
            headers={"Authorization": f"Bearer {self.token}"}
        )

# Run load test
# locust -f tests/load/locustfile.py --host=http://api.example.com
# Open http://localhost:8089
# Configure: 100 users, 10 users/second spawn rate
```

### K6 Load Test

```javascript
// tests/load/k6-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% requests < 500ms
    errors: ['rate<0.01'],             // Error rate < 1%
  },
};

export default function () {
  const payload = JSON.stringify({
    features: {
      age: Math.floor(Math.random() * 60) + 18,
      tenure: Math.floor(Math.random() * 72),
      monthly_charges: Math.random() * 130 + 20,
    },
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': 'test-key',
    },
  };

  const res = http.post('http://api.example.com/predict', payload, params);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  }) || errorRate.add(1);

  sleep(1);
}

// Run: k6 run tests/load/k6-test.js
```

---

## Profiling and Debugging

### Python Profiling

```python
# src/churn_mlops/profiling/profiler.py
import cProfile
import pstats
import io
from functools import wraps
import time

def profile_function(func):
    """Decorator to profile function."""
    @wraps(func)
    def wrapper(*args, **kwargs):
        profiler = cProfile.Profile()
        profiler.enable()
        
        result = func(*args, **kwargs)
        
        profiler.disable()
        
        # Print stats
        s = io.StringIO()
        ps = pstats.Stats(profiler, stream=s).sort_stats('cumulative')
        ps.print_stats(10)  # Top 10
        print(s.getvalue())
        
        return result
    
    return wrapper

# Usage
@profile_function
def process_data(data):
    # ... processing
    pass

# Or with context manager
from contextlib import contextmanager

@contextmanager
def profile_context(name="Profile"):
    profiler = cProfile.Profile()
    profiler.enable()
    yield
    profiler.disable()
    
    s = io.StringIO()
    ps = pstats.Stats(profiler, stream=s).sort_stats('cumulative')
    ps.print_stats()
    print(f"\n{name}:\n{s.getvalue()}")

# Usage
with profile_context("Model Inference"):
    result = model.predict(features)
```

### Memory Profiling

```python
# src/churn_mlops/profiling/memory_profiler.py
from memory_profiler import profile

@profile
def load_large_dataset():
    """Profile memory usage."""
    data = pd.read_csv("large_file.csv")
    processed = data.groupby("customer_id").agg({"value": "sum"})
    return processed

# Run with: python -m memory_profiler script.py
# Output:
# Line    Mem usage    Increment   Line Contents
# ====    =========    =========   ==============
#   1    45.2 MiB     45.2 MiB    data = pd.read_csv(...)
#   2   123.5 MiB     78.3 MiB    processed = data.groupby(...)
```

### API Profiling Middleware

```python
# src/churn_mlops/api/profiling_middleware.py
from fastapi import Request
import time

@app.middleware("http")
async def profiling_middleware(request: Request, call_next):
    """Profile request processing."""
    timings = {}
    
    # Start time
    start = time.perf_counter()
    
    # Process request
    response = await call_next(request)
    
    # End time
    total_time = time.perf_counter() - start
    
    # Add timing headers
    response.headers["X-Process-Time"] = f"{total_time:.3f}"
    
    # Log slow requests
    if total_time > 1.0:
        logger.warning(
            f"Slow request: {request.url.path} took {total_time:.3f}s"
        )
    
    return response
```

---

## Hands-On Exercise

### Exercise 1: Implement Response Caching

```python
# Add Redis caching to API
from churn_mlops.cache.redis_cache import RedisCache

cache = RedisCache("redis://localhost:6379")

@app.post("/predict")
async def predict_cached(request: PredictionRequest):
    # Generate cache key
    cache_key = f"pred:{hash(json.dumps(request.features, sort_keys=True))}"
    
    # Check cache
    result = await cache.get(cache_key)
    if result:
        return {"cached": True, **result}
    
    # Compute
    result = model.predict(request.features)
    
    # Cache for 1 hour
    await cache.set(cache_key, result, ttl=3600)
    
    return {"cached": False, **result}
```

### Exercise 2: Configure HPA

```bash
# Apply HPA
kubectl apply -f k8s/hpa.yaml

# Generate load
kubectl run load-generator --rm -it --image=busybox -- /bin/sh
while true; do wget -q -O- http://churn-api:8000/health; done

# Watch scaling
kubectl get hpa churn-api-hpa --watch
```

### Exercise 3: Run Load Test

```bash
# Install Locust
pip install locust

# Run load test
locust -f tests/load/locustfile.py --host=http://localhost:8000

# Open UI: http://localhost:8089
# Configure:
# - Users: 100
# - Spawn rate: 10/second
# - Duration: 5 minutes

# Observe:
# - RPS (requests per second)
# - Response times (P50, P95, P99)
# - Error rate
```

### Exercise 4: Profile API Endpoint

```python
# Add profiling to endpoint
from churn_mlops.profiling.profiler import profile_context

@app.post("/predict")
async def predict_profiled(request: PredictionRequest):
    with profile_context("Prediction"):
        result = model.predict(request.features)
    
    return result

# Make request and check logs for profile output
```

### Exercise 5: Optimize Database Queries

```python
# Before: N+1 queries
customers = await session.execute(select(Customer).limit(10))
for customer in customers:
    predictions = await session.execute(
        select(Prediction).where(Prediction.customer_id == customer.id)
    )

# After: Single query with join
customers = await session.execute(
    select(Customer)
    .options(selectinload(Customer.predictions))
    .limit(10)
)

# Measure improvement
# Before: 11 queries, 150ms
# After: 1 query, 15ms (10x faster)
```

---

## Assessment Questions

### Question 1: Multiple Choice
What's the most effective way to reduce API latency?

A) Increase CPU limits  
B) **Implement caching** ✅  
C) Add more replicas  
D) Use faster network  

---

### Question 2: True/False
**Statement**: Setting CPU limits equal to requests (e.g., 1 CPU) prevents CPU throttling.

**Answer**: True ✅  
**Explanation**: When `requests == limits`, the pod gets QoS class "Guaranteed" and won't be throttled. But it also can't burst above the limit.

---

### Question 3: Short Answer
What's the difference between HPA and VPA?

**Answer**:
- **HPA (Horizontal Pod Autoscaler)**: Scales number of **replicas** based on CPU/memory/custom metrics
  - Example: 2 pods → 6 pods when CPU > 70%
- **VPA (Vertical Pod Autoscaler)**: Adjusts **resource requests/limits** per pod
  - Example: 512Mi → 1Gi memory when pod uses too much

Use HPA for variable load, VPA for resource optimization.

---

### Question 4: Code Analysis
What performance issues exist?

```python
@app.post("/predict")
def predict(request: PredictionRequest):
    # Load model for each request
    model = joblib.load("model.pkl")
    
    # Synchronous database call
    customer = db.query(Customer).filter_by(id=request.customer_id).first()
    
    # Make prediction
    result = model.predict(request.features)
    
    return result
```

**Answer**:

**Performance Issues**:
1. **Loading model on every request** (100+ ms overhead)
2. **Synchronous database call** (blocks other requests)
3. **No caching** (repeated predictions for same input)
4. **Synchronous endpoint** (can't handle concurrent requests efficiently)

**Optimized Version**:
```python
# Load model once at startup
model = None

@app.on_event("startup")
async def load_model():
    global model
    model = joblib.load("model.pkl")

# Async endpoint with caching
@app.post("/predict")
async def predict_optimized(request: PredictionRequest):
    # Check cache
    cache_key = hash_features(request.features)
    if cache_key in cache:
        return cache[cache_key]
    
    # Async database call
    async with db_pool.get_session() as session:
        result = await session.execute(
            select(Customer).where(Customer.id == request.customer_id)
        )
        customer = result.scalar_one_or_none()
    
    # Prediction in thread pool
    prediction = await asyncio.get_event_loop().run_in_executor(
        None, model.predict, request.features
    )
    
    # Cache result
    cache[cache_key] = prediction
    
    return prediction
```

---

### Question 5: Design Challenge
Design a performance optimization strategy for an ML API handling 1000 RPS.

**Answer**:

```yaml
Performance Optimization Strategy:

1. Caching (Biggest impact: 60-80% latency reduction)
   L1: In-memory LRU cache (10K entries)
     - Hit rate target: 30-40%
     - Latency: <1ms
   
   L2: Redis distributed cache
     - TTL: 1 hour
     - Hit rate target: 20-30%
     - Latency: 2-5ms
   
   Total cache hit rate: 50-70%
   Cost savings: 50-70% less compute

2. Request Batching
   - Batch size: 32 requests
   - Max wait: 10ms
   - Benefit: 3-5x throughput improvement

3. Async Processing
   - FastAPI with uvicorn
   - Workers: 4 per pod (1 per CPU core)
   - Connection pool: 20 connections
   - Benefit: Handle 10x concurrent requests

4. Model Optimization
   - Quantization: Float64 → Float32 (50% size reduction)
   - Feature preprocessing: NumPy vectorization
   - Benefit: 2x inference speed

5. Horizontal Scaling
   - HPA: 5-20 replicas based on CPU/RPS
   - Target: 70% CPU utilization
   - Anti-flapping: 5-minute cooldown
   - Benefit: Handle traffic spikes

6. Resource Allocation
   Per pod:
   - CPU: 1 core request, 2 cores limit
   - Memory: 1Gi request, 2Gi limit
   - QoS: Burstable (allows bursting)

7. Database Optimization
   - Connection pooling: 20 connections
   - Read replicas: 3 replicas
   - Query caching: Frequent queries cached
   - Indexes: All foreign keys and filters
   - Benefit: 5-10x faster queries

8. Infrastructure
   - CDN: Cache /health, /docs endpoints
   - Load balancer: Round-robin with health checks
   - Network policy: Internal cluster communication
   - Benefit: Reduce latency, improve reliability

Expected Performance:
- Latency P50: 20ms (with 50% cache hit rate)
- Latency P95: 100ms
- Latency P99: 300ms
- Throughput: 1000 RPS per pod
- Error rate: <0.1%
- Cost: $100/month for 5 pods

Monitoring:
- Grafana dashboard: Latency, throughput, cache hit rate
- Alerts: P95 > 500ms, error rate > 1%, cache hit rate < 30%
- Profiling: Weekly performance reviews
```

---

## Key Takeaways

### ✅ What You Learned

1. **API Optimization**
   - Async FastAPI
   - Response compression
   - Connection pooling
   - Request batching

2. **Model Optimization**
   - Quantization
   - Feature preprocessing
   - Prediction caching

3. **Caching**
   - Redis distributed cache
   - Multi-level caching
   - Cache invalidation

4. **Database**
   - Query optimization
   - Connection pooling
   - Indexing strategies

5. **Resource Management**
   - HPA/VPA autoscaling
   - Resource limits
   - QoS classes

6. **Load Testing**
   - Locust/K6 tools
   - Performance metrics
   - Capacity planning

7. **Profiling**
   - CPU profiling
   - Memory profiling
   - Slow query detection

---

## Next Steps

Continue to **[Section 32: Documentation and Knowledge Sharing](./section-32-documentation.md)**

---

**Progress**: 29/34 sections complete (85%) → **30/34 (88%)**
