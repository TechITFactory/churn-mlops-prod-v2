# Section 10: Model Evaluation & Metrics

**Duration**: 2.5 hours  
**Level**: Intermediate to Advanced  
**Prerequisites**: Section 09

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand classification metrics (accuracy, precision, recall, F1)
- ✅ Master the precision-recall tradeoff
- ✅ Use ROC-AUC and PR-AUC correctly
- ✅ Interpret confusion matrices
- ✅ Choose the right metric for business goals
- ✅ Visualize model performance
- ✅ Compare models objectively

---

## 📚 Table of Contents

1. [Why Accuracy is Not Enough](#why-accuracy-is-not-enough)
2. [Classification Metrics Overview](#classification-metrics-overview)
3. [Code Walkthrough: Evaluation](#code-walkthrough)
4. [Confusion Matrix Deep Dive](#confusion-matrix-deep-dive)
5. [Precision vs Recall Tradeoff](#precision-vs-recall-tradeoff)
6. [ROC-AUC vs PR-AUC](#roc-auc-vs-pr-auc)
7. [Choosing the Right Metric](#choosing-the-right-metric)
8. [Hands-On Exercise](#hands-on-exercise)
9. [Assessment Questions](#assessment-questions)

---

## Why Accuracy is Not Enough

### The Imbalanced Dataset Problem

**Scenario**: TechITFactory churn dataset

```
Total users: 10,000
Churned (1): 500  (5%)
Active (0):  9,500 (95%)
```

**Naive Model**: Always predict 0 (never churn)

```python
# Dumb model
def predict(user):
    return 0  # Always predict "active"

# Accuracy
correct = 9500  # Predicted all active users correctly
total = 10000
accuracy = correct / total = 95%  🎉
```

**Problem**: 95% accuracy sounds great, but model is useless!
- Never predicts churn (misses all 500 churned users)
- Business can't act on predictions

**Lesson**: **Accuracy is misleading for imbalanced data**

---

## Classification Metrics Overview

### The Four Outcomes

```
Confusion Matrix:

                  Predicted
                  0 (Active)  1 (Churned)
Actual  ┌─────────────────────────────────┐
0       │   TN              FP            │ (Active)
        │   9400            100           │
        ├─────────────────────────────────┤
1       │   FN              TP            │ (Churned)
        │   100             400           │
        └─────────────────────────────────┘

TN = True Negative (predicted active, actually active) = 9400
FP = False Positive (predicted churned, actually active) = 100
FN = False Negative (predicted active, actually churned) = 100
TP = True Positive (predicted churned, actually churned) = 400
```

### Key Metrics

#### 1. Accuracy
```
Accuracy = (TP + TN) / (TP + TN + FP + FN)
         = (400 + 9400) / 10000
         = 98%

Problem: Dominated by majority class (TN)
```

#### 2. Precision
```
Precision = TP / (TP + FP)
          = 400 / (400 + 100)
          = 80%

Interpretation: "Of all users we predicted would churn, 80% actually churned"
Business: "How reliable are our churn predictions?"
```

#### 3. Recall (Sensitivity, True Positive Rate)
```
Recall = TP / (TP + FN)
       = 400 / (400 + 100)
       = 80%

Interpretation: "Of all users who churned, we caught 80%"
Business: "How many churners did we miss?"
```

#### 4. F1-Score
```
F1 = 2 × (Precision × Recall) / (Precision + Recall)
   = 2 × (0.8 × 0.8) / (0.8 + 0.8)
   = 0.8 (80%)

Interpretation: Harmonic mean of precision and recall
Use when: You want balance between precision and recall
```

#### 5. Specificity (True Negative Rate)
```
Specificity = TN / (TN + FP)
            = 9400 / (9400 + 100)
            = 99%

Interpretation: "Of all active users, we correctly identified 99%"
```

---

## Code Walkthrough

### File: `src/churn_mlops/training/train_baseline.py` (Evaluation Function)

```python
def _evaluate(model: Pipeline, X_test: pd.DataFrame, y_test: pd.Series) -> Dict[str, Any]:
    """
    Compute comprehensive evaluation metrics.
    
    Returns:
    - pr_auc: Precision-Recall AUC (best for imbalanced)
    - roc_auc: ROC AUC (general metric)
    - confusion_matrix: 2x2 matrix [[TN, FP], [FN, TP]]
    - classification_report: Precision, Recall, F1 per class
    - pr_curve_sample: Sample points from PR curve (for plotting)
    """
    
    # Get predicted probabilities (not hard predictions!)
    proba = model.predict_proba(X_test)[:, 1]
    # proba[i] = P(churn=1 | features[i])
    # Example: [0.05, 0.82, 0.15, ...] (probabilities for each test user)
    
    # Metric 1: PR-AUC (Area Under Precision-Recall Curve)
    pr_auc = float(average_precision_score(y_test, proba))
    
    # Metric 2: ROC-AUC (Area Under ROC Curve)
    roc_auc = float(roc_auc_score(y_test, proba)) if len(np.unique(y_test)) > 1 else 0.0
    # Edge case: If test set has only one class, ROC-AUC undefined
    
    # Convert probabilities to hard predictions (threshold=0.5)
    y_pred = (proba >= 0.5).astype(int)
    # [0.05, 0.82, 0.15] → [0, 1, 0]
    
    # Metric 3: Classification Report (precision, recall, F1 per class)
    report = classification_report(y_test, y_pred, output_dict=True, zero_division=0)
    # Output:
    # {
    #   "0": {"precision": 0.98, "recall": 0.99, "f1-score": 0.98, "support": 9500},
    #   "1": {"precision": 0.80, "recall": 0.80, "f1-score": 0.80, "support": 500},
    #   "accuracy": 0.98,
    #   "macro avg": {...},
    #   "weighted avg": {...}
    # }
    
    # Metric 4: Confusion Matrix
    cm = confusion_matrix(y_test, y_pred).tolist()
    # Output: [[TN, FP], [FN, TP]]
    # Example: [[9400, 100], [100, 400]]
    
    # Metric 5: Precision-Recall Curve (for visualization)
    precisions, recalls, thresholds = precision_recall_curve(y_test, proba)
    # precisions[i] = precision at threshold[i]
    # recalls[i] = recall at threshold[i]
    # Sample first 10 points for storage
    pr_curve_sample = {
        "precision_head": [float(x) for x in precisions[:10]],
        "recall_head": [float(x) for x in recalls[:10]],
    }
    
    return {
        "pr_auc": pr_auc,
        "roc_auc": roc_auc,
        "confusion_matrix": cm,
        "classification_report": report,
        "pr_curve_sample": pr_curve_sample,
    }
```

**Key Points**:
- Use **probabilities** (not hard predictions) for AUC metrics
- **Hard predictions** (0/1) needed for confusion matrix
- Store curve samples (for later visualization)

---

## Confusion Matrix Deep Dive

### Visual Representation

```
                    PREDICTED
                    Negative    Positive
                    (Active)    (Churn)
              ┌─────────────────────────┐
ACTUAL        │                         │
Negative      │   TN          FP        │  Total Actual Negatives
(Active)      │   9400        100       │  = TN + FP = 9500
              ├─────────────────────────┤
Positive      │   FN          TP        │  Total Actual Positives
(Churn)       │   100         400       │  = FN + TP = 500
              └─────────────────────────┘
                Total Pred    Total Pred
                Negatives     Positives
                = TN + FN     = FP + TP
                = 9500        = 500
```

### Business Interpretation

| Outcome | Count | Business Meaning |
|---------|-------|------------------|
| **TN** (True Negative) | 9400 | Correctly predicted active → No wasted intervention |
| **TP** (True Positive) | 400 | Correctly predicted churn → Can intervene (offer discount) |
| **FP** (False Positive) | 100 | Predicted churn, but user stayed → Wasted discount |
| **FN** (False Negative) | 100 | Missed churner → Lost customer (most costly!) |

### Cost Analysis

```
Costs per outcome:
- TN: $0 (correct, no action)
- TP: $10 (discount given, retained user) → Saves $100 (customer lifetime value)
- FP: $10 (discount given to non-churner) → Wasted
- FN: $100 (lost customer, no intervention)

Total cost = (FP × $10) + (FN × $100)
           = (100 × $10) + (100 × $100)
           = $1,000 + $10,000
           = $11,000

If we reduce FN (increase recall):
FN = 50, FP = 150
Total cost = (150 × $10) + (50 × $100) = $1,500 + $5,000 = $6,500 ✅ Better!
```

---

## Precision vs Recall Tradeoff

### The Tradeoff Explained

```
Threshold = 0.9 (very strict):
- Predict churn only if P(churn) > 0.9
- High Precision (few false alarms)
- Low Recall (miss many churners)

Threshold = 0.1 (very lenient):
- Predict churn if P(churn) > 0.1
- Low Precision (many false alarms)
- High Recall (catch most churners)
```

### Visual Example

```
User Probabilities:
User A: 0.95 → Churn (very confident)
User B: 0.85 → Churn
User C: 0.65 → Churn
User D: 0.55 → Churn
User E: 0.45 → Active
User F: 0.15 → Active
User G: 0.05 → Active (very confident)

Actual labels:
A, B, C, D = Churned (4 positives)
E, F, G = Active (3 negatives)

Threshold = 0.5 (default):
Predicted Churn: A, B, C, D (4 predictions)
TP = 4, FP = 0
Precision = 4/4 = 100%
Recall = 4/4 = 100%  ← Perfect!

Threshold = 0.8 (strict):
Predicted Churn: A, B (2 predictions)
TP = 2, FP = 0, FN = 2 (missed C, D)
Precision = 2/2 = 100%  ← High precision
Recall = 2/4 = 50%      ← Low recall

Threshold = 0.3 (lenient):
Predicted Churn: A, B, C, D, E (5 predictions)
TP = 4, FP = 1 (E is false alarm), FN = 0
Precision = 4/5 = 80%   ← Lower precision
Recall = 4/4 = 100%     ← High recall
```

### Precision-Recall Curve

```
Precision
    │
1.0 │ ●
    │  ╲
    │   ●─●
    │      ╲
0.8 │       ●─●
    │          ╲
    │           ●─●
0.6 │              ╲
    │               ●────●
    │                    ╲
0.4 │                     ●──────●
    │                            ╲
0.2 │                             ●────────────●
    │
0.0 └───────────────────────────────────────────→ Recall
    0.0                                        1.0

Area Under Curve (PR-AUC) = 0.85
Higher is better! (Perfect = 1.0)
```

---

## ROC-AUC vs PR-AUC

### ROC Curve (Receiver Operating Characteristic)

**Axes**:
- X-axis: False Positive Rate (FPR) = FP / (FP + TN)
- Y-axis: True Positive Rate (TPR) = TP / (TP + FN) = Recall

```
TPR (Recall)
    │
1.0 │         ●─────●
    │       ╱       │
    │     ╱         │
0.8 │   ╱           │ ← Our model
    │  ╱            │
    │ ╱             │
0.6 │●              │
    │               │
    │               │
0.4 │               │ ╱ Random baseline (AUC=0.5)
    │              ╱│╱
0.2 │            ╱  ●
    │          ╱
0.0 └─────────────────────────────→ FPR
    0.0                          1.0

ROC-AUC = 0.92 (area under blue curve)
Perfect model: AUC = 1.0
Random model: AUC = 0.5
```

**Interpretation**:
- ROC-AUC = 0.92 → Model can distinguish classes well
- At any FPR, we have high TPR

### PR Curve (Precision-Recall)

**Axes**:
- X-axis: Recall = TP / (TP + FN)
- Y-axis: Precision = TP / (TP + FP)

```
Precision
    │
1.0 │●─●
    │   ╲
    │    ●─●
0.8 │       ╲
    │        ●─●  ← Our model
    │           ╲
0.6 │            ●─●
    │               ╲
0.4 │                ●────●
    │                     ╲
0.2 │                      ●────────●
    │
0.0 └──────────────────────────────────→ Recall
    0.0                              1.0

PR-AUC = 0.75
Perfect model: AUC = 1.0
Random model: AUC = baseline churn rate (e.g., 0.05)
```

### When to Use Which?

| Scenario | Recommended Metric | Reason |
|----------|-------------------|--------|
| **Balanced dataset** (50/50) | ROC-AUC | Both classes equally important |
| **Imbalanced dataset** (95/5) | **PR-AUC** ✅ | Focuses on positive class (churn) |
| **Both classes matter** | ROC-AUC | Considers TN and FP |
| **Positive class critical** | PR-AUC | Ignores TN (not inflated by majority class) |

**TechITFactory**: Use **PR-AUC** (imbalanced: ~20% churn rate)

### Why PR-AUC Better for Imbalance?

**ROC-AUC problem**:
```
Imbalanced dataset: 95% negative, 5% positive

Model A (bad):
- Predicts everyone as negative
- TPR = 0 (no positives caught)
- FPR = 0 (no false alarms)
- But TN = 9500 (huge!)
- ROC-AUC = 0.50 (not terrible looking, but model is useless)

Model B (good):
- Actually predicts churn
- TPR = 0.80, FPR = 0.10
- ROC-AUC = 0.92 (good)

Problem: TN (9500) inflates ROC-AUC even for bad models
```

**PR-AUC solution**:
```
Model A (bad):
- Precision = 0 (never predicts positive)
- Recall = 0
- PR-AUC = 0.05 (baseline) ✅ Correctly shows model is bad

Model B (good):
- Precision = 0.80
- Recall = 0.80
- PR-AUC = 0.75 ✅ Correctly shows model is good
```

---

## Choosing the Right Metric

### Decision Tree for Metric Selection

```
┌─────────────────────────────────────┐
│ What's the business goal?          │
└───────────┬─────────────────────────┘
            │
            ↓
┌───────────────────────────────────────────────┐
│ Minimize false negatives (don't miss churn)? │
└───────────┬───────────────────────────────────┘
            │ YES
            ↓
      ┌──────────┐
      │  RECALL  │  ← Maximize (catch all churners)
      └──────────┘
            │ NO
            ↓
┌───────────────────────────────────────────────┐
│ Minimize false positives (avoid wasted       │
│ discounts)?                                   │
└───────────┬───────────────────────────────────┘
            │ YES
            ↓
      ┌────────────┐
      │ PRECISION  │  ← Maximize (only act on confident predictions)
      └────────────┘
            │ NO
            ↓
┌───────────────────────────────────────────────┐
│ Balance both (catch churners but avoid false │
│ alarms)?                                      │
└───────────┬───────────────────────────────────┘
            │ YES
            ↓
      ┌───────────┐
      │ F1-SCORE  │  ← Harmonic mean of precision & recall
      └───────────┘
            │
            ↓
      ┌───────────┐
      │ PR-AUC    │  ← Overall quality across all thresholds
      └───────────┘
```

### TechITFactory Business Requirements

```
Priority 1: Don't lose customers (minimize FN)
Priority 2: Don't waste discounts (minimize FP)

Optimal Metric: PR-AUC (balances both)
Monitoring: Recall @ 80% Precision (business constraint)
```

---

## Hands-On Exercise

### Exercise 1: Analyze Baseline Model Metrics

```python
import json
from pathlib import Path

# Load latest metrics
metrics_files = sorted(Path('artifacts/metrics').glob('baseline_*.json'))
latest_metrics_path = metrics_files[-1]

with open(latest_metrics_path) as f:
    metrics = json.load(f)

# Extract key metrics
print(f"PR-AUC: {metrics['metrics']['pr_auc']:.4f}")
print(f"ROC-AUC: {metrics['metrics']['roc_auc']:.4f}")
print(f"\nConfusion Matrix:")
cm = metrics['metrics']['confusion_matrix']
print(f"  [[TN={cm[0][0]}, FP={cm[0][1]}],")
print(f"   [FN={cm[1][0]}, TP={cm[1][1]}]]")

# Classification report
report = metrics['metrics']['classification_report']
print(f"\nClass 1 (Churn):")
print(f"  Precision: {report['1']['precision']:.2%}")
print(f"  Recall: {report['1']['recall']:.2%}")
print(f"  F1-Score: {report['1']['f1-score']:.2%}")
```

### Exercise 2: Compute Metrics Manually

```python
import numpy as np

# Confusion matrix values
TN, FP, FN, TP = 9400, 100, 100, 400

# Compute metrics manually
accuracy = (TP + TN) / (TP + TN + FP + FN)
precision = TP / (TP + FP)
recall = TP / (TP + FN)
f1 = 2 * (precision * recall) / (precision + recall)
specificity = TN / (TN + FP)

print(f"Accuracy: {accuracy:.2%}")
print(f"Precision: {precision:.2%}")
print(f"Recall: {recall:.2%}")
print(f"F1-Score: {f1:.2%}")
print(f"Specificity: {specificity:.2%}")

# Verify against sklearn
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score

y_true = np.array([0]*9500 + [1]*500)  # 9500 negatives, 500 positives
y_pred = np.array([0]*9400 + [1]*100 + [0]*100 + [1]*400)  # From confusion matrix

print(f"\nSklearn verification:")
print(f"Accuracy: {accuracy_score(y_true, y_pred):.2%}")
print(f"Precision: {precision_score(y_true, y_pred):.2%}")
print(f"Recall: {recall_score(y_true, y_pred):.2%}")
print(f"F1-Score: {f1_score(y_true, y_pred):.2%}")
```

### Exercise 3: Visualize Precision-Recall Curve

```python
import joblib
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.metrics import precision_recall_curve

# Load model and test data
artifact = joblib.load('artifacts/models/baseline_20250115_143022.pkl')
model = artifact['model']

# Recreate test set (or load saved test set)
df = pd.read_csv('data/features/training_dataset.csv')
df = df.sort_values('as_of_date')
test_df = df.iloc[int(len(df)*0.7):]

X_test = test_df.drop(columns=['churn_label', 'user_id', 'as_of_date', 'signup_date'])
y_test = test_df['churn_label']

# Get predictions
proba = model.predict_proba(X_test)[:, 1]

# Compute PR curve
precisions, recalls, thresholds = precision_recall_curve(y_test, proba)

# Plot
plt.figure(figsize=(10, 6))
plt.plot(recalls, precisions, label=f'Baseline (PR-AUC={average_precision_score(y_test, proba):.3f})')
plt.xlabel('Recall')
plt.ylabel('Precision')
plt.title('Precision-Recall Curve')
plt.legend()
plt.grid(True)
plt.savefig('pr_curve.png')
plt.show()

print(f"Saved PR curve to pr_curve.png")
```

### Exercise 4: Find Optimal Threshold

```python
from sklearn.metrics import precision_recall_curve
import numpy as np

# Compute PR curve
precisions, recalls, thresholds = precision_recall_curve(y_test, proba)

# Business requirement: Precision >= 80%
min_precision = 0.80

# Find best recall at precision >= 80%
valid_indices = np.where(precisions >= min_precision)[0]
best_idx = valid_indices[np.argmax(recalls[valid_indices])]

optimal_threshold = thresholds[best_idx]
optimal_precision = precisions[best_idx]
optimal_recall = recalls[best_idx]

print(f"Optimal Threshold: {optimal_threshold:.3f}")
print(f"At this threshold:")
print(f"  Precision: {optimal_precision:.2%}")
print(f"  Recall: {optimal_recall:.2%}")

# Apply optimal threshold
y_pred_optimal = (proba >= optimal_threshold).astype(int)

from sklearn.metrics import confusion_matrix
cm = confusion_matrix(y_test, y_pred_optimal)
print(f"\nConfusion Matrix at optimal threshold:")
print(cm)
```

### Exercise 5: Compare Multiple Models

```python
import json
from pathlib import Path
import pandas as pd

# Load all model metrics
metrics_files = sorted(Path('artifacts/metrics').glob('*.json'))

results = []
for path in metrics_files:
    with open(path) as f:
        data = json.load(f)
    
    results.append({
        'model': path.stem,
        'pr_auc': data['metrics']['pr_auc'],
        'roc_auc': data['metrics']['roc_auc'],
        'precision': data['metrics']['classification_report']['1']['precision'],
        'recall': data['metrics']['classification_report']['1']['recall'],
    })

df = pd.DataFrame(results).sort_values('pr_auc', ascending=False)
print(df.to_string(index=False))

# Best model by PR-AUC
best = df.iloc[0]
print(f"\n🏆 Best Model: {best['model']}")
print(f"   PR-AUC: {best['pr_auc']:.4f}")
```

---

## Assessment Questions

### Question 1: Multiple Choice
For an imbalanced churn dataset (95% active, 5% churn), which metric is most appropriate?

A) Accuracy  
B) ROC-AUC  
C) **PR-AUC** ✅  
D) Specificity  

**Explanation**: PR-AUC focuses on the positive class (churn) and isn't inflated by the large number of true negatives.

---

### Question 2: True/False
**Statement**: A model with 95% accuracy on an imbalanced dataset is definitely good.

**Answer**: False ❌  
**Explanation**: High accuracy can be misleading. A model that always predicts the majority class gets high accuracy but is useless.

---

### Question 3: Short Answer
What's the business cost of False Negatives (FN) in churn prediction?

**Answer**:
- FN = Predicted active, but user churned
- Cost: Lost customer (no intervention attempted)
- Typically most expensive outcome ($100 customer lifetime value lost)
- Worse than False Positive (wasted $10 discount)

---

### Question 4: Code Analysis
What does this confusion matrix tell you?

```
[[9400, 100],
 [ 400,  100]]
```

**Answer**:
- TN=9400, FP=100, FN=400, TP=100
- Precision = 100/(100+100) = 50% (half of churn predictions are wrong)
- Recall = 100/(100+400) = 20% (only catching 20% of churners!)
- Model has low recall → Missing most churners (bad!)

---

### Question 5: Design Challenge
Your business can afford to give discounts to at most 10% of users. How do you use model predictions?

**Answer**:
```python
# Get predictions for all users
probas = model.predict_proba(X)[:, 1]

# Sort by churn probability (highest first)
sorted_indices = np.argsort(probas)[::-1]

# Select top 10%
n_users = len(probas)
top_10_percent = int(n_users * 0.10)
users_to_target = sorted_indices[:top_10_percent]

# Give discounts only to these high-risk users
# This maximizes precision (targets most confident predictions)
```

---

## Key Takeaways

### ✅ What You Learned

1. **Why Accuracy Fails**
   - Misleading for imbalanced datasets
   - Dominated by majority class
   - Use precision, recall, F1 instead

2. **Confusion Matrix**
   - TN, FP, FN, TP (four outcomes)
   - Business interpretation (costs per outcome)
   - Foundation for all metrics

3. **Precision vs Recall Tradeoff**
   - Threshold determines tradeoff
   - High precision → fewer false alarms
   - High recall → catch more positives
   - Can't maximize both simultaneously

4. **PR-AUC vs ROC-AUC**
   - PR-AUC for imbalanced data (focuses on positive class)
   - ROC-AUC for balanced data (considers both classes)
   - PR-AUC = area under precision-recall curve

5. **Metric Selection**
   - Choose based on business goal
   - Minimize FN → maximize Recall
   - Minimize FP → maximize Precision
   - Balance → F1-Score or PR-AUC

---

## Next Steps

You now understand how to evaluate models rigorously!

**Next Section**: [Section 11: Handling Class Imbalance](./section-11-class-imbalance.md)

In the next section, we'll:
- Understand class imbalance problem
- Implement SMOTE (oversampling)
- Use class weights
- Compare imbalance strategies

---

## Additional Resources

### Metrics:
- [Classification Metrics (Sklearn)](https://scikit-learn.org/stable/modules/model_evaluation.html#classification-metrics)
- [Precision-Recall vs ROC (Explained)](https://machinelearningmastery.com/roc-curves-and-precision-recall-curves-for-classification-in-python/)

### Confusion Matrix:
- [Confusion Matrix (Visual Guide)](https://www.dataschool.io/simple-guide-to-confusion-matrix-terminology/)

---

**🎉 Congratulations!** You've completed Section 10!

Next: **[Section 11: Handling Class Imbalance](./section-11-class-imbalance.md)** →
