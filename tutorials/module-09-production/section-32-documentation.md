# Section 32: Documentation and Runbook Standards

**Duration**: 2 hours  
**Level**: Intermediate  
**Prerequisites**: All previous modules

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Create comprehensive technical documentation
- ✅ Write effective API documentation
- ✅ Build operational runbooks
- ✅ Document ML models and experiments
- ✅ Maintain architecture decision records (ADRs)
- ✅ Create onboarding guides for new team members

---

## Key Documentation Types

### 1. API Documentation (OpenAPI/Swagger)

```python
# src/churn_mlops/api/app.py
from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI(
    title="Churn Prediction API",
    description="ML service for customer churn prediction",
    version="1.2.3",
    docs_url="/docs",
    redoc_url="/redoc"
)

class PredictionRequest(BaseModel):
    """Request model for predictions."""
    
    features: dict = Field(
        ...,
        description="Customer features for prediction",
        example={
            "age": 35,
            "tenure": 12,
            "monthly_charges": 65.50
        }
    )

class PredictionResponse(BaseModel):
    """Response model for predictions."""
    
    prediction: str = Field(..., description="Predicted class: churn or no_churn")
    confidence: float = Field(..., ge=0, le=1, description="Model confidence score")
    model_version: str = Field(..., description="Model version used")

@app.post(
    "/predict",
    response_model=PredictionResponse,
    summary="Make churn prediction",
    description="Predict customer churn based on features",
    tags=["Predictions"]
)
async def predict(request: PredictionRequest):
    """
    Make a churn prediction for a customer.
    
    **Parameters:**
    - **features**: Dictionary of customer features
    
    **Returns:**
    - **prediction**: "churn" or "no_churn"
    - **confidence**: Model confidence (0-1)
    - **model_version**: Version of model used
    
    **Example:**
    ```json
    {
      "features": {
        "age": 35,
        "tenure": 12,
        "monthly_charges": 65.50
      }
    }
    ```
    """
    result = model.predict(request.features)
    return result
```

### 2. Operational Runbooks

```markdown
# Runbook: High API Latency

## Severity: P2 (Warning)

## Symptoms
- P95 latency > 500ms for 10+ minutes
- User complaints about slow responses
- Grafana alert firing

## Impact
- **Users**: Degraded experience
- **Business**: Potential revenue loss
- **SLO**: Approaching 99.9% availability threshold

## Investigation Steps

### 1. Check Dashboard
```bash
# Open Grafana
https://grafana.example.com/d/api-overview

# Check metrics:
- Request rate (normal vs spike?)
- Error rate (errors causing retries?)
- Resource usage (CPU/memory at limits?)
```

### 2. Check Logs
```bash
# Recent errors
kubectl logs -n churn-mlops deployment/churn-api --tail=100 | grep ERROR

# Slow requests
kubectl logs -n churn-mlops deployment/churn-api --tail=100 | grep "Process-Time: [0-9]\{4,\}"
```

### 3. Check Pod Status
```bash
# Pod health
kubectl get pods -n churn-mlops -l app=churn-api

# Resource usage
kubectl top pods -n churn-mlops -l app=churn-api

# Restart count (crashing pods?)
kubectl get pods -n churn-mlops -l app=churn-api -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}'
```

## Common Causes & Solutions

### Cause 1: Database Slowdown
**Symptoms**: DB queries taking >100ms

**Solution**:
```bash
# Check DB connections
kubectl exec -n churn-mlops deployment/churn-api -- \
  psql -h postgres -U churn -c "SELECT count(*) FROM pg_stat_activity;"

# Kill long-running queries
kubectl exec -n churn-mlops statefulset/postgres -- \
  psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'active' AND query_start < now() - interval '5 minutes';"
```

### Cause 2: Cache Miss Storm
**Symptoms**: Redis cache hit rate <20%

**Solution**:
```bash
# Check cache stats
kubectl exec -n churn-mlops deployment/redis -- redis-cli INFO stats

# Warm up cache
kubectl exec -n churn-mlops deployment/churn-api -- \
  python -m churn_mlops.cache.warmup
```

### Cause 3: Model Loading
**Symptoms**: High CPU on model load

**Solution**:
```bash
# Restart pods to reload model
kubectl rollout restart deployment churn-api -n churn-mlops

# Scale up for more capacity
kubectl scale deployment churn-api -n churn-mlops --replicas=6
```

## Escalation
If latency >1s for >30 minutes:
1. Page on-call engineer
2. Notify #incidents Slack channel
3. Consider emergency rollback

## Prevention
- [ ] Review query performance weekly
- [ ] Monitor cache hit rates
- [ ] Set up preemptive scaling rules
- [ ] Implement circuit breakers

## Related Documents
- [API Performance Dashboard](https://grafana.example.com/d/api-perf)
- [Database Optimization Guide](./database-optimization.md)
- [Caching Strategy](./caching-strategy.md)

---
**Last Updated**: 2023-12-15  
**Owner**: SRE Team  
**Reviewers**: ML Team, Backend Team
```

### 3. Architecture Decision Records (ADRs)

```markdown
# ADR-001: Use FastAPI for ML Serving API

## Status
Accepted

## Context
We need to build a REST API for serving ML predictions. Options considered:
- Flask
- FastAPI
- Django REST Framework

## Decision
Use FastAPI for ML serving API.

## Rationale

### Pros
1. **Performance**: 
   - Async/await support (handle 10x concurrent requests)
   - Fast JSON serialization with Pydantic
   - Comparable to Node.js/Go performance

2. **Developer Experience**:
   - Automatic OpenAPI/Swagger documentation
   - Type hints with runtime validation
   - Less boilerplate than Flask

3. **Modern Features**:
   - Native async/await
   - Dependency injection
   - WebSocket support

### Cons
1. Newer ecosystem (fewer libraries)
2. Team learning curve (async programming)

### Comparison

| Feature | FastAPI | Flask | Django RF |
|---------|---------|-------|-----------|
| Performance | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| Documentation | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| Async Support | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| Ecosystem | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

## Consequences

### Positive
- 3x better performance in load tests
- Automatic API documentation saves 20 hours/month
- Type safety catches bugs before production

### Negative
- Team needs async/await training (2-week ramp-up)
- Some libraries lack async versions

## Alternatives Considered

### Flask
- Pros: Mature, large ecosystem, team familiar
- Cons: Synchronous (blocks on I/O), manual documentation
- **Rejected**: Performance limitations for high-traffic API

### Django REST Framework
- Pros: Full-featured, excellent for CRUD APIs
- Cons: Heavyweight, slower than FastAPI/Flask
- **Rejected**: Overkill for ML serving, slower performance

## References
- [FastAPI Benchmarks](https://www.techempower.com/benchmarks/)
- [Load Test Results](./load-test-results.md)
- [Team Training Plan](./fastapi-training.md)

---
**Date**: 2023-10-15  
**Deciders**: Tech Lead, ML Engineer, SRE  
**Consulted**: Backend Team, DevOps Team
```

### 4. Model Documentation

```yaml
# models/churn-model-v3/model-card.yaml
model_card:
  name: Churn Prediction Model
  version: 3.0.0
  date: 2023-12-15
  
  description: |
    Gradient boosting classifier for predicting customer churn.
    Trained on 2 years of customer data (2021-2023).
  
  intended_use:
    primary_uses:
      - Identify at-risk customers for retention campaigns
      - Score customers for prioritization
    
    primary_users:
      - Customer success team
      - Marketing team
      - Data analysts
    
    out_of_scope:
      - Real-time credit decisions
      - Automated customer termination
  
  factors:
    relevant_factors:
      - Customer age
      - Tenure (months as customer)
      - Monthly charges
      - Contract type
      - Payment method
    
    evaluation_factors:
      - Customer segment (consumer/business)
      - Geographic region
      - Service type
  
  metrics:
    model_performance:
      - metric: Accuracy
        value: 0.87
        threshold: 0.85
      
      - metric: Precision
        value: 0.85
        threshold: 0.80
      
      - metric: Recall
        value: 0.89
        threshold: 0.85
      
      - metric: F1 Score
        value: 0.87
      
      - metric: ROC AUC
        value: 0.93
    
    decision_thresholds:
      default: 0.5
      high_precision: 0.7  # Use when false positives costly
      high_recall: 0.3     # Use when catching all churners critical
  
  training_data:
    dataset:
      name: Customer Churn Dataset
      size: 500,000 customers
      time_period: 2021-01-01 to 2023-10-31
      source: Production database
    
    preprocessing:
      - Removed customers with <3 months tenure
      - Imputed missing values (median for numeric, mode for categorical)
      - Scaled numeric features (StandardScaler)
      - One-hot encoded categorical features
    
    data_splits:
      training: 70% (350,000)
      validation: 15% (75,000)
      test: 15% (75,000)
  
  evaluation_data:
    datasets:
      - name: Test Set
        size: 75,000
        performance: See metrics above
      
      - name: Holdout Set (Q4 2023)
        size: 50,000
        performance:
          accuracy: 0.86
          precision: 0.84
          recall: 0.88
  
  ethical_considerations:
    risks:
      - Potential bias against certain demographics
      - Privacy concerns with customer data
      - Risk of discriminatory targeting
    
    mitigations:
      - Bias testing across customer segments
      - Differential privacy in training
      - Regular fairness audits
      - Human review of high-risk predictions
  
  caveats_and_recommendations:
    - Model degrades over time (retrain quarterly)
    - Performance varies by customer segment
    - Use ensemble with rule-based system for critical decisions
    - Monitor for concept drift (data distribution changes)
  
  model_details:
    algorithm: HistGradientBoostingClassifier
    framework: scikit-learn 1.3.0
    hyperparameters:
      max_depth: 10
      learning_rate: 0.1
      n_estimators: 200
      min_samples_split: 50
    
    features:
      count: 45
      types:
        - 15 numeric
        - 30 categorical (one-hot encoded)
  
  references:
    papers:
      - "Customer Churn Prediction: A Comparative Study"
      - "Gradient Boosting for Imbalanced Classification"
    
    related_models:
      - churn-model-v2 (previous version)
      - churn-model-regional (region-specific variants)
```

---

## Key Takeaways

### Documentation Best Practices

1. **Keep it Current**: Review quarterly
2. **Make it Discoverable**: Central wiki/repo
3. **Use Templates**: Standardize format
4. **Include Examples**: Code snippets, commands
5. **Version Control**: Track changes in Git

### Essential Documents

- ✅ API documentation (OpenAPI)
- ✅ Runbooks for incidents
- ✅ Architecture Decision Records
- ✅ Model cards
- ✅ Onboarding guides
- ✅ Deployment guides

---

## Next Steps

Continue to **[Section 33: MLOps Capstone Project - Part 1](../module-10-capstone/section-33-capstone-part1.md)**

---

**Progress**: 30/34 sections complete (88%) → **31/34 (91%)**
