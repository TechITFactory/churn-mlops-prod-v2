# Section 08: Building Training Labels

**Duration**: 2 hours  
**Level**: Intermediate  
**Prerequisites**: Module 2 (Sections 04-07)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand supervised learning label design
- ✅ Define churn in measurable terms
- ✅ Implement forward-looking label computation
- ✅ Prevent label leakage in time-series
- ✅ Handle temporal cutoffs correctly
- ✅ Analyze label distributions
- ✅ Build reproducible label pipelines

---

## 📚 Table of Contents

1. [What are Training Labels?](#what-are-training-labels)
2. [Defining Churn](#defining-churn)
3. [The Label Window Problem](#the-label-window-problem)
4. [Code Walkthrough: build_labels.py](#code-walkthrough)
5. [Forward-Looking Label Computation](#forward-looking-label-computation)
6. [Temporal Cutoff Strategy](#temporal-cutoff-strategy)
7. [Label Distribution Analysis](#label-distribution-analysis)
8. [Hands-On Exercise](#hands-on-exercise)
9. [Assessment Questions](#assessment-questions)

---

## What are Training Labels?

### Supervised Learning Recap

```
Supervised Learning = Learning from labeled examples

Example:
X (features)                           y (label)
─────────────────────────────────────  ──────────
logins_30d=25, days_since=0, ...    →  churn=0 (active)
logins_30d=2, days_since=15, ...    →  churn=1 (churned)
logins_30d=18, days_since=1, ...    →  churn=0 (active)

Model learns pattern: "If logins_30d < 5 AND days_since > 10, predict churn=1"
```

### The Label Challenge

**Question**: What does "churn" mean exactly?

**Bad Definition** (vague):
> "User stopped using the platform"

**Problems**:
- When did they stop? (today? last week? a month ago?)
- How do we measure "stopped"? (zero logins? zero videos?)
- What if they come back later?

**Good Definition** (precise):
> "User has **ZERO active days** in the **next 30 days** starting from `as_of_date`"

**Why this is better**:
- ✅ Measurable (count active days)
- ✅ Time-bounded (30-day window)
- ✅ Prediction-aligned (predict 30 days ahead)

---

## Defining Churn

### Business vs ML Definitions

#### Business Definition (Qualitative)
- "User hasn't logged in for a while"
- "User cancelled subscription"
- "User complained and left"

#### ML Definition (Quantitative)
```python
churn_label = 1 if future_active_days_in_window == 0 else 0
```

### Active Day Definition

What counts as "active"?

```python
# Option 1: Any login counts
is_active_day = (total_logins > 0)

# Option 2: Meaningful engagement (login + some activity)
is_active_day = (total_logins > 0) & (total_events > 1)

# Option 3: High engagement threshold
is_active_day = (total_watch_minutes > 10)
```

**For TechITFactory**:
```python
# Simple: Any event counts as active
is_active_day = (total_events > 0)
```

### Churn Window

**Churn Window** = How far into the future we look

```
Timeline:
│───────────────│────────────────────────│
   as_of_date    Churn Window (30 days)
   (today)       (future we predict)

If user has ZERO active days in window → churn_label = 1
```

**Common Windows**:
- **7 days**: Short-term churn (fast-moving products)
- **30 days**: Medium-term (standard for subscriptions)
- **90 days**: Long-term (enterprise, seasonal products)

**TechITFactory**: 30 days (configurable in `config.yaml`)

---

## The Label Window Problem

### Why Labels are Tricky in Time-Series

```
User Timeline:
┌────────────┬──────────────┬──────────────┐
│  as_of     │  30d window  │   Beyond     │
│  date      │  (look here) │              │
├────────────┼──────────────┼──────────────┤
│ 2025-01-01 │ [01-02 to    │  ...         │
│            │  01-31]      │              │
│            │              │              │
│ Features ← │ → Label      │              │
│ (past data)│ (future data)│              │
└────────────┴──────────────┴──────────────┘

as_of_date: 2025-01-01
Feature: logins_past_30d (Dec 2 to Jan 1) ✅
Label: active_days_next_30d (Jan 2 to Jan 31) ✅

KEY: Feature uses PAST, Label uses FUTURE
```

### The Data Availability Problem

**Problem**: We can't create labels for recent dates!

```
Today: 2025-01-15

Row: as_of_date=2025-01-01
Label: Check activity from 01-02 to 01-31 ✅ (past now)

Row: as_of_date=2025-01-14
Label: Check activity from 01-15 to 02-13 ❌ (future data not available!)

Solution: TRUNCATE last N days (where N = churn_window_days)
```

**Visual**:
```
Data Range: [2025-01-01 to 2025-02-28] (59 days)

Can create labels for:
[2025-01-01 to 2025-01-29] (59 - 30 = 29 days)

Cannot create labels for:
[2025-01-30 to 2025-02-28] (last 30 days - no future data!)
```

---

## Code Walkthrough

### File: `src/churn_mlops/training/build_labels.py`

#### Configuration

```python
@dataclass
class LabelSettings:
    processed_dir: str          # Where user_daily.csv lives
    churn_window_days: int      # How many days ahead to check (default: 30)
```

#### Step 1: Load User-Daily Data

```python
def _read_user_daily(processed_dir: str) -> pd.DataFrame:
    """Load user_daily.csv (from Section 06)"""
    path = Path(processed_dir) / "user_daily.csv"
    if not path.exists():
        raise FileNotFoundError(f"Missing required file: {path}")
    return pd.read_csv(path)
```

#### Step 2: Compute Future Active Sum (Core Logic)

```python
def _compute_future_active_sum(active: np.ndarray, window: int) -> np.ndarray:
    """
    For each day i, compute sum of active days in [i+1, i+window].
    
    Uses cumulative sum for O(n) efficiency instead of O(n*window).
    
    Example:
    active = [1, 0, 1, 1, 0, 0, 1]  (7 days)
    window = 3
    
    For day 0: Sum of days [1,2,3] = 0+1+1 = 2
    For day 1: Sum of days [2,3,4] = 1+1+0 = 2
    For day 2: Sum of days [3,4,5] = 1+0+0 = 1
    For day 3: Sum of days [4,5,6] = 0+0+1 = 1
    For day 4: Sum of days [5,6,7] = 0+1+? = 1 (only 2 remaining)
    For day 5: Sum of days [6,7]   = 1+? = 1 (only 1 remaining)
    For day 6: Sum of days []      = 0 (no future days)
    
    Result: [2, 2, 1, 1, 1, 1, 0]
    """
    n = len(active)
    
    # Cumulative sum (prefix sum array)
    cs = np.zeros(n + 1, dtype=np.int64)
    cs[1:] = np.cumsum(active.astype(np.int64))
    
    # cs[i] = sum of active[0:i]
    # Example: active=[1,0,1,1] → cs=[0,1,1,2,3]
    
    out = np.zeros(n, dtype=np.int64)
    for i in range(n):
        # We want sum of active[i+1 : i+window+1]
        start = i + 1
        end = min(n, i + window + 1)
        
        if start >= n:
            # No future days left
            out[i] = 0
        else:
            # Range sum using cumulative sum: cs[end] - cs[start]
            out[i] = cs[end] - cs[start]
    
    return out
```

**Key Insights**:
- **Cumulative sum trick**: Compute range sum in O(1) instead of O(window)
- **Efficient**: Total O(n) instead of O(n * window)
- **Edge cases**: Handle when fewer than `window` days remain

**Visual Example**:
```
active: [1, 1, 0, 1, 0]
window: 3

Day 0: Future [1,2,3] → sum(1,0,1) = 2
Day 1: Future [2,3,4] → sum(0,1,0) = 1
Day 2: Future [3,4]   → sum(1,0) = 1 (only 2 days left)
Day 3: Future [4]     → sum(0) = 0 (only 1 day left)
Day 4: Future []      → 0 (no future)

Result: [2, 1, 1, 0, 0]
```

#### Step 3: Build Labels for All Users

```python
def build_labels(user_daily: pd.DataFrame, churn_window_days: int) -> pd.DataFrame:
    """
    Build churn labels for each user-day.
    
    Steps:
    1. For each user, compute future_active_sum
    2. Label = 1 if future_active_sum == 0 (zero activity in window)
    3. Truncate last N days (can't label without future data)
    """
    d = user_daily.copy()
    
    # Ensure correct types
    d["user_id"] = pd.to_numeric(d["user_id"], errors="coerce").astype(int)
    d["as_of_date"] = pd.to_datetime(d["as_of_date"], errors="coerce")
    
    # Must have is_active_day column
    if "is_active_day" not in d.columns:
        raise ValueError("user_daily must contain 'is_active_day'")
    
    d["is_active_day"] = pd.to_numeric(d["is_active_day"], errors="coerce").fillna(0).astype(int)
    
    # Sort by user and date (critical for time-series)
    d = d.sort_values(["user_id", "as_of_date"]).reset_index(drop=True)
    
    labels = []
    
    # Process each user independently
    for _uid, g in d.groupby("user_id", sort=False):
        # Get boolean array of active days
        active = g["is_active_day"].to_numpy()
        
        # Compute future active sum for each day
        future_sum = _compute_future_active_sum(active, churn_window_days)
        
        # Create label dataframe
        tmp = g[["user_id", "as_of_date"]].copy()
        tmp["future_active_days"] = future_sum
        tmp["churn_label"] = (tmp["future_active_days"] == 0).astype(int)
        
        # TRUNCATE: Remove last N days (can't compute label without future data)
        if len(tmp) > churn_window_days:
            tmp = tmp.iloc[:-churn_window_days]  # Keep all except last N
        else:
            # User has fewer than N days of history → no valid labels
            tmp = tmp.iloc[0:0]  # Empty dataframe
        
        labels.append(tmp)
    
    # Combine all users
    out = (
        pd.concat(labels, ignore_index=True)
        if labels
        else pd.DataFrame(columns=["user_id", "as_of_date", "future_active_days", "churn_label"])
    )
    
    # Convert as_of_date to date (not datetime) for consistency
    out["as_of_date"] = pd.to_datetime(out["as_of_date"]).dt.date
    
    return out
```

**Key Points**:
- **Per-user processing**: Each user's timeline is independent
- **Truncation**: `iloc[:-churn_window_days]` removes last N days
- **Edge case**: Users with < N days history get zero labels

#### Step 4: Save Labels

```python
def write_labels(labels: pd.DataFrame, processed_dir: str) -> Path:
    """Save labels to labels_daily.csv"""
    out_dir = ensure_dir(processed_dir)
    out_path = Path(out_dir) / "labels_daily.csv"
    labels.to_csv(out_path, index=False)
    return out_path
```

---

## Forward-Looking Label Computation

### Why Forward-Looking?

**Goal**: Predict **future** churn, not **past** churn

```
Past Churn (useless):
"User churned last month" → Too late to act!

Future Churn (actionable):
"User will churn next month" → Can intervene (discount, email, support)
```

### Label Timeline Visualization

```
User 123 Timeline:
Date       | active | future_30d_sum | churn_label
-----------|--------|----------------|-------------
2025-01-01 | 1      | 15             | 0 (active in future)
2025-01-02 | 1      | 14             | 0
2025-01-03 | 0      | 14             | 0
...
2025-01-20 | 1      | 3              | 0
2025-01-21 | 1      | 2              | 0
2025-01-22 | 0      | 2              | 0
2025-01-23 | 0      | 0              | 1 ← CHURN (zero activity in next 30d)
2025-01-24 | 0      | 0              | 1
2025-01-25 | 0      | 0              | 1
...
2025-02-22 | 0      | 0              | 1
2025-02-23 | 0      | ?              | ? ← Can't compute (no future data)
```

**Interpretation**:
- **2025-01-01**: Label=0 (user will be active in next 30 days)
- **2025-01-23**: Label=1 (user has ZERO activity from 01-24 to 02-22)
- **2025-02-23**: No label (need data until 03-24, which doesn't exist)

---

## Temporal Cutoff Strategy

### The Truncation Rule

```python
if len(tmp) > churn_window_days:
    tmp = tmp.iloc[:-churn_window_days]  # Keep all except last N
else:
    tmp = tmp.iloc[0:0]  # Empty (not enough history)
```

### Visual Example

```
User with 60 days of data:
Dates: [Day 1, Day 2, ..., Day 60]
Window: 30 days

Valid labels: Day 1 to Day 30 (30 labels)
│─────────────────────────────│──────────────────────────│
  Days 1-30 (keep)               Days 31-60 (truncate)
  ↑                              ↑
  Can compute label              Can't compute label
  (have 30d future data)         (no future data)

Example:
Day 30 label: Check activity in [Day 31 to Day 60] ✅ Available
Day 31 label: Check activity in [Day 32 to Day 61] ❌ Day 61 doesn't exist!
```

### Why Truncate?

**Without truncation**:
```python
# Day 59 label: Check activity in [Day 60 to Day 89]
# Problem: Days 61-89 don't exist!
# Result: future_active_days = 1 (only Day 60)
# Label: churn_label = 0 (WRONG! We don't have full window)
```

**With truncation**:
```python
# Day 59: Excluded from labels (truncated)
# Result: Only label days with complete future window
# Label quality: HIGH (all labels use full 30d window)
```

---

## Label Distribution Analysis

### Check Label Balance

```python
import pandas as pd

labels = pd.read_csv('data/processed/labels_daily.csv')

# Overall churn rate
churn_rate = labels['churn_label'].mean()
print(f"Churn Rate: {churn_rate:.2%}")

# Distribution
print(labels['churn_label'].value_counts())
```

**Example Output**:
```
Churn Rate: 23.50%

churn_label
0    122000  (76.5% active)
1     38000  (23.5% churned)
```

### Why Balance Matters

**Balanced Dataset** (50/50):
- Model learns both classes equally
- Easy to train

**Imbalanced Dataset** (90/10):
- Model biased toward majority class
- Hard to predict minority (churn) class
- Requires special techniques (Section 11!)

### Churn Rate by Plan

```python
# Merge labels with users to get plan
users = pd.read_csv('data/raw/users.csv')
labels_with_plan = labels.merge(users[['user_id', 'plan']], on='user_id')

# Churn rate by plan
print(labels_with_plan.groupby('plan')['churn_label'].mean())
```

**Expected**:
```
plan
free    0.30  (30% churn - higher)
paid    0.15  (15% churn - lower, more committed)
```

---

## Hands-On Exercise

### Exercise 1: Build Labels

```bash
# Ensure you have user_daily.csv
ls data/processed/user_daily.csv

# Build labels (30-day window by default)
python -m churn_mlops.training.build_labels

# Check output
head data/processed/labels_daily.csv
wc -l data/processed/labels_daily.csv
```

### Exercise 2: Analyze Label Distribution

```python
import pandas as pd
import matplotlib.pyplot as plt

labels = pd.read_csv('data/processed/labels_daily.csv')

# Churn rate
churn_rate = labels['churn_label'].mean()
print(f"Churn Rate: {churn_rate:.2%}")

# Label counts
labels['churn_label'].value_counts().plot(kind='bar')
plt.title('Label Distribution')
plt.xlabel('Churn Label')
plt.ylabel('Count')
plt.xticks([0, 1], ['Active (0)', 'Churned (1)'], rotation=0)
plt.savefig('label_distribution.png')

# Class imbalance ratio
n_active = (labels['churn_label'] == 0).sum()
n_churned = (labels['churn_label'] == 1).sum()
imbalance_ratio = n_active / n_churned
print(f"Imbalance Ratio: {imbalance_ratio:.1f}:1 (active:churned)")
```

### Exercise 3: Verify Truncation

```python
import pandas as pd

# Load user_daily and labels
user_daily = pd.read_csv('data/processed/user_daily.csv')
labels = pd.read_csv('data/processed/labels_daily.csv')

# Check date ranges
user_daily['as_of_date'] = pd.to_datetime(user_daily['as_of_date'])
labels['as_of_date'] = pd.to_datetime(labels['as_of_date'])

user_daily_max_date = user_daily['as_of_date'].max()
labels_max_date = labels['as_of_date'].max()

print(f"User Daily Max Date: {user_daily_max_date.date()}")
print(f"Labels Max Date:     {labels_max_date.date()}")
print(f"Difference:          {(user_daily_max_date - labels_max_date).days} days")

# Should be ~30 days (churn_window_days)
expected_diff = 30
actual_diff = (user_daily_max_date - labels_max_date).days
assert abs(actual_diff - expected_diff) <= 1, f"Expected ~{expected_diff} days, got {actual_diff}"
print(f"✅ Truncation verified! Last {actual_diff} days excluded.")
```

### Exercise 4: Custom Churn Window

**Task**: Build labels with 7-day window (short-term churn)

```bash
# Generate with custom window
python -m churn_mlops.training.build_labels --window-days 7

# Compare 7d vs 30d churn rates
python -c "
import pandas as pd

labels_7d = pd.read_csv('data/processed/labels_daily.csv')
churn_rate_7d = labels_7d['churn_label'].mean()

# Rebuild with 30d
import subprocess
subprocess.run(['python', '-m', 'churn_mlops.training.build_labels', '--window-days', '30'])
labels_30d = pd.read_csv('data/processed/labels_daily.csv')
churn_rate_30d = labels_30d['churn_label'].mean()

print(f'7-day churn rate:  {churn_rate_7d:.2%}')
print(f'30-day churn rate: {churn_rate_30d:.2%}')
"
```

**Expected**: 7-day churn rate < 30-day churn rate (shorter window = fewer churned users)

### Exercise 5: Manual Label Verification

**Task**: Manually verify label for one user

```python
import pandas as pd
import numpy as np

# Load data
user_daily = pd.read_csv('data/processed/user_daily.csv')
labels = pd.read_csv('data/processed/labels_daily.csv')

# Pick a user
user_id = 1
window = 30

# Get user's timeline
user_data = user_daily[user_daily['user_id'] == user_id].sort_values('as_of_date').reset_index(drop=True)

# Pick a date in the middle (so we have future data)
test_idx = 30
test_date = user_data.loc[test_idx, 'as_of_date']

# Compute future active sum manually
future_window = user_data.loc[test_idx+1 : test_idx+window]
manual_future_sum = future_window['total_events'].sum() > 0  # At least 1 event?
manual_label = 0 if manual_future_sum else 1

# Get label from labels_daily
label_row = labels[(labels['user_id'] == user_id) & (labels['as_of_date'] == test_date)]
actual_label = label_row['churn_label'].values[0] if len(label_row) > 0 else None

print(f"User: {user_id}, Date: {test_date}")
print(f"Manual Label: {manual_label}")
print(f"Actual Label: {actual_label}")
assert manual_label == actual_label, "Label mismatch!"
print("✅ Label verified!")
```

---

## Assessment Questions

### Question 1: Multiple Choice
Why do we truncate the last N days when building labels?

A) To reduce file size  
B) **We can't compute labels without future data** ✅  
C) To balance the dataset  
D) To improve model accuracy  

**Explanation**: For day D, we need data from [D+1 to D+N] to compute the label. Last N days don't have this future data.

---

### Question 2: True/False
**Statement**: A churn_label=1 means the user churned in the PAST.

**Answer**: False ❌  
**Explanation**: Label=1 means user will churn in the FUTURE (zero activity in next N days). We predict future churn, not past.

---

### Question 3: Short Answer
What does `churn_label=0` mean in our definition?

**Answer**:
- User has at least 1 active day in the next 30 days
- User is NOT churning (will remain engaged)
- `future_active_days > 0`

---

### Question 4: Code Analysis
What does this code compute?

```python
future_sum = _compute_future_active_sum(active, window=30)
churn_label = (future_sum == 0).astype(int)
```

**Answer**:
- For each day, count active days in next 30 days
- If count is 0 (zero future activity) → label=1 (churned)
- If count > 0 (some future activity) → label=0 (active)

---

### Question 5: Design Challenge
Your business wants to predict churn **7 days ahead** instead of 30 days. What changes?

**Answer**:
```python
# Change churn_window_days from 30 to 7
settings.churn_window_days = 7

# Effects:
# 1. Truncate last 7 days (instead of 30)
# 2. More training data (fewer days truncated)
# 3. Lower churn rate (shorter window → fewer churned users)
# 4. Easier prediction (shorter horizon)
# 5. Less lead time for intervention (only 7 days to act)
```

---

## Key Takeaways

### ✅ What You Learned

1. **Label Design**
   - Labels = Ground truth for supervised learning
   - Must be measurable and time-bounded
   - Forward-looking (predict future, not past)

2. **Churn Definition**
   - Zero active days in next N days (e.g., 30)
   - `churn_label = 1 if future_active_days == 0`
   - Configurable window (7d, 30d, 90d)

3. **Temporal Cutoff**
   - Truncate last N days (no future data available)
   - Only label days with complete future window
   - Maintains label quality

4. **Forward-Looking Computation**
   - Use cumulative sum for efficiency (O(n) not O(n*window))
   - Per-user processing (independent timelines)
   - Handle edge cases (users with < N days history)

5. **Code Structure**
   - `_compute_future_active_sum()`: Core label logic
   - `build_labels()`: Process all users
   - `write_labels()`: Save to labels_daily.csv

---

## Next Steps

You now have labeled data ready for training!

**Next Section**: [Section 09: Training Pipeline & Baseline Model](./section-09-training-baseline.md)

In the next section, we'll:
- Split data temporally (train/test)
- Build baseline model (Logistic Regression)
- Implement preprocessing pipeline
- Train first model

---

## Additional Resources

### Label Design:
- [Label Leakage in Time-Series](https://machinelearningmastery.com/data-leakage-machine-learning/)
- [Temporal Target Definition](https://arxiv.org/abs/1803.02710)

### Churn Prediction:
- [Customer Churn Prediction (Kaggle)](https://www.kaggle.com/competitions/customer-churn-prediction)
- [Survival Analysis for Churn](https://towardsdatascience.com/survival-analysis-in-python-a-quick-guide-5a8bb6f1d2f0)

---

**🎉 Congratulations!** You've completed Section 08!

Next: **[Section 09: Training Pipeline & Baseline Model](./section-09-training-baseline.md)** →
