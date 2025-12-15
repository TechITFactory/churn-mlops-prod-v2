# Section 09: Training Pipeline & Baseline Model

**Duration**: 2.5 hours  
**Level**: Intermediate to Advanced  
**Prerequisites**: Section 08

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Build end-to-end training pipelines
- ✅ Implement temporal train/test splits
- ✅ Create preprocessing pipelines (sklearn)
- ✅ Train baseline models (Logistic Regression)
- ✅ Understand pipeline composition
- ✅ Handle mixed data types (categorical + numeric)
- ✅ Save and version models

---

## 📚 Table of Contents

1. [Training Pipeline Architecture](#training-pipeline-architecture)
2. [Temporal Train/Test Split](#temporal-train-test-split)
3. [Code Walkthrough: train_baseline.py](#code-walkthrough)
4. [Preprocessing Pipelines](#preprocessing-pipelines)
5. [Baseline Model: Logistic Regression](#baseline-model-logistic-regression)
6. [Model Serialization](#model-serialization)
7. [Hands-On Exercise](#hands-on-exercise)
8. [Assessment Questions](#assessment-questions)

---

## Training Pipeline Architecture

### End-to-End ML Pipeline

```
┌─────────────────────────────────────────────────────────┐
│                 DATA PREPARATION                        │
├─────────────────────────────────────────────────────────┤
│  Raw Data → Validation → Processing → Features         │
│  (Sections 04-07)                                       │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────────┐
│                 LABEL CREATION                          │
├─────────────────────────────────────────────────────────┤
│  user_daily.csv + churn_window → labels_daily.csv      │
│  (Section 08)                                           │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────────┐
│           TRAINING DATASET ASSEMBLY                     │
├─────────────────────────────────────────────────────────┤
│  features + labels → training_dataset.csv               │
│  (Join on user_id, as_of_date)                          │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────────┐
│             TEMPORAL TRAIN/TEST SPLIT                   │
├─────────────────────────────────────────────────────────┤
│  Sort by date → Train (70%) | Test (30%)               │
│  (Time-aware, no random shuffle!)                       │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────────┐
│            PREPROCESSING PIPELINE                       │
├─────────────────────────────────────────────────────────┤
│  Categorical: Impute + OneHotEncode                     │
│  Numeric: Impute + StandardScale                        │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────────┐
│              MODEL TRAINING                             │
├─────────────────────────────────────────────────────────┤
│  Logistic Regression (baseline)                         │
│  Fit on train set                                       │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────────┐
│              MODEL EVALUATION                           │
├─────────────────────────────────────────────────────────┤
│  Predict on test set                                    │
│  Compute metrics (PR-AUC, ROC-AUC, etc.)                │
│  (Section 10)                                           │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────────┐
│            MODEL SERIALIZATION                          │
├─────────────────────────────────────────────────────────┤
│  Save model: baseline_YYYYMMDD_HHMMSS.pkl              │
│  Save metrics: baseline_YYYYMMDD_HHMMSS_metrics.json   │
└─────────────────────────────────────────────────────────┘
```

### Why Start with Baseline?

**Baseline Model** = Simple, interpretable model (Logistic Regression)

**Benefits**:
- ✅ Fast to train (seconds, not hours)
- ✅ Interpretable (coefficient = feature importance)
- ✅ Stable (no overfitting from complex models)
- ✅ **Benchmark**: Compare fancy models against this

**Philosophy**: "Beat the baseline first, then optimize"

---

## Temporal Train/Test Split

### Why NOT Random Split?

#### ❌ Random Split (WRONG for time-series)

```python
from sklearn.model_selection import train_test_split

# WRONG! Shuffles data randomly
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
```

**Problem**: Test data contains rows from BEFORE train data!

```
Timeline:
────────────────────────────────────────────→ time
  Jan    Feb    Mar    Apr    May    Jun

Random split:
Train: [Jan, Mar, May, Jun]  ← Includes future!
Test:  [Feb, Apr]            ← Includes past!

Problem: Model sees "future" data during training (leakage!)
```

#### ✅ Temporal Split (CORRECT)

```python
# Sort by date first
df = df.sort_values('as_of_date')

# Split by date cutoff (e.g., 70/30)
cutoff_idx = int(len(df) * 0.7)
train = df.iloc[:cutoff_idx]
test = df.iloc[cutoff_idx:]
```

**Correct Timeline**:
```
────────────────────────────────────────────→ time
  Jan    Feb    Mar    Apr    May    Jun
  ↑                         ↑
  Train (Jan-Apr)           Test (May-Jun)

Train: [Jan, Feb, Mar, Apr]  ← Only past
Test:  [May, Jun]            ← Only future

Model trained on past, tested on future (realistic!)
```

### Date-Based Split Implementation

```python
def _time_split(df: pd.DataFrame, test_size: float) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """
    Split by date: first (1-test_size) for train, last test_size for test.
    
    Example:
    Dates: [2025-01-01, ..., 2025-06-30]  (180 days)
    test_size: 0.3 (30%)
    
    Split at: 180 * 0.7 = day 126
    Train: Days 1-126 (Jan 1 to May 6)
    Test: Days 127-180 (May 7 to Jun 30)
    """
    d = df.copy()
    d["as_of_date"] = pd.to_datetime(d["as_of_date"], errors="coerce")
    d = d.dropna(subset=["as_of_date"]).reset_index(drop=True)
    
    # Get unique dates (sorted)
    dates = sorted(d["as_of_date"].dt.date.unique().tolist())
    
    # Handle edge case: very few dates
    if len(dates) < 5:
        # Fall back to row-based split (still temporal, not random!)
        d = d.sort_values("as_of_date")
        cutoff_idx = int(len(d) * (1 - test_size))
        return d.iloc[:cutoff_idx].copy(), d.iloc[cutoff_idx:].copy()
    
    # Split dates
    cut_at = int(len(dates) * (1 - test_size))
    cut_at = max(1, min(cut_at, len(dates) - 1))  # Ensure valid index
    cutoff_date = dates[cut_at - 1]
    
    # Filter dataframe
    train_df = d[d["as_of_date"].dt.date <= cutoff_date].copy()
    test_df = d[d["as_of_date"].dt.date > cutoff_date].copy()
    
    return train_df, test_df
```

**Key Points**:
- Split by **dates**, not rows (more realistic)
- Handles edge cases (very few dates)
- No shuffling! Preserves temporal order

---

## Code Walkthrough

### File: `src/churn_mlops/training/train_baseline.py`

#### Configuration

```python
@dataclass
class TrainSettings:
    features_dir: str           # Where training_dataset.csv lives
    models_dir: str             # Where to save model
    metrics_dir: str            # Where to save metrics
    test_size: float            # Test set fraction (0.3 = 30%)
    random_state: int           # For reproducibility
    imbalance_strategy: str     # 'balanced' or None (Section 11)
```

#### Step 1: Load Training Dataset

```python
def _read_training_dataset(features_dir: str) -> pd.DataFrame:
    """Load training_dataset.csv (features + labels joined)"""
    path = Path(features_dir) / "training_dataset.csv"
    if not path.exists():
        raise FileNotFoundError(f"Missing required file: {path}")
    return pd.read_csv(path)
```

**Note**: `training_dataset.csv` is created by joining `user_features_daily.csv` + `labels_daily.csv` on `(user_id, as_of_date)`.

#### Step 2: Select Features and Label

```python
def _select_feature_columns(df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.Series]:
    """
    Split into X (features) and y (label).
    
    Drop columns that shouldn't be features:
    - churn_label (target)
    - user_id (identifier, not predictive)
    - as_of_date (temporal info, handled by split)
    - signup_date (already captured in days_since_signup feature)
    """
    if "churn_label" not in df.columns:
        raise ValueError("training_dataset must contain 'churn_label'")
    
    y = pd.to_numeric(df["churn_label"], errors="coerce").fillna(0).astype(int)
    
    # Columns to exclude from features
    drop_cols = {
        "churn_label",   # Target (don't use as feature!)
        "user_id",       # Identifier (not generalizable)
        "as_of_date",    # Date (temporal split handles this)
        "signup_date",   # Date (feature: days_since_signup captures this)
    }
    
    X = df.drop(columns=[c for c in drop_cols if c in df.columns], errors="ignore")
    
    return X, y
```

**Why drop these columns?**
- **churn_label**: Target variable (using it as feature = cheating!)
- **user_id**: Overfits to specific users (not generalizable)
- **as_of_date**: Temporal info (captured by split + time features)
- **signup_date**: Already captured by `days_since_signup` feature

#### Step 3: Infer Column Types

```python
def _infer_column_types(X: pd.DataFrame) -> Tuple[List[str], List[str]]:
    """
    Separate categorical and numeric columns.
    
    Categorical: plan, country, ...
    Numeric: total_logins_7d, days_since_last_login, ...
    """
    cat_cols = []
    num_cols = []
    
    for col in X.columns:
        if pd.api.types.is_numeric_dtype(X[col]):
            num_cols.append(col)
        else:
            cat_cols.append(col)
    
    return cat_cols, num_cols
```

**Why separate?**
- Different preprocessing for each type
- Categorical: OneHotEncode (country='US' → [0,0,1,0])
- Numeric: StandardScale (mean=0, std=1)

#### Step 4: Build Preprocessing + Model Pipeline

```python
def _build_pipeline(cat_cols: List[str], num_cols: List[str], class_weight) -> Pipeline:
    """
    Create sklearn Pipeline:
    1. Preprocess (impute + transform)
    2. Model (LogisticRegression)
    """
    
    # Categorical preprocessing
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
            ("scaler", StandardScaler(with_mean=True, with_std=True)),
        ]
    )
    
    # Combine preprocessing
    pre = ColumnTransformer(
        transformers=[
            ("cat", categorical, cat_cols),
            ("num", numeric, num_cols),
        ],
        remainder="drop",  # Drop any columns not specified
    )
    
    # Model
    clf = LogisticRegression(
        max_iter=2000,              # Ensure convergence
        class_weight=class_weight,  # Handle imbalance (Section 11)
        solver="lbfgs",             # Fast solver
    )
    
    # Full pipeline
    return Pipeline(steps=[("preprocess", pre), ("model", clf)])
```

**Pipeline Benefits**:
- ✅ Atomic unit (preprocessing + model in one object)
- ✅ Prevents leakage (scaler fitted only on train, applied to test)
- ✅ Production-ready (same preprocessing at inference)

**Visual**:
```
Input:
plan='paid', total_logins_7d=25, country='US'

Pipeline:
├─ Preprocess
│  ├─ Categorical: plan='paid', country='US' → [0,1,0,0,1,0]
│  └─ Numeric: total_logins_7d=25 → (25-15)/10 = 1.0 (standardized)
└─ Model
   └─ LogisticRegression: [0,1,0,0,1,0,1.0,...] → P(churn)=0.23

Output: 0.23 (23% churn probability)
```

#### Step 5: Train Model

```python
def train_baseline(settings: TrainSettings):
    """Main training function"""
    
    # 1. Load data
    df = _read_training_dataset(settings.features_dir)
    
    # 2. Temporal split
    train_df, test_df = _time_split(df, settings.test_size)
    
    # 3. Select features and label
    X_train, y_train = _select_feature_columns(train_df)
    X_test, y_test = _select_feature_columns(test_df)
    
    # 4. Infer column types
    cat_cols, num_cols = _infer_column_types(X_train)
    
    # 5. Build pipeline
    class_weight = "balanced" if settings.imbalance_strategy == "balanced" else None
    model = _build_pipeline(cat_cols, num_cols, class_weight)
    
    # 6. Train!
    model.fit(X_train, y_train)
    
    # 7. Evaluate (Section 10)
    metrics = _evaluate(model, X_test, y_test)
    
    # 8. Save model and metrics
    model_path, metrics_path = _save_artifacts(model, metrics, settings)
    
    return model_path, metrics_path, metrics
```

---

## Preprocessing Pipelines

### Why Preprocessing?

**Raw Data Issues**:
- Missing values (NaN)
- Different scales (age: 20-80, income: 20k-200k)
- Categorical text (country='US', plan='paid')

**Models require**:
- No missing values
- Numeric input only
- Similar scales (for convergence)

### Categorical Pipeline

```python
categorical = Pipeline(
    steps=[
        ("imputer", SimpleImputer(strategy="constant", fill_value="missing")),
        ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
    ]
)
```

**Step 1: Impute Missing Values**
```
country: ['US', 'UK', NaN, 'IN']
         ↓
country: ['US', 'UK', 'missing', 'IN']
```

**Step 2: OneHotEncode**
```
country: ['US', 'UK', 'missing', 'IN']
         ↓
country_US: [1, 0, 0, 0]
country_UK: [0, 1, 0, 0]
country_missing: [0, 0, 1, 0]
country_IN: [0, 0, 0, 1]
```

**Why `handle_unknown='ignore'`?**
- Training: countries = {US, UK, IN}
- Production: New country = 'CA' (unseen!)
- Without `handle_unknown`: Crash!
- With `handle_unknown='ignore'`: Encode as all zeros [0,0,0]

### Numeric Pipeline

```python
numeric = Pipeline(
    steps=[
        ("imputer", SimpleImputer(strategy="constant", fill_value=0.0)),
        ("scaler", StandardScaler(with_mean=True, with_std=True)),
    ]
)
```

**Step 1: Impute Missing Values**
```
total_logins_7d: [5, 10, NaN, 15]
                 ↓
total_logins_7d: [5, 10, 0, 15]  (fill with 0)
```

**Step 2: StandardScale**
```
Formula: z = (x - mean) / std

total_logins_7d: [5, 10, 0, 15]
mean = 7.5, std = 6.24
                 ↓
scaled: [-0.4, 0.4, -1.2, 1.2]
```

**Why StandardScale?**
- Logistic Regression converges faster with scaled features
- Prevents features with large values from dominating

### ColumnTransformer

```python
pre = ColumnTransformer(
    transformers=[
        ("cat", categorical, cat_cols),
        ("num", numeric, num_cols),
    ],
    remainder="drop",
)
```

**Combines pipelines**:
```
Input DataFrame:
user_id | plan | total_logins_7d | country
--------|------|-----------------|--------
1       | paid | 25              | US
2       | free | 5               | UK

ColumnTransformer:
├─ Categorical: [plan, country]
│  └─ Output: [0,1, 1,0] (one-hot encoded)
└─ Numeric: [total_logins_7d]
   └─ Output: [1.5] (standardized)

Final: [0,1, 1,0, 1.5]
```

---

## Baseline Model: Logistic Regression

### Why Logistic Regression?

| Property | Value |
|----------|-------|
| **Training Speed** | Fast (seconds) |
| **Interpretability** | High (coefficients = feature importance) |
| **Overfitting Risk** | Low (regularized) |
| **Production** | Lightweight (small model size) |
| **Baseline Quality** | Good starting point |

### Logistic Regression Intuition

**Formula**:
```
P(churn=1) = 1 / (1 + e^(-z))

where z = β₀ + β₁·x₁ + β₂·x₂ + ... + βₙ·xₙ

β₀ = intercept
β₁, β₂, ..., βₙ = coefficients (feature weights)
x₁, x₂, ..., xₙ = features
```

**Example**:
```python
# Trained coefficients:
β₀ = -1.5
β₁ = 0.8  (logins_7d)
β₂ = -0.5 (days_since_last_login)

# User features:
logins_7d = 2 (scaled: -1.0)
days_since_last_login = 10 (scaled: 1.5)

# Compute:
z = -1.5 + (0.8 × -1.0) + (-0.5 × 1.5)
z = -1.5 - 0.8 - 0.75 = -3.05

P(churn=1) = 1 / (1 + e^3.05) = 0.045 (4.5% churn probability)
```

**Interpretation**:
- **Positive coefficient** (β₁=0.8): Higher logins → Higher churn (unexpected!)
- **Negative coefficient** (β₂=-0.5): Higher recency → Lower churn (expected!)

### Hyperparameters

```python
LogisticRegression(
    max_iter=2000,           # Max iterations for convergence
    class_weight='balanced', # Handle imbalance (Section 11)
    solver='lbfgs',          # Optimization algorithm
)
```

**max_iter**:
- Default: 100 (may not converge)
- Our setting: 2000 (ensure convergence)
- If model warns "not converged", increase this

**class_weight='balanced'**:
- Automatically adjust for class imbalance
- Equivalent to: `class_weight={0: 1.0, 1: n_samples/(n_positive*2)}`
- Section 11 covers this in detail

**solver='lbfgs'**:
- Fast for small/medium datasets
- Alternatives: 'liblinear' (very large), 'saga' (L1 regularization)

---

## Model Serialization

### Why Save Models?

**Without saving**:
- Train model every time you need prediction → Slow!
- Different model each run → Not reproducible!

**With saving**:
- ✅ Train once, use many times
- ✅ Version models (baseline_v1, baseline_v2, ...)
- ✅ Deploy to production
- ✅ Reproduce results months later

### Joblib vs Pickle

```python
# Option 1: joblib (recommended for sklearn)
import joblib
joblib.dump(model, 'model.pkl')
loaded_model = joblib.load('model.pkl')

# Option 2: pickle (standard Python)
import pickle
with open('model.pkl', 'wb') as f:
    pickle.dump(model, f)
```

**Why joblib?**
- Efficient for NumPy arrays (sklearn uses these internally)
- Better compression
- Recommended by sklearn docs

### Artifact Naming Convention

```python
# Timestamped artifacts (reproducibility)
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
model_file = f"baseline_{timestamp}.pkl"
metrics_file = f"baseline_{timestamp}_metrics.json"

# Example:
# baseline_20250115_143022.pkl
# baseline_20250115_143022_metrics.json
```

**Benefits**:
- Unique filenames (no overwrites)
- Sortable by time
- Easy to find latest model

### Saving Model + Metadata

```python
# Save model
model_path = Path(models_dir) / model_file
joblib.dump({
    "model": model,
    "feature_names": X_train.columns.tolist(),
    "created_at": timestamp,
}, model_path)

# Save metrics
metrics_path = Path(metrics_dir) / metrics_file
with open(metrics_path, 'w') as f:
    json.dump({
        "model_type": "logistic_regression",
        "train_rows": len(train_df),
        "test_rows": len(test_df),
        "churn_rate_train": float(y_train.mean()),
        "metrics": metrics,
    }, f, indent=2)
```

**Why save metadata?**
- Know which features model expects
- Track training data size
- Audit training details

---

## Hands-On Exercise

### Exercise 1: Train Baseline Model

```bash
# Ensure training_dataset.csv exists
# (Created by joining features + labels)
python -m churn_mlops.training.build_training_set

# Train baseline model
python -m churn_mlops.training.train_baseline

# Check outputs
ls artifacts/models/baseline_*.pkl
ls artifacts/metrics/baseline_*_metrics.json
```

### Exercise 2: Inspect Model Artifacts

```python
import joblib
import json
from pathlib import Path

# Load latest model
model_files = sorted(Path('artifacts/models').glob('baseline_*.pkl'))
latest_model_path = model_files[-1]

artifact = joblib.load(latest_model_path)
model = artifact['model']
feature_names = artifact['feature_names']

print(f"Model type: {type(model)}")
print(f"Number of features: {len(feature_names)}")
print(f"Features: {feature_names[:5]}...")  # First 5

# Load metrics
metrics_file = str(latest_model_path).replace('.pkl', '_metrics.json')
with open(metrics_file) as f:
    metrics = json.load(f)

print(f"Train rows: {metrics['train_rows']}")
print(f"Test rows: {metrics['test_rows']}")
print(f"Churn rate (train): {metrics['churn_rate_train']:.2%}")
```

### Exercise 3: Manual Prediction

```python
import pandas as pd
import joblib

# Load model
artifact = joblib.load('artifacts/models/baseline_20250115_143022.pkl')
model = artifact['model']

# Create test input (must match training features!)
test_input = pd.DataFrame({
    'plan': ['paid'],
    'country': ['US'],
    'total_logins_7d': [25],
    'total_logins_14d': [45],
    'total_logins_30d': [80],
    'days_since_last_login': [0],
    'total_watch_minutes_30d': [500],
    # ... (include ALL features from training)
})

# Predict
churn_prob = model.predict_proba(test_input)[:, 1]
print(f"Churn Probability: {churn_prob[0]:.2%}")
```

### Exercise 4: Compare Temporal vs Random Split

**Task**: Show that random split causes data leakage

```python
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score

# Load data
df = pd.read_csv('data/features/training_dataset.csv')
X = df.drop(columns=['churn_label', 'user_id', 'as_of_date', 'signup_date'])
y = df['churn_label']

# Method 1: Random split (WRONG!)
X_train_rand, X_test_rand, y_train_rand, y_test_rand = train_test_split(
    X, y, test_size=0.3, random_state=42
)
model_rand = LogisticRegression(max_iter=1000)
model_rand.fit(X_train_rand.fillna(0), y_train_rand)
auc_rand = roc_auc_score(y_test_rand, model_rand.predict_proba(X_test_rand.fillna(0))[:, 1])

# Method 2: Temporal split (CORRECT!)
df = df.sort_values('as_of_date')
cutoff = int(len(df) * 0.7)
train_df = df.iloc[:cutoff]
test_df = df.iloc[cutoff:]

X_train_temp = train_df.drop(columns=['churn_label', 'user_id', 'as_of_date', 'signup_date'])
y_train_temp = train_df['churn_label']
X_test_temp = test_df.drop(columns=['churn_label', 'user_id', 'as_of_date', 'signup_date'])
y_test_temp = test_df['churn_label']

model_temp = LogisticRegression(max_iter=1000)
model_temp.fit(X_train_temp.fillna(0), y_train_temp)
auc_temp = roc_auc_score(y_test_temp, model_temp.predict_proba(X_test_temp.fillna(0))[:, 1])

print(f"Random Split AUC: {auc_rand:.4f}")
print(f"Temporal Split AUC: {auc_temp:.4f}")
print(f"Difference: {auc_rand - auc_temp:.4f}")
print("\nRandom split AUC is artificially high due to leakage!")
```

### Exercise 5: Feature Importance from Coefficients

```python
import joblib
import pandas as pd
import matplotlib.pyplot as plt

# Load model
artifact = joblib.load('artifacts/models/baseline_20250115_143022.pkl')
model = artifact['model']

# Extract coefficients
# Note: model is Pipeline, actual LogisticRegression is final step
lr = model.named_steps['model']
coefficients = lr.coef_[0]

# Get feature names (after one-hot encoding)
feature_names = model.named_steps['preprocess'].get_feature_names_out()

# Create importance dataframe
importance_df = pd.DataFrame({
    'feature': feature_names,
    'coefficient': coefficients,
    'abs_coefficient': abs(coefficients)
}).sort_values('abs_coefficient', ascending=False)

# Plot top 20
importance_df.head(20).plot(x='feature', y='coefficient', kind='barh', figsize=(10, 8))
plt.title('Top 20 Feature Importances (Logistic Regression Coefficients)')
plt.xlabel('Coefficient')
plt.savefig('feature_coefficients.png')

print(importance_df.head(20))
```

---

## Assessment Questions

### Question 1: Multiple Choice
Why do we use temporal split instead of random split for time-series data?

A) Random split is slower  
B) **Temporal split prevents data leakage** ✅  
C) Temporal split gives better accuracy  
D) Random split doesn't work with pandas  

**Explanation**: Random split mixes past and future data, causing leakage. Temporal split ensures train < test (time-wise).

---

### Question 2: True/False
**Statement**: We should include `user_id` as a feature for better predictions.

**Answer**: False ❌  
**Explanation**: `user_id` overfits to training users, won't generalize to new users. It's an identifier, not a predictive feature.

---

### Question 3: Short Answer
What is the purpose of `ColumnTransformer` in the pipeline?

**Answer**:
- Apply different preprocessing to different column types
- Categorical: Impute + OneHotEncode
- Numeric: Impute + StandardScale
- Combines both into single transformation step

---

### Question 4: Code Analysis
What does this code do?

```python
categorical = Pipeline([
    ("imputer", SimpleImputer(strategy="constant", fill_value="missing")),
    ("onehot", OneHotEncoder(handle_unknown="ignore")),
])
```

**Answer**:
- Step 1: Fill missing categorical values with "missing" string
- Step 2: One-hot encode (country='US' → [0,0,1,0])
- `handle_unknown='ignore'`: If production sees new category, encode as all zeros (prevents crash)

---

### Question 5: Design Challenge
Your model fails with "Feature mismatch: expected 50 features, got 48". What's wrong?

**Answer**:
Possible causes:
1. **Missing features**: Test data missing 2 columns from training
2. **Different one-hot encoding**: New categorical value in test creates extra column
3. **Column order**: Features in different order

Solution:
```python
# Save feature names during training
artifact = {
    'model': model,
    'feature_names': X_train.columns.tolist()
}

# At inference, reindex to match training columns
X_test = X_test.reindex(columns=artifact['feature_names'], fill_value=0)
```

---

## Key Takeaways

### ✅ What You Learned

1. **Training Pipeline Architecture**
   - Data → Labels → Training Set → Split → Preprocess → Train → Evaluate → Save
   - End-to-end reproducible workflow

2. **Temporal Split**
   - Split by date, not random
   - Train on past, test on future
   - Prevents data leakage

3. **Preprocessing Pipeline**
   - Categorical: Impute → OneHotEncode
   - Numeric: Impute → StandardScale
   - ColumnTransformer combines both

4. **Baseline Model**
   - Logistic Regression (simple, fast, interpretable)
   - class_weight='balanced' for imbalance
   - Good benchmark for comparison

5. **Model Serialization**
   - Save with joblib (efficient for sklearn)
   - Timestamped filenames (versioning)
   - Include metadata (feature names, training info)

---

## Next Steps

You now have a trained baseline model!

**Next Section**: [Section 10: Model Evaluation & Metrics](./section-10-model-evaluation.md)

In the next section, we'll:
- Compute evaluation metrics (PR-AUC, ROC-AUC)
- Understand precision vs recall tradeoff
- Visualize model performance
- Compare models objectively

---

## Additional Resources

### Sklearn Pipelines:
- [Sklearn Pipeline Tutorial](https://scikit-learn.org/stable/modules/compose.html)
- [ColumnTransformer Guide](https://scikit-learn.org/stable/modules/generated/sklearn.compose.ColumnTransformer.html)

### Logistic Regression:
- [Logistic Regression (StatQuest)](https://www.youtube.com/watch?v=yIYKR4sgzI8)
- [Sklearn LogisticRegression](https://scikit-learn.org/stable/modules/generated/sklearn.linear_model.LogisticRegression.html)

### Time-Series ML:
- [Time Series Cross-Validation](https://scikit-learn.org/stable/modules/cross_validation.html#time-series-split)
- [Temporal Data Leakage](https://machinelearningmastery.com/data-leakage-machine-learning/)

---

**🎉 Congratulations!** You've completed Section 09!

Next: **[Section 10: Model Evaluation & Metrics](./section-10-model-evaluation.md)** →
