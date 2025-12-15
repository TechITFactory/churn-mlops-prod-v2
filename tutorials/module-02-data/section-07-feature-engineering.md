# Section 07: Feature Engineering Deep Dive

**Duration**: 3 hours  
**Level**: Advanced  
**Prerequisites**: Sections 04-06

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Master rolling window feature calculations
- ✅ Understand temporal feature engineering patterns
- ✅ Prevent label leakage in time-series ML
- ✅ Implement recency and frequency metrics
- ✅ Build behavioral signal features
- ✅ Design feature catalogs
- ✅ Optimize feature computation

---

## 📚 Table of Contents

1. [What is Feature Engineering?](#what-is-feature-engineering)
2. [The Label Leakage Problem](#the-label-leakage-problem)
3. [Code Walkthrough: build_features.py](#code-walkthrough)
4. [Rolling Window Features](#rolling-window-features)
5. [Recency Features](#recency-features)
6. [Frequency and Behavioral Signals](#frequency-and-behavioral-signals)
7. [Feature Engineering Best Practices](#feature-engineering-best-practices)
8. [Feature Catalog Design](#feature-catalog-design)
9. [Performance Optimization](#performance-optimization)
10. [Hands-On Exercise](#hands-on-exercise)
11. [Assessment Questions](#assessment-questions)

---

## What is Feature Engineering?

### Definition

> **Feature Engineering**: The process of transforming raw data into predictive signals (features) that ML models can learn from.

### Raw Data vs Features

```
Raw Data (not directly useful):
user_id | as_of_date | total_logins
--------|------------|-------------
1       | 2025-01-15 | 2
1       | 2025-01-16 | 0
1       | 2025-01-17 | 1

❓ Is user 1 engaged? Hard to tell from one day!

Features (predictive signals):
user_id | as_of_date | logins_7d | logins_30d | days_since_last_login
--------|------------|-----------|------------|----------------------
1       | 2025-01-17 | 8         | 25         | 0 (today)
2       | 2025-01-17 | 0         | 2          | 14 (2 weeks ago)

✅ User 1: Highly engaged (8 logins in 7d, active today)
✅ User 2: Churning (no activity in 7d, last seen 2 weeks ago)
```

### Why Features Matter More Than Models

**Common Misconception**: "Just get more data and use a fancier model!"

**Reality**:
```
Bad Features + Fancy Model (XGBoost, Neural Net) = Poor Performance
Good Features + Simple Model (Logistic Regression) = Great Performance
```

**Example**:
- Model A: 100 raw features → XGBoost → 65% accuracy
- Model B: 20 engineered features → Logistic Regression → 82% accuracy

**Takeaway**: Spend 80% of time on features, 20% on model tuning.

---

## The Label Leakage Problem

### What is Label Leakage?

> **Label Leakage**: When features contain information about the target that wouldn't be available at prediction time.

### Example of Leakage

#### ❌ WRONG (Leakage)
```python
# Training: Predict churn in next 30 days
# Feature: total_logins in next 30 days

user_id | as_of_date | logins_next_30d | churn_label
--------|------------|-----------------|-------------
1       | 2025-01-01 | 0               | 1 (churned)
2       | 2025-01-01 | 15              | 0 (active)

# Model learns: "If logins_next_30d = 0, predict churn"
# Training accuracy: 99% 🎉

# Production (prediction time):
# ❌ We don't know logins_next_30d! (It's in the future!)
```

#### ✅ CORRECT (No Leakage)
```python
# Feature: total_logins in PAST 30 days (before as_of_date)

user_id | as_of_date | logins_past_30d | churn_label
--------|------------|-----------------|-------------
1       | 2025-01-01 | 2               | 1 (churned)
2       | 2025-01-01 | 18              | 0 (active)

# Model learns: "If logins_past_30d < 5, likely to churn"
# Production: ✅ We know logins_past_30d (it's historical data)
```

### Time Cutoff Rule

**Golden Rule**: Features must use ONLY data from **before** `as_of_date`.

```
Timeline:
│────────────────────────────────│─────────────────────────│
    Historical Data               as_of_date         Future
       (can use)                 (prediction time)  (cannot use!)

Features ← Use this data
Label   → Use this data (e.g., "churned in next 30 days")
```

### Visual Example

```
User Timeline:
┌──────────────┬──────────────┬──────────────┐
│   Past 30d   │  as_of_date  │  Next 30d    │
├──────────────┼──────────────┼──────────────┤
│ 15 logins    │  2025-01-15  │  0 logins    │
│ 120 min      │      ↑       │  0 min       │
│ 3 courses    │  Prediction  │  0 courses   │
│              │    Time      │              │
└──────────────┴──────────────┴──────────────┘
       ✅                             ❌
   Use for                      Don't use
   features                     for features!
                                (Use for label)
```

---

## Code Walkthrough

### File: `src/churn_mlops/features/build_features.py`

#### Configuration: FeatureSettings

```python
@dataclass
class FeatureSettings:
    """Configuration for feature engineering"""
    input_path: str = "data/processed/user_daily.csv"
    output_path: str = "data/features/user_features_daily.csv"
    
    # Rolling window sizes (days)
    window_7d: int = 7
    window_14d: int = 14
    window_30d: int = 30
    
    # Feature toggles (for experimentation)
    include_rolling: bool = True
    include_recency: bool = True
    include_ratios: bool = True
```

#### Step 1: Rolling Window Features

```python
def _add_rolling_features(df: pd.DataFrame, settings: FeatureSettings) -> pd.DataFrame:
    """
    Calculate rolling window aggregations (7d, 14d, 30d)
    
    For each user, compute trailing sums/averages over past N days.
    
    CRITICAL: Uses `.shift(1)` to exclude current day (prevent leakage)
    
    Example:
    as_of_date: 2025-01-15
    Rolling 7d: Sum of [2025-01-08, ..., 2025-01-14] (NOT including 2025-01-15!)
    """
    df = df.sort_values(['user_id', 'as_of_date']).copy()
    
    # Metrics to aggregate
    rolling_metrics = [
        'total_logins',
        'total_watch_minutes',
        'total_quiz_attempts',
        'total_events',
        'distinct_courses',
    ]
    
    for metric in rolling_metrics:
        for window in [settings.window_7d, settings.window_14d, settings.window_30d]:
            # CRITICAL: .shift(1) excludes current day (as_of_date)
            # This prevents leakage: we only use data BEFORE as_of_date
            
            # Rolling sum (total in past N days)
            df[f'{metric}_{window}d'] = (
                df.groupby('user_id')[metric]
                .shift(1)  # Exclude today
                .rolling(window=window, min_periods=1)
                .sum()
                .reset_index(level=0, drop=True)
            )
            
            # Rolling mean (average per day in past N days)
            df[f'{metric}_{window}d_avg'] = (
                df.groupby('user_id')[metric]
                .shift(1)
                .rolling(window=window, min_periods=1)
                .mean()
                .reset_index(level=0, drop=True)
            )
    
    # Fill NaN with 0 (early days have no history)
    rolling_cols = [c for c in df.columns if any(f'_{w}d' in c for w in [7, 14, 30])]
    df[rolling_cols] = df[rolling_cols].fillna(0)
    
    return df
```

**Key Points**:
- **`.shift(1)`**: Critical for preventing leakage (excludes current day)
- **`min_periods=1`**: Allow calculations even if < window days available
- **`reset_index(level=0, drop=True)`**: Preserve original index after groupby

**Visual Example**:
```
User 1 Data:
Date       | logins | logins_7d (with shift) | logins_7d (WITHOUT shift - WRONG!)
-----------|--------|------------------------|----------------------------------
2025-01-01 | 2      | 0 (no history)         | 2 (includes today - LEAKAGE!)
2025-01-02 | 1      | 2 (only 01-01)         | 3 (01-01 + 01-02 - LEAKAGE!)
2025-01-03 | 0      | 3 (01-01 + 01-02)      | 3 (all 3 days - LEAKAGE!)
2025-01-04 | 1      | 3 (01-02 + 01-03)      | 4 (all 4 days - LEAKAGE!)
...
2025-01-10 | 2      | 4 (sum of 01-03 to 01-09, 7 days) | ...
```

#### Step 2: Recency Features

```python
def _add_days_since_last_activity(df: pd.DataFrame) -> pd.DataFrame:
    """
    Calculate days since last activity (recency metrics)
    
    Recency = How long since user last did X?
    - days_since_last_login
    - days_since_last_video
    - days_since_last_quiz
    
    Logic:
    1. Mark active days (where activity > 0)
    2. Forward-fill dates (carry forward last active date)
    3. Calculate days between as_of_date and last_active_date
    """
    df = df.sort_values(['user_id', 'as_of_date']).copy()
    
    # Days since last login
    # Step 1: Create date column where logins > 0, else NaN
    df['_last_login_date'] = df['as_of_date'].where(df['total_logins'] > 0)
    
    # Step 2: Forward-fill (carry forward last known date)
    df['_last_login_date'] = df.groupby('user_id')['_last_login_date'].ffill()
    
    # Step 3: Calculate days difference
    df['days_since_last_login'] = (
        pd.to_datetime(df['as_of_date']) - pd.to_datetime(df['_last_login_date'])
    ).dt.days
    
    # Same for video watching
    df['_last_video_date'] = df['as_of_date'].where(df['total_watch_minutes'] > 0)
    df['_last_video_date'] = df.groupby('user_id')['_last_video_date'].ffill()
    df['days_since_last_video'] = (
        pd.to_datetime(df['as_of_date']) - pd.to_datetime(df['_last_video_date'])
    ).dt.days
    
    # Same for quiz attempts
    df['_last_quiz_date'] = df['as_of_date'].where(df['total_quiz_attempts'] > 0)
    df['_last_quiz_date'] = df.groupby('user_id')['_last_quiz_date'].ffill()
    df['days_since_last_quiz'] = (
        pd.to_datetime(df['as_of_date']) - pd.to_datetime(df['_last_quiz_date'])
    ).dt.days
    
    # Fill NaN (user never did activity) with large value (e.g., 9999)
    df['days_since_last_login'] = df['days_since_last_login'].fillna(9999)
    df['days_since_last_video'] = df['days_since_last_video'].fillna(9999)
    df['days_since_last_quiz'] = df['days_since_last_quiz'].fillna(9999)
    
    # Drop temporary columns
    df = df.drop(columns=['_last_login_date', '_last_video_date', '_last_quiz_date'])
    
    return df
```

**Key Points**:
- **Forward-fill (`.ffill()`)**: Propagate last known date forward
- **Fill with 9999**: Represents "never did this activity" (large value so model learns it's bad)
- **Days difference**: Simple subtraction after datetime conversion

**Visual Example**:
```
User 1 Timeline:
Date       | logins | _last_login_date | days_since_last_login
-----------|--------|------------------|----------------------
2025-01-01 | 2      | 2025-01-01       | 0 (today)
2025-01-02 | 0      | 2025-01-01 (ffill)| 1 (1 day ago)
2025-01-03 | 0      | 2025-01-01 (ffill)| 2 (2 days ago)
2025-01-04 | 1      | 2025-01-04       | 0 (today)
2025-01-05 | 0      | 2025-01-04 (ffill)| 1 (1 day ago)
...
```

#### Step 3: Ratio and Behavioral Features

```python
def _add_ratio_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Calculate ratio-based features (rates, averages)
    
    Examples:
    - Average watch minutes per login
    - Payment failure rate (payment_fails / total_payments)
    - Course diversity (distinct_courses / total_events)
    """
    # Avoid division by zero
    df['avg_watch_per_login'] = df['total_watch_minutes_30d'] / df['total_logins_30d'].replace(0, 1)
    
    # Payment failure rate (requires payment events in data)
    # Note: Not in current user_daily schema, but shown as pattern
    # df['payment_fail_rate_30d'] = df['payment_fails_30d'] / (df['payment_fails_30d'] + df['payment_success_30d']).replace(0, 1)
    
    # Course diversity score
    df['course_diversity_30d'] = df['distinct_courses_30d'] / df['total_events_30d'].replace(0, 1)
    
    # Activity trend (compare 7d vs 30d)
    df['activity_trend'] = df['total_events_7d'] / df['total_events_30d'].replace(0, 1)
    # If activity_trend > 0.5: User is MORE active recently (good signal)
    # If activity_trend < 0.2: User is LESS active recently (churn signal!)
    
    return df
```

**Key Points**:
- **`.replace(0, 1)`**: Prevent division by zero (instead of NaN)
- **Ratios**: Normalize raw counts (compare users with different activity levels)
- **Trends**: Compare short-term vs long-term (detect changes in behavior)

#### Step 4: Main Pipeline

```python
def build_features(settings: FeatureSettings) -> pd.DataFrame:
    """
    Main feature engineering pipeline
    
    Input: user_daily.csv (from Section 06)
    Output: user_features_daily.csv (ready for training)
    
    Steps:
    1. Load user_daily
    2. Add rolling features (7d, 14d, 30d)
    3. Add recency features (days_since_last_X)
    4. Add ratio features
    5. Add temporal features (day_of_week, days_since_signup)
    6. Sort and save
    """
    # Load processed data
    df = pd.read_csv(settings.input_path)
    df['as_of_date'] = pd.to_datetime(df['as_of_date'])
    df['signup_date'] = pd.to_datetime(df['signup_date'])
    
    # Feature engineering steps
    if settings.include_rolling:
        df = _add_rolling_features(df, settings)
    
    if settings.include_recency:
        df = _add_days_since_last_activity(df)
    
    if settings.include_ratios:
        df = _add_ratio_features(df)
    
    # Temporal features (calendar effects)
    df['day_of_week'] = df['as_of_date'].dt.dayofweek  # 0=Monday, 6=Sunday
    df['is_weekend'] = (df['day_of_week'] >= 5).astype(int)
    df['days_since_signup'] = (df['as_of_date'] - df['signup_date']).dt.days
    
    # Sort for reproducibility
    df = df.sort_values(['user_id', 'as_of_date']).reset_index(drop=True)
    
    # Save
    df.to_csv(settings.output_path, index=False)
    
    return df
```

---

## Rolling Window Features

### What are Rolling Windows?

**Definition**: Aggregations over a **sliding time window** (e.g., last 7 days).

```
Timeline:
│────┬────┬────┬────┬────┬────┬────┬────┤
  -7d  -6d  -5d  -4d  -3d  -2d  -1d  as_of_date
└──────────────────────────────────┘
         7-day window
         (sum of activity in these 7 days)

Next day:
│────┬────┬────┬────┬────┬────┬────┬────┤
  -6d  -5d  -4d  -3d  -2d  -1d  as_of_date  +1d
     └──────────────────────────────────┘
              7-day window (shifted forward)
```

### Common Window Sizes

| Window | Use Case |
|--------|----------|
| **7d** | Short-term behavior (recent engagement) |
| **14d** | Medium-term trends |
| **30d** | Long-term patterns (monthly activity) |
| **90d** | Seasonal effects (quarterly) |

### Why Multiple Windows?

**Different windows capture different signals**:

```
User A (Recently Disengaged):
logins_7d:  2  ← Low (recent decline)
logins_30d: 25 ← High (was engaged before)
Signal: Recently became inactive → High churn risk

User B (Consistently Engaged):
logins_7d:  8  ← High
logins_30d: 30 ← High
Signal: Stable high engagement → Low churn risk

User C (Consistently Disengaged):
logins_7d:  0  ← Low
logins_30d: 2  ← Low
Signal: Never engaged → Already churned or never activated
```

### Implementation Pattern

```python
# Group by user, then apply rolling window
df.groupby('user_id')['metric'].rolling(window=7).sum()

# With shift (exclude current day)
df.groupby('user_id')['metric'].shift(1).rolling(window=7).sum()
```

---

## Recency Features

### What is Recency?

**Definition**: How long since the user last did an activity?

**Why it matters**: Recent activity is a strong signal of engagement.

```
User A: last_login = 0 days ago (today) → Highly engaged
User B: last_login = 3 days ago → Moderately engaged
User C: last_login = 30 days ago → Likely churned
```

### Forward-Fill Pattern

```python
# Step 1: Mark active days
df['last_login_date'] = df['date'].where(df['logins'] > 0)

# Before ffill:
date       | logins | last_login_date
-----------|--------|----------------
2025-01-01 | 2      | 2025-01-01
2025-01-02 | 0      | NaN
2025-01-03 | 0      | NaN
2025-01-04 | 1      | 2025-01-04

# Step 2: Forward-fill (propagate last known date)
df['last_login_date'] = df.groupby('user_id')['last_login_date'].ffill()

# After ffill:
date       | logins | last_login_date
-----------|--------|----------------
2025-01-01 | 2      | 2025-01-01
2025-01-02 | 0      | 2025-01-01  ← Filled
2025-01-03 | 0      | 2025-01-01  ← Filled
2025-01-04 | 1      | 2025-01-04

# Step 3: Calculate days since
df['days_since'] = (df['date'] - df['last_login_date']).dt.days

# Result:
date       | days_since
-----------|------------
2025-01-01 | 0
2025-01-02 | 1
2025-01-03 | 2
2025-01-04 | 0
```

### Why 9999 for "Never"?

```python
df['days_since_last_quiz'] = df['days_since_last_quiz'].fillna(9999)
```

**Reason**:
- **NaN**: Means "missing data" (model doesn't know what to do)
- **9999**: Means "never did this" (model learns: large value = bad signal)
- Alternative: Use -1 (but some models handle large values better)

---

## Frequency and Behavioral Signals

### Frequency Metrics

**Definition**: How often does the user do an activity?

```python
# Example: Logins per week
df['logins_per_week'] = df['total_logins_30d'] / 4.0  # 30 days ≈ 4 weeks

# Categorize into frequency buckets
df['login_frequency'] = pd.cut(
    df['logins_per_week'],
    bins=[0, 1, 5, 10, 100],
    labels=['rare', 'occasional', 'frequent', 'power_user']
)
```

### Behavioral Signals

#### 1. Payment Failure Rate
```python
# High failure rate → Likely to churn (billing issues)
df['payment_fail_rate'] = df['payment_fails_30d'] / (df['payment_fails_30d'] + df['payment_success_30d'])
```

#### 2. Support Ticket Activity
```python
# Support tickets → User frustrated → Churn risk
df['support_tickets_7d'] = (events['event_type'] == 'support_ticket').groupby([user, date]).sum()
```

#### 3. Course Diversity
```python
# High diversity → Exploring (engaged)
# Low diversity → Stuck on one course (may lose interest)
df['course_diversity'] = df['distinct_courses_30d']
```

#### 4. Activity Trend
```python
# Compare recent (7d) vs baseline (30d)
df['activity_trend'] = df['total_events_7d'] / df['total_events_30d']

# Interpretation:
# trend > 0.5: User is MORE active recently (good!)
# trend < 0.2: User is LESS active recently (churn signal!)
```

---

## Feature Engineering Best Practices

### 1. Start Simple, Then Iterate

```python
# Iteration 1: Basic counts
features_v1 = ['total_logins_30d', 'total_watch_minutes_30d']

# Iteration 2: Add recency
features_v2 = features_v1 + ['days_since_last_login']

# Iteration 3: Add ratios
features_v3 = features_v2 + ['avg_watch_per_login']

# Compare model performance at each iteration
```

### 2. Document Feature Definitions

```python
FEATURE_CATALOG = {
    'total_logins_7d': {
        'description': 'Count of login events in past 7 days (excluding today)',
        'type': 'rolling_count',
        'window': 7,
        'leakage_safe': True,
    },
    'days_since_last_login': {
        'description': 'Days since user last logged in (9999 if never)',
        'type': 'recency',
        'leakage_safe': True,
    },
}
```

### 3. Test for Leakage

```python
def test_no_future_leakage(df, as_of_date, feature_col):
    """Ensure feature only uses data before as_of_date"""
    # Get feature value at as_of_date
    feature_value = df[df['as_of_date'] == as_of_date][feature_col].iloc[0]
    
    # Calculate expected value using only past data
    past_data = df[df['as_of_date'] < as_of_date]
    expected_value = past_data['metric'].sum()  # Or appropriate aggregation
    
    assert abs(feature_value - expected_value) < 1e-6, "Possible leakage detected!"
```

### 4. Handle Missing Values Explicitly

```python
# ❌ Don't ignore NaNs (model breaks)
df['ratio'] = df['A'] / df['B']  # May produce NaN

# ✅ Handle explicitly
df['ratio'] = df['A'] / df['B'].replace(0, 1)  # Or fillna(0)
```

### 5. Feature Naming Convention

```
{metric}_{window}d_{aggregation}

Examples:
- total_logins_7d_sum
- total_watch_minutes_30d_avg
- distinct_courses_14d

Recency:
- days_since_last_{activity}

Ratios:
- {numerator}_per_{denominator}
```

---

## Feature Catalog Design

### What is a Feature Catalog?

**Definition**: A structured inventory of all features with metadata.

### Example Catalog

```python
FEATURE_CATALOG = {
    # === ROLLING WINDOW FEATURES ===
    'total_logins_7d': {
        'category': 'engagement',
        'type': 'rolling_sum',
        'window_days': 7,
        'description': 'Total login events in past 7 days',
        'expected_range': [0, 50],
        'leakage_safe': True,
        'added_date': '2025-01-01',
        'importance': 0.15,  # From model feature_importances_
    },
    
    'days_since_last_login': {
        'category': 'recency',
        'type': 'days_since',
        'description': 'Days since last login (9999 if never)',
        'expected_range': [0, 9999],
        'leakage_safe': True,
        'added_date': '2025-01-01',
        'importance': 0.22,
    },
    
    'avg_watch_per_login': {
        'category': 'behavioral',
        'type': 'ratio',
        'description': 'Average watch minutes per login (30d window)',
        'expected_range': [0, 120],
        'leakage_safe': True,
        'added_date': '2025-01-05',
        'importance': 0.08,
    },
    
    # === TEMPORAL FEATURES ===
    'day_of_week': {
        'category': 'temporal',
        'type': 'categorical',
        'description': 'Day of week (0=Mon, 6=Sun)',
        'expected_range': [0, 6],
        'leakage_safe': True,
        'added_date': '2025-01-01',
        'importance': 0.03,
    },
}
```

### Benefits of Feature Catalog

1. **Documentation**: Team knows what each feature means
2. **Leakage Audit**: Track which features are safe
3. **Feature Selection**: Identify low-importance features to drop
4. **Monitoring**: Detect feature drift in production

---

## Performance Optimization

### 1. Vectorize Rolling Calculations

```python
# ❌ Slow (loop through users)
for user_id in df['user_id'].unique():
    user_df = df[df['user_id'] == user_id]
    user_df['logins_7d'] = user_df['logins'].rolling(7).sum()

# ✅ Fast (vectorized groupby)
df['logins_7d'] = df.groupby('user_id')['logins'].rolling(7).sum().reset_index(level=0, drop=True)
```

**Speedup**: 100x faster for 1000 users

### 2. Use `.transform()` for Group-Wise Operations

```python
# Add group mean as feature
df['user_avg_logins'] = df.groupby('user_id')['logins'].transform('mean')

# Equivalent to (but faster than):
user_means = df.groupby('user_id')['logins'].mean()
df['user_avg_logins'] = df['user_id'].map(user_means)
```

### 3. Parallelize Feature Computation

```python
from concurrent.futures import ProcessPoolExecutor

def compute_features_for_user(user_df):
    """Compute features for single user"""
    user_df = _add_rolling_features(user_df)
    user_df = _add_recency_features(user_df)
    return user_df

# Split by user
user_groups = [group for _, group in df.groupby('user_id')]

# Parallel processing
with ProcessPoolExecutor(max_workers=8) as executor:
    results = list(executor.map(compute_features_for_user, user_groups))

# Combine
df_features = pd.concat(results)
```

### 4. Cache Intermediate Results

```python
# Save rolling features (slow to compute)
df_rolling = _add_rolling_features(df)
df_rolling.to_parquet('data/cache/rolling_features.parquet')

# Later: Load from cache
df_rolling = pd.read_parquet('data/cache/rolling_features.parquet')
df_final = _add_recency_features(df_rolling)  # Fast step only
```

---

## Hands-On Exercise

### Exercise 1: Build Features

```bash
# Ensure you have user_daily.csv
ls data/processed/user_daily.csv

# Build features
python -m churn_mlops.features.build_features

# Check output
head data/features/user_features_daily.csv
wc -l data/features/user_features_daily.csv
```

### Exercise 2: Analyze Feature Distributions

```python
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv('data/features/user_features_daily.csv')

# Plot rolling features
df[['total_logins_7d', 'total_logins_14d', 'total_logins_30d']].hist(bins=30, figsize=(12, 4))
plt.suptitle('Rolling Login Features')
plt.savefig('rolling_logins.png')

# Plot recency features
df[['days_since_last_login', 'days_since_last_video']].hist(bins=30, figsize=(10, 4))
plt.suptitle('Recency Features')
plt.savefig('recency.png')

# Summary stats
print(df[['total_logins_7d', 'days_since_last_login', 'activity_trend']].describe())
```

### Exercise 3: Test for Leakage

```python
import pandas as pd

df = pd.read_csv('data/features/user_features_daily.csv')

# Check: For as_of_date, are features using only PAST data?
user_1 = df[df['user_id'] == 1].sort_values('as_of_date')

# For a specific date (e.g., 2025-01-15)
test_date = '2025-01-15'
row = user_1[user_1['as_of_date'] == test_date].iloc[0]

# Feature value
feature_val = row['total_logins_7d']

# Expected: Sum of logins from [2025-01-08, ..., 2025-01-14] (NOT including 2025-01-15)
past_data = user_1[(user_1['as_of_date'] >= '2025-01-08') & (user_1['as_of_date'] < '2025-01-15')]
expected_val = past_data['total_logins'].sum()

print(f"Feature value: {feature_val}")
print(f"Expected value: {expected_val}")
assert abs(feature_val - expected_val) < 0.1, "LEAKAGE DETECTED!"
print("✅ No leakage!")
```

### Exercise 4: Create Custom Feature

**Task**: Add `quiz_success_rate_30d` (quiz scores > 70 / total quiz attempts)

```python
import pandas as pd

# Load user_daily (not features yet)
df = pd.read_csv('data/processed/user_daily.csv')

# Load raw events to get quiz scores
events = pd.read_csv('data/raw/events.csv')
events['event_date'] = pd.to_datetime(events['event_date'])

# Filter quiz attempts
quiz_events = events[events['event_type'] == 'quiz_attempt'].copy()

# Mark successful quizzes (score > 70)
quiz_events['quiz_success'] = (quiz_events['quiz_score'] > 70).astype(int)

# Aggregate by user-date
quiz_agg = quiz_events.groupby(['user_id', 'event_date']).agg({
    'quiz_success': 'sum',
    'event_id': 'count'  # Total attempts
}).reset_index()
quiz_agg.columns = ['user_id', 'event_date', 'quiz_success_count', 'quiz_attempt_count']

# Merge with user_daily
df = pd.read_csv('data/features/user_features_daily.csv')
df['as_of_date'] = pd.to_datetime(df['as_of_date'])

df = df.merge(
    quiz_agg,
    left_on=['user_id', 'as_of_date'],
    right_on=['user_id', 'event_date'],
    how='left'
)

# Calculate rolling 30d success rate
df = df.sort_values(['user_id', 'as_of_date'])
df['quiz_success_30d'] = df.groupby('user_id')['quiz_success_count'].shift(1).rolling(30, min_periods=1).sum()
df['quiz_attempts_30d'] = df.groupby('user_id')['quiz_attempt_count'].shift(1).rolling(30, min_periods=1).sum()
df['quiz_success_rate_30d'] = df['quiz_success_30d'] / df['quiz_attempts_30d'].replace(0, 1)

# Check
print(df[['user_id', 'as_of_date', 'quiz_success_rate_30d']].head(20))
```

### Exercise 5: Feature Importance Analysis

```python
# Train simple model to get feature importances
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import pandas as pd

# Load features with labels (need to create labels first - see next module!)
# For now, simulate labels
df = pd.read_csv('data/features/user_features_daily.csv')
df['churn_label'] = (df['total_events_30d'] == 0).astype(int)  # Simplified

# Select features
feature_cols = [c for c in df.columns if any(x in c for x in ['_7d', '_14d', '_30d', 'days_since', 'trend', 'ratio'])]
X = df[feature_cols].fillna(0)
y = df['churn_label']

# Train
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
model = RandomForestClassifier(n_estimators=50, random_state=42)
model.fit(X_train, y_train)

# Get importances
importances = pd.DataFrame({
    'feature': feature_cols,
    'importance': model.feature_importances_
}).sort_values('importance', ascending=False)

print(importances.head(20))

# Plot top 10
importances.head(10).plot(x='feature', y='importance', kind='barh', figsize=(10, 6))
plt.title('Top 10 Feature Importances')
plt.savefig('feature_importances.png')
```

---

## Assessment Questions

### Question 1: Multiple Choice
What is the purpose of `.shift(1)` in rolling window calculations?

A) Speed up computation  
B) **Prevent label leakage by excluding current day** ✅  
C) Handle missing values  
D) Sort data chronologically  

**Explanation**: `.shift(1)` excludes the current day (as_of_date), ensuring features only use past data.

---

### Question 2: True/False
**Statement**: It's okay to use "total_logins_next_7d" as a feature if it helps model accuracy.

**Answer**: False ❌  
**Explanation**: This is label leakage! At prediction time, we don't know future logins. Model won't generalize.

---

### Question 3: Short Answer
Why do we use multiple window sizes (7d, 14d, 30d) instead of just one?

**Answer**:
- Different windows capture different patterns
- 7d: Recent short-term behavior
- 30d: Long-term baseline
- Comparison (7d vs 30d): Trend detection (increasing/decreasing engagement)

---

### Question 4: Code Analysis
What does this feature represent?

```python
df['activity_trend'] = df['total_events_7d'] / df['total_events_30d']
```

**Answer**:
- Ratio of recent activity (7d) to baseline (30d)
- If > 0.5: User is MORE active recently
- If < 0.2: User is LESS active recently (churn signal)
- Detects changes in behavior over time

---

### Question 5: Design Challenge
You want to predict churn 30 days ahead. What features would you NOT use?

**Answer**:
- ❌ `total_logins_next_30d` (future data - leakage!)
- ❌ `date_of_churn` (literally the label - extreme leakage!)
- ❌ `churned_already` (post-churn indicator - leakage!)
- ✅ `total_logins_past_30d` (historical data - safe)
- ✅ `days_since_last_login` (historical data - safe)

---

## Key Takeaways

### ✅ What You Learned

1. **Feature Engineering Fundamentals**
   - Transform raw data into predictive signals
   - Features matter more than models
   - Good features + simple model beats bad features + fancy model

2. **Label Leakage Prevention**
   - Only use data BEFORE `as_of_date`
   - `.shift(1)` excludes current day
   - Test features for temporal validity

3. **Rolling Window Features**
   - Capture trends over time (7d, 14d, 30d)
   - Multiple windows for different patterns
   - Vectorized computation with groupby + rolling

4. **Recency Features**
   - Days since last activity (strong engagement signal)
   - Forward-fill pattern for tracking last occurrence
   - Use 9999 for "never did this"

5. **Behavioral Features**
   - Ratios (normalize for user variability)
   - Trends (compare short-term vs baseline)
   - Domain-specific signals (payment failures, support tickets)

6. **Code Structure**
   - `_add_rolling_features()`: Time-windowed aggregations
   - `_add_days_since_last_activity()`: Recency metrics
   - `_add_ratio_features()`: Behavioral signals
   - `build_features()`: Main pipeline

---

## Next Steps

You now have a complete feature engineering pipeline!

**Next Module**: [Module 03: Machine Learning Pipeline](../module-03-ml-pipeline/section-08-training-pipeline.md)

In the next module, we'll:
- Build training labels (who churned?)
- Train baseline models
- Evaluate model performance
- Handle class imbalance

---

## Additional Resources

### Feature Engineering:
- [Feature Engineering for Machine Learning (O'Reilly)](https://www.oreilly.com/library/view/feature-engineering-for/9781491953235/)
- [Feast: Feature Store](https://feast.dev/)
- [Featuretools: Automated Feature Engineering](https://www.featuretools.com/)

### Time-Series ML:
- [Time Series Forecasting Best Practices (Microsoft)](https://github.com/microsoft/forecasting)
- [Temporal Cross-Validation](https://scikit-learn.org/stable/modules/cross_validation.html#time-series-split)

### Leakage Prevention:
- [Leakage in Data Mining (KDD)](https://www.cs.umb.edu/~ding/history/470_670_fall_2011/papers/cs670_Tran_PreferredPaper_LeakingInDataMining.pdf)
- [Target Leakage in ML](https://machinelearningmastery.com/data-leakage-machine-learning/)

---

**🎉 Congratulations!** You've completed Module 2: Data Engineering!

You've mastered:
- ✅ Data architecture and synthetic generation (Section 04)
- ✅ Validation gates and fail-fast philosophy (Section 05)
- ✅ Data processing and temporal grids (Section 06)
- ✅ Feature engineering and leakage prevention (Section 07)

Next: **[Module 03: Machine Learning Pipeline](../module-03-ml-pipeline/)** →
