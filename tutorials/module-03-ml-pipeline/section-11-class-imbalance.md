# Section 11: Handling Class Imbalance

**Duration**: 2.5 hours  
**Level**: Advanced  
**Prerequisites**: Sections 08-10

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand the class imbalance problem
- ✅ Implement SMOTE (Synthetic Minority Oversampling)
- ✅ Use class weights effectively
- ✅ Apply undersampling strategies
- ✅ Compare imbalance techniques empirically
- ✅ Choose the right strategy for your dataset
- ✅ Train candidate models (HistGradientBoosting)

---

## 📚 Table of Contents

1. [What is Class Imbalance?](#what-is-class-imbalance)
2. [Why Imbalance Hurts Models](#why-imbalance-hurts-models)
3. [Strategy 1: Class Weights](#strategy-1-class-weights)
4. [Strategy 2: Oversampling (SMOTE)](#strategy-2-oversampling-smote)
5. [Strategy 3: Undersampling](#strategy-3-undersampling)
6. [Code Walkthrough: train_candidate.py](#code-walkthrough)
7. [Comparing Strategies](#comparing-strategies)
8. [Hands-On Exercise](#hands-on-exercise)
9. [Assessment Questions](#assessment-questions)

---

## What is Class Imbalance?

### Definition

> **Class Imbalance**: When one class (minority) has significantly fewer samples than another (majority).

```
Balanced Dataset:
Class 0: 5000 samples (50%)
Class 1: 5000 samples (50%)
Imbalance Ratio: 1:1

Imbalanced Dataset:
Class 0: 9500 samples (95%)
Class 1:  500 samples (5%)
Imbalance Ratio: 19:1

Severely Imbalanced:
Class 0: 9900 samples (99%)
Class 1:  100 samples (1%)
Imbalance Ratio: 99:1
```

### Real-World Examples

| Domain | Positive Class | Imbalance Ratio |
|--------|----------------|-----------------|
| **Fraud Detection** | Fraudulent transactions | 1000:1 (0.1%) |
| **Churn Prediction** | Churned users | 5:1 to 20:1 (5-20%) |
| **Disease Diagnosis** | Rare disease | 100:1 (1%) |
| **Spam Detection** | Spam emails | 10:1 (10%) |
| **Credit Default** | Defaulted loans | 30:1 (3%) |

**TechITFactory**: ~20% churn rate → 4:1 imbalance (moderate)

---

## Why Imbalance Hurts Models

### The Majority Class Bias

**Problem**: Models optimize for overall accuracy → Biased toward majority class

```python
# Imbalanced dataset
X_train: 9500 class 0 (active), 500 class 1 (churn)
y_train: [0, 0, 0, ..., 0, 1, 1, ..., 1]

# Model training (implicitly)
# Minimizes: Loss = Σ errors
# Since there are 19× more class 0 samples, model focuses on them!

# Result: Model learns to predict class 0 most of the time
```

**Visual**:
```
Training Process:

Iteration 1:
  Predict all 0 → Error on 500 (class 1)
  Predict all 1 → Error on 9500 (class 0)
  Model chooses: Predict all 0 (fewer errors!)

Iteration 100:
  Model: "Churn? Nah, always predict active"
  Accuracy: 95% (but useless for churn prediction!)
```

### Impact on Metrics

```
Naive Model (always predict 0):
Accuracy: 95% ✅ (looks good!)
Precision: 0% ❌ (never predicts churn)
Recall: 0% ❌ (catches no churners)
F1: 0% ❌
PR-AUC: 0.05 ❌ (baseline, random)

Business Impact: Model is worthless!
```

---

## Strategy 1: Class Weights

### Concept

**Idea**: Give higher weight to minority class samples during training

```
Without weights:
Loss = (error_sample1 + error_sample2 + ... + error_sample10000) / 10000
All samples contribute equally

With weights:
Loss = (w0×error_class0_samples + w1×error_class1_samples)
w0 = 1.0 (majority)
w1 = 19.0 (minority gets 19× weight)
Minority class errors penalized more → Model pays attention!
```

### Balanced Class Weights (sklearn)

```python
from sklearn.linear_model import LogisticRegression

# Automatically compute balanced weights
# Formula: w_i = n_samples / (n_classes × n_samples_class_i)
#
# Example:
# n_samples = 10000
# n_classes = 2
# n_samples_class_0 = 9500
# n_samples_class_1 = 500
#
# w_0 = 10000 / (2 × 9500) = 0.526
# w_1 = 10000 / (2 × 500) = 10.0
#
# Class 1 gets ~19× higher weight!

model = LogisticRegression(class_weight='balanced')
model.fit(X_train, y_train)
```

**Benefits**:
- ✅ Simple (one parameter change)
- ✅ No data modification
- ✅ Works with any sklearn classifier
- ✅ Fast (no resampling needed)

**Drawbacks**:
- ⚠️ May overfit to minority class (too much weight)
- ⚠️ Doesn't add information (just reweights existing samples)

---

## Strategy 2: Oversampling (SMOTE)

### Random Oversampling (Naive)

```
Original Data:
Class 0: [sample1, sample2, ..., sample9500]
Class 1: [sampleA, sampleB, ..., sample500]

Random Oversampling:
Duplicate minority samples randomly until balanced

Class 1 (after): [sampleA, sampleB, ..., sample500, 
                  sampleA (copy), sampleB (copy), ..., (19× total)]

Problem: Exact duplicates → Overfitting!
Model memorizes minority samples
```

### SMOTE (Synthetic Minority Oversampling Technique)

**Idea**: Generate **synthetic** samples (not duplicates) by interpolating between existing minority samples

```python
from imblearn.over_sampling import SMOTE

# Original
X_train: 10000 samples (9500 class 0, 500 class 1)

# Apply SMOTE
smote = SMOTE(sampling_strategy=0.5, random_state=42)
X_resampled, y_resampled = smote.fit_resample(X_train, y_train)

# After
X_resampled: 14250 samples (9500 class 0, 4750 class 1)
# sampling_strategy=0.5 means: minority = 0.5 × majority
```

### How SMOTE Works

```
Step 1: Pick a minority sample (e.g., sample A)
A = [logins_7d=5, days_since=10]

Step 2: Find K nearest neighbors (e.g., K=5) from minority class
Neighbors = [B, C, D, E, F]
B = [logins_7d=7, days_since=8]

Step 3: Pick random neighbor (e.g., B)

Step 4: Interpolate between A and B
# Random point on line between A and B
lambda = random(0, 1) = 0.6
synthetic = A + lambda × (B - A)
synthetic = [5, 10] + 0.6 × ([7, 8] - [5, 10])
synthetic = [5, 10] + 0.6 × [2, -2]
synthetic = [5, 10] + [1.2, -1.2]
synthetic = [6.2, 8.8]

Step 5: Repeat until desired balance
```

**Visual**:
```
Feature Space (2D):
Minority samples:
    A ●         ● B
      
       ★ (synthetic, interpolated)
      
    C ●         ● D

Synthetic sample ★ is realistic (between A and B)
Not a duplicate! Has different feature values
```

**Benefits**:
- ✅ Generates realistic synthetic samples
- ✅ Adds information (not just duplicates)
- ✅ Reduces overfitting vs random oversampling

**Drawbacks**:
- ⚠️ Increases training time (more samples)
- ⚠️ Can generate unrealistic samples (if minority class has multiple clusters)
- ⚠️ Requires tuning (K, sampling_strategy)

### SMOTE Variants

| Variant | Description |
|---------|-------------|
| **SMOTE** | Standard (interpolate between K neighbors) |
| **SMOTE-Tomek** | SMOTE + remove noisy boundary samples |
| **SMOTE-ENN** | SMOTE + remove misclassified samples |
| **ADASYN** | Adaptive SMOTE (more synthesis near decision boundary) |
| **BorderlineSMOTE** | Focus synthesis on borderline samples |

---

## Strategy 3: Undersampling

### Random Undersampling

**Idea**: Remove majority class samples to balance dataset

```
Original:
Class 0: 9500 samples
Class 1: 500 samples

Random Undersampling:
Randomly select 500 samples from class 0

After:
Class 0: 500 samples (randomly selected)
Class 1: 500 samples (all kept)
Total: 1000 samples (10× smaller!)
```

**Benefits**:
- ✅ Fast training (smaller dataset)
- ✅ Balanced classes

**Drawbacks**:
- ❌ **Information loss** (discarded 9000 samples!)
- ❌ May lose important patterns
- ❌ Not recommended for small datasets

### Tomek Links (Smart Undersampling)

**Idea**: Remove **noisy** majority samples near decision boundary

```
Tomek Link: Pair of samples from different classes that are nearest neighbors

Example:
Class 0 sample: A = [10, 5]
Class 1 sample: B = [10.5, 5.1]  (very close!)

If A and B are each other's nearest neighbors → Tomek Link
Remove A (majority class sample)

Benefit: Cleaner decision boundary
```

---

## Code Walkthrough

### File: `src/churn_mlops/training/train_candidate.py`

**Candidate Model** = More sophisticated model (HistGradientBoosting) vs baseline (LogisticRegression)

#### Model: HistGradientBoostingClassifier

```python
from sklearn.ensemble import HistGradientBoostingClassifier

def _build_pipeline(cat_cols: List[str], num_cols: List[str], random_state: int) -> Pipeline:
    """
    Build pipeline with HistGradientBoosting (stronger than LogisticRegression)
    
    HistGradientBoosting:
    - Gradient boosting (ensemble of decision trees)
    - Handles categorical features natively (no need for one-hot encoding!)
    - Faster than standard GradientBoosting
    - Built-in missing value handling
    """
    
    # Categorical preprocessing (simpler than baseline)
    categorical = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="constant", fill_value="missing")),
            ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
        ]
    )
    
    # Numeric preprocessing
    numeric = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="constant", fill_value=0.0)),
            # Note: No StandardScaler! HistGradientBoosting doesn't need it
        ]
    )
    
    pre = ColumnTransformer(
        transformers=[
            ("cat", categorical, cat_cols),
            ("num", numeric, num_cols),
        ],
        remainder="drop",
    )
    
    # Strong candidate model
    clf = HistGradientBoostingClassifier(
        max_iter=100,              # Number of boosting iterations
        learning_rate=0.1,         # Step size
        max_depth=5,               # Tree depth (prevents overfitting)
        min_samples_leaf=20,       # Min samples per leaf (regularization)
        random_state=random_state,
    )
    
    return Pipeline(steps=[("preprocess", pre), ("model", clf)])
```

**Why HistGradientBoosting?**
- **Stronger**: Ensemble of trees (vs single linear model)
- **Faster**: Histogram-based (bins features)
- **Native categorical support**: Handles categories internally
- **Robust**: Less sensitive to feature scaling

#### Training with SMOTE (Optional)

```python
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline as ImbPipeline

def train_with_smote():
    """Train model with SMOTE oversampling"""
    
    # Standard preprocessing
    preprocessor = _build_preprocessor(cat_cols, num_cols)
    
    # SMOTE (applied after preprocessing, before model)
    smote = SMOTE(
        sampling_strategy=0.5,  # Minority = 50% of majority
        k_neighbors=5,          # Number of neighbors for synthesis
        random_state=42
    )
    
    # Model
    clf = HistGradientBoostingClassifier(...)
    
    # Pipeline: Preprocess → SMOTE → Model
    # Note: Use imblearn.pipeline.Pipeline (not sklearn.pipeline.Pipeline)
    # because SMOTE needs to see y (labels)
    pipeline = ImbPipeline([
        ('preprocess', preprocessor),
        ('smote', smote),
        ('model', clf)
    ])
    
    pipeline.fit(X_train, y_train)
```

**Key Point**: SMOTE must be in pipeline to avoid data leakage!

```
❌ WRONG (leakage):
X_resampled, y_resampled = SMOTE().fit_resample(X_train, y_train)
# Problem: SMOTE sees entire training set (including validation folds)
model.fit(X_resampled, y_resampled)

✅ CORRECT (no leakage):
pipeline = ImbPipeline([
    ('smote', SMOTE()),
    ('model', model)
])
pipeline.fit(X_train, y_train)
# SMOTE applied only to training fold (not validation)
```

---

## Comparing Strategies

### Experiment Setup

Train 4 models with different strategies:

| Model | Strategy | Description |
|-------|----------|-------------|
| **Baseline** | None | LogisticRegression, no imbalance handling |
| **Class Weight** | Weighted loss | LogisticRegression, class_weight='balanced' |
| **SMOTE** | Oversampling | LogisticRegression, SMOTE(sampling_strategy=0.5) |
| **Candidate** | Advanced model | HistGradientBoosting (handles imbalance better) |

### Expected Results

```
Model Performance (PR-AUC):

Baseline (no handling):        0.65  ← Poor (biased toward majority)
Class Weight:                  0.72  ← Better (balanced loss)
SMOTE:                         0.75  ← Better (more minority samples)
Candidate (HistGradientBoosting): 0.82  ← Best (strong model)

Recall @ 80% Precision:
Baseline:    45%  ← Misses 55% of churners
Class Weight: 60%
SMOTE:       65%
Candidate:   75%  ← Best for business
```

### When to Use Each Strategy

| Strategy | Use When | Avoid When |
|----------|----------|------------|
| **Class Weights** | Simple first step, any imbalance ratio | Severe imbalance (>100:1) |
| **SMOTE** | Moderate imbalance (5:1 to 50:1), enough minority samples | Very small minority class (<100 samples) |
| **Undersampling** | Huge dataset, training time critical | Small dataset (information loss) |
| **Advanced Model** | Budget for complex model, other strategies not enough | Interpretability critical |

---

## Hands-On Exercise

### Exercise 1: Train Baseline (No Imbalance Handling)

```bash
# Train baseline (LogisticRegression, no weights)
python -m churn_mlops.training.train_baseline --imbalance-strategy none

# Check metrics
cat artifacts/metrics/baseline_*.json | grep pr_auc
```

### Exercise 2: Train with Class Weights

```bash
# Train with class_weight='balanced'
python -m churn_mlops.training.train_baseline --imbalance-strategy class_weight

# Compare metrics
python -c "
import json
from pathlib import Path

metrics_files = sorted(Path('artifacts/metrics').glob('baseline_*.json'))

for path in metrics_files:
    with open(path) as f:
        data = json.load(f)
    strategy = 'class_weight' if 'balanced' in str(path) else 'none'
    pr_auc = data['metrics']['pr_auc']
    recall = data['metrics']['classification_report']['1']['recall']
    print(f'{strategy:15} PR-AUC: {pr_auc:.4f}, Recall: {recall:.2%}')
"
```

### Exercise 3: Train Candidate Model

```bash
# Train HistGradientBoosting
python -m churn_mlops.training.train_candidate

# Compare all models
ls -lh artifacts/models/
ls -lh artifacts/metrics/
```

### Exercise 4: Implement SMOTE Pipeline

```python
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline as ImbPipeline
from sklearn.linear_model import LogisticRegression
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.impute import SimpleImputer
import pandas as pd

# Load training data
df = pd.read_csv('data/features/training_dataset.csv')
train_df = df.iloc[:int(len(df)*0.7)]

X_train = train_df.drop(columns=['churn_label', 'user_id', 'as_of_date', 'signup_date'])
y_train = train_df['churn_label']

# Separate columns
cat_cols = [c for c in X_train.columns if X_train[c].dtype == 'object']
num_cols = [c for c in X_train.columns if X_train[c].dtype != 'object']

# Preprocessor
preprocessor = ColumnTransformer([
    ('cat', Pipeline([
        ('imputer', SimpleImputer(strategy='constant', fill_value='missing')),
        ('onehot', OneHotEncoder(handle_unknown='ignore'))
    ]), cat_cols),
    ('num', Pipeline([
        ('imputer', SimpleImputer(strategy='constant', fill_value=0)),
        ('scaler', StandardScaler())
    ]), num_cols)
])

# Pipeline with SMOTE
pipeline = ImbPipeline([
    ('preprocess', preprocessor),
    ('smote', SMOTE(sampling_strategy=0.5, random_state=42)),
    ('model', LogisticRegression(max_iter=1000))
])

# Train
pipeline.fit(X_train, y_train)

print("✅ SMOTE pipeline trained!")

# Check resampling effect
# Note: Can't access intermediate SMOTE output easily
# But model should perform better on minority class
```

### Exercise 5: Visualize Class Distribution

```python
import pandas as pd
import matplotlib.pyplot as plt
from imblearn.over_sampling import SMOTE

# Load data
df = pd.read_csv('data/features/training_dataset.csv')
y = df['churn_label']

# Original distribution
print("Original distribution:")
print(y.value_counts())
print(f"Imbalance ratio: {(y==0).sum()/(y==1).sum():.1f}:1")

# Apply SMOTE
X = df.drop(columns=['churn_label', 'user_id', 'as_of_date', 'signup_date']).fillna(0)
smote = SMOTE(sampling_strategy=0.5, random_state=42)
X_resampled, y_resampled = smote.fit_resample(X, y)

print(f"\nAfter SMOTE (sampling_strategy=0.5):")
print(pd.Series(y_resampled).value_counts())
print(f"Imbalance ratio: {(y_resampled==0).sum()/(y_resampled==1).sum():.1f}:1")

# Plot
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))

pd.Series(y).value_counts().plot(kind='bar', ax=ax1, color=['green', 'red'])
ax1.set_title('Original Distribution')
ax1.set_xlabel('Class')
ax1.set_ylabel('Count')
ax1.set_xticklabels(['Active (0)', 'Churned (1)'], rotation=0)

pd.Series(y_resampled).value_counts().plot(kind='bar', ax=ax2, color=['green', 'red'])
ax2.set_title('After SMOTE')
ax2.set_xlabel('Class')
ax2.set_ylabel('Count')
ax2.set_xticklabels(['Active (0)', 'Churned (1)'], rotation=0)

plt.tight_layout()
plt.savefig('smote_distribution.png')
print("Saved plot to smote_distribution.png")
```

---

## Assessment Questions

### Question 1: Multiple Choice
Why does class imbalance hurt model performance?

A) Makes training slower  
B) **Models optimize for overall accuracy, biased toward majority** ✅  
C) Increases memory usage  
D) Causes overfitting  

**Explanation**: Models minimize overall loss, so they focus on majority class (more samples = more loss contribution).

---

### Question 2: True/False
**Statement**: SMOTE creates exact duplicates of minority samples.

**Answer**: False ❌  
**Explanation**: SMOTE creates **synthetic** samples by interpolating between existing minority samples (not duplicates).

---

### Question 3: Short Answer
What's the main advantage of class weights over SMOTE?

**Answer**:
- Class weights: Simple (one parameter), fast (no resampling), no data modification
- SMOTE: More complex, slower (generates new samples), modifies training set
- Use class weights as first step; try SMOTE if insufficient

---

### Question 4: Code Analysis
What's wrong with this code?

```python
X_resampled, y_resampled = SMOTE().fit_resample(X_train, y_train)
X_train_scaled = scaler.fit_transform(X_resampled)
model.fit(X_train_scaled, y_resampled)
```

**Answer**:
- SMOTE should be applied **after** preprocessing (scaling), not before
- Correct order: Scale → SMOTE → Model
- Reason: SMOTE uses distances (needs scaled features)
- Use ImbPipeline to ensure correct order

---

### Question 5: Design Challenge
Your dataset has 10,000 class 0 and 10 class 1 (1000:1 imbalance). Which strategy?

**Answer**:
- **Class weights**: Essential (1000× weight for class 1)
- **SMOTE**: Risky (only 10 samples to synthesize from → unrealistic synthetics)
- **Better approach**: 
  1. Collect more minority samples (if possible)
  2. Use anomaly detection (treat minority as outliers)
  3. Ensemble with balanced subsets
- **Undersampling**: Maybe (subsample majority, but lose info)

---

## Key Takeaways

### ✅ What You Learned

1. **Class Imbalance Problem**
   - Majority class bias
   - Misleading accuracy
   - Poor minority class performance

2. **Class Weights**
   - Simple, fast, no data modification
   - `class_weight='balanced'` in sklearn
   - Good first step

3. **SMOTE (Oversampling)**
   - Synthetic minority samples (interpolation)
   - Adds information (not duplicates)
   - Use ImbPipeline to prevent leakage

4. **Undersampling**
   - Remove majority samples
   - Fast training (smaller dataset)
   - Information loss (not recommended for small datasets)

5. **Candidate Model**
   - HistGradientBoosting (stronger than LogisticRegression)
   - Handles imbalance better
   - Faster, robust, native categorical support

---

## Next Steps

You've completed Module 3: Machine Learning Pipeline! 🎉

**Next Module**: [Module 04: Containerization](../module-04-containerization/)

In the next module, we'll:
- Build Docker images
- Create multi-stage Dockerfiles
- Implement container best practices
- Deploy models in containers

---

## Additional Resources

### Imbalanced Learning:
- [imbalanced-learn Documentation](https://imbalanced-learn.org/)
- [SMOTE Paper (Original)](https://arxiv.org/abs/1106.1813)
- [Class Imbalance Guide](https://machinelearningmastery.com/tactics-to-combat-imbalanced-classes-in-your-machine-learning-dataset/)

### HistGradientBoosting:
- [Sklearn HistGradientBoostingClassifier](https://scikit-learn.org/stable/modules/generated/sklearn.ensemble.HistGradientBoostingClassifier.html)
- [LightGBM (similar algorithm)](https://lightgbm.readthedocs.io/)

---

**🎉 Congratulations!** You've completed Module 3!

**Module 3 Summary**:
- ✅ Section 08: Building Training Labels
- ✅ Section 09: Training Pipeline & Baseline Model
- ✅ Section 10: Model Evaluation & Metrics
- ✅ Section 11: Handling Class Imbalance

**Total Progress**: 10/34 sections complete (29%)

Next: **[Module 04: Containerization](../module-04-containerization/)** →
