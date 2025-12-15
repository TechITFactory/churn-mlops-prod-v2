# Section 06: Data Processing Pipeline

**Duration**: 2.5 hours  
**Level**: Intermediate to Advanced  
**Prerequisites**: Sections 04-05

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand data cleaning principles
- ✅ Build temporal grid aggregations
- ✅ Master pandas optimization techniques
- ✅ Implement user_daily table design
- ✅ Handle time-series data correctly
- ✅ Optimize memory usage
- ✅ Design reproducible pipelines

---

## 📚 Table of Contents

1. [Raw to Processed Data Flow](#raw-to-processed-data-flow)
2. [Data Cleaning Principles](#data-cleaning-principles)
3. [Code Walkthrough: prepare_dataset.py](#code-walkthrough)
4. [User-Day Grid Pattern](#user-day-grid-pattern)
5. [Temporal Aggregation](#temporal-aggregation)
6. [Pandas Performance Optimization](#pandas-performance-optimization)
7. [Memory Management](#memory-management)
8. [Idempotency and Reproducibility](#idempotency-and-reproducibility)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## Raw to Processed Data Flow

### The Big Picture

```
┌──────────────────────────────────────────────────────────┐
│                    RAW DATA LAYER                        │
├──────────────────────────────────────────────────────────┤
│  users.csv          │  events.csv                        │
│  - user_id          │  - event_id                        │
│  - signup_date      │  - user_id                         │
│  - plan             │  - event_time                      │
│  - country          │  - event_type                      │
│                     │  - watch_minutes                   │
│  [1000 rows]        │  [50,000 rows]                     │
└──────────────────┬──────────────────────────────────────┘
                   │
                   │ VALIDATION GATE ✅
                   │
                   ↓
┌──────────────────────────────────────────────────────────┐
│              DATA CLEANING & PREPARATION                 │
├──────────────────────────────────────────────────────────┤
│  • Parse dates                                           │
│  • Remove duplicates                                     │
│  • Filter invalid rows                                   │
│  • Standardize types                                     │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────────┐
│           TEMPORAL GRID CONSTRUCTION                     │
├──────────────────────────────────────────────────────────┤
│  user_day_grid = users × dates (Cartesian product)      │
│  - Every user for every day in range                     │
│  - Baseline: user_id, as_of_date                         │
│  [1000 users × 180 days = 180,000 rows]                 │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────────┐
│              DAILY AGGREGATION                           │
├──────────────────────────────────────────────────────────┤
│  Group events by (user_id, date) and aggregate:         │
│  - total_logins (count)                                  │
│  - total_watch_minutes (sum)                             │
│  - total_quiz_attempts (count)                           │
│  - distinct_courses (nunique)                            │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────────┐
│                PROCESSED DATA LAYER                      │
├──────────────────────────────────────────────────────────┤
│  user_daily.csv                                          │
│  - user_id                                               │
│  - as_of_date                                            │
│  - signup_date (from users)                              │
│  - plan (from users)                                     │
│  - total_logins                                          │
│  - total_watch_minutes                                   │
│  - total_quiz_attempts                                   │
│  - distinct_courses                                      │
│  [180,000 rows]                                          │
└──────────────────────────────────────────────────────────┘
```

### Why User-Day Grain?

**Question**: Why not keep raw events?

**Answer**: ML models need **fixed-length feature vectors**

```python
# ❌ Raw events: Variable length per user
user_123 = [
    {"event": "login", "time": "2025-01-01 09:00"},
    {"event": "video_watch", "time": "2025-01-01 09:15"},
    {"event": "login", "time": "2025-01-02 10:00"},
    # ... 50 events
]
# How to feed this into scikit-learn? Can't!

# ✅ User-day aggregation: Fixed columns
user_123_daily = [
    {"date": "2025-01-01", "logins": 1, "watch_minutes": 45},
    {"date": "2025-01-02", "logins": 1, "watch_minutes": 30},
    # ... 180 days
]
# Each day has same columns → can build features!
```

---

## Data Cleaning Principles

### The 5 Cs of Data Cleaning

#### 1. **Correct** - Fix errors
```python
# Example: Fix inverted dates
df['signup_date'] = pd.to_datetime(df['signup_date'], errors='coerce')
```

#### 2. **Complete** - Fill missing values (carefully!)
```python
# Example: Fill missing country with 'UNKNOWN' (don't drop!)
df['country'] = df['country'].fillna('UNKNOWN')
```

#### 3. **Consistent** - Standardize formats
```python
# Example: Standardize country codes
df['country'] = df['country'].str.upper()  # 'us' → 'US'
```

#### 4. **Conformant** - Match expected types
```python
# Example: Ensure user_id is integer
df['user_id'] = df['user_id'].astype(int)
```

#### 5. **Current** - Remove outdated data
```python
# Example: Filter to last 180 days only
cutoff = datetime.now() - timedelta(days=180)
df = df[df['event_time'] >= cutoff]
```

### When to Drop vs Fill

| Scenario | Action | Reason |
|----------|--------|--------|
| Missing user_id | **Drop** | Cannot identify user → useless |
| Missing event_time | **Drop** | Time-series needs timestamps |
| Missing country | **Fill with 'UNKNOWN'** | Still useful data, just missing attr |
| Missing watch_minutes (for video_watch) | **Fill with 0** | Probably opened but didn't watch |
| Missing quiz_score (for quiz_attempt) | **Drop** | Score is the point of the event |

**Golden Rule**: Only fill if the filled value is **defensible** (not arbitrary).

---

## Code Walkthrough

### File: `src/churn_mlops/data/prepare_dataset.py`

#### Configuration: PrepareSettings

```python
@dataclass
class PrepareSettings:
    """Configuration for data preparation pipeline"""
    users_path: str = "data/raw/users.csv"
    events_path: str = "data/raw/events.csv"
    output_path: str = "data/processed/user_daily.csv"
    start_date: Optional[str] = None  # If None, use earliest event
    end_date: Optional[str] = None    # If None, use latest event
    min_events_per_user: int = 1      # Filter users with < N events
```

#### Step 1: Clean Users

```python
def _clean_users(users_raw: pd.DataFrame) -> pd.DataFrame:
    """
    Clean and standardize users data
    
    Transformations:
    1. Parse signup_date to datetime
    2. Standardize country codes (uppercase)
    3. Ensure user_id is integer
    4. Drop duplicates
    """
    users = users_raw.copy()
    
    # Parse dates
    users['signup_date'] = pd.to_datetime(users['signup_date'])
    
    # Standardize strings
    users['country'] = users['country'].str.upper()
    users['plan'] = users['plan'].str.lower()
    
    # Ensure correct types
    users['user_id'] = users['user_id'].astype(int)
    users['is_paid'] = users['is_paid'].astype(int)
    
    # Drop duplicates (keep first occurrence)
    users = users.drop_duplicates(subset=['user_id'], keep='first')
    
    # Drop engagement_score (synthetic only, not for features)
    if 'engagement_score' in users.columns:
        users = users.drop(columns=['engagement_score'])
    
    return users
```

**Key Points**:
- `copy()` prevents modifying original dataframe (defensive)
- `keep='first'` for duplicates (arbitrary but consistent)
- Drop `engagement_score` (would be leakage!)

#### Step 2: Clean Events

```python
def _clean_events(events_raw: pd.DataFrame) -> pd.DataFrame:
    """
    Clean and standardize events data
    
    Transformations:
    1. Parse event_time to datetime
    2. Derive event_date from event_time
    3. Filter out future events
    4. Drop events with missing critical fields
    5. Standardize event_type (lowercase)
    """
    events = events_raw.copy()
    
    # Parse timestamps
    events['event_time'] = pd.to_datetime(events['event_time'])
    events['event_date'] = events['event_time'].dt.date
    
    # Filter out future events (data quality issue)
    now = datetime.now()
    events = events[events['event_time'] <= now]
    
    # Drop events with missing user_id or event_time
    events = events.dropna(subset=['user_id', 'event_time', 'event_type'])
    
    # Ensure correct types
    events['user_id'] = events['user_id'].astype(int)
    events['event_id'] = events['event_id'].astype(int)
    
    # Standardize event_type
    events['event_type'] = events['event_type'].str.lower()
    
    # Fill missing numeric columns with 0 (defensive)
    numeric_cols = ['watch_minutes', 'quiz_score', 'amount']
    for col in numeric_cols:
        if col in events.columns:
            events[col] = events[col].fillna(0)
    
    return events
```

**Key Points**:
- Derive `event_date` from `event_time` (consistency)
- Filter future events (validation overlap)
- Fill numeric NaNs with 0 (safe assumption)

#### Step 3: Build User-Day Grid

```python
def _build_user_day_grid(
    users: pd.DataFrame,
    events: pd.DataFrame,
    start_date: date,
    end_date: date,
) -> pd.DataFrame:
    """
    Create Cartesian product of users × dates
    
    Result: Every user has a row for every day in range
    This ensures temporal continuity (even on days with no activity)
    
    Example:
    users: [1, 2, 3]
    dates: [2025-01-01, 2025-01-02]
    grid: [
        (1, 2025-01-01),
        (1, 2025-01-02),
        (2, 2025-01-01),
        (2, 2025-01-02),
        (3, 2025-01-01),
        (3, 2025-01-02),
    ]
    """
    # Generate date range
    date_range = pd.date_range(start=start_date, end=end_date, freq='D')
    
    # Create grid: Cartesian product
    # Method: Cross join (merge with dummy key)
    users_base = users[['user_id', 'signup_date', 'plan', 'is_paid', 'country']].copy()
    users_base['_merge_key'] = 1
    
    dates_df = pd.DataFrame({'as_of_date': date_range})
    dates_df['_merge_key'] = 1
    
    # Cross join
    grid = users_base.merge(dates_df, on='_merge_key', how='outer')
    grid = grid.drop(columns=['_merge_key'])
    
    # Filter: Only include days ON or AFTER signup_date
    # User cannot have activity before they signed up!
    grid['signup_date_only'] = grid['signup_date'].dt.date
    grid = grid[grid['as_of_date'].dt.date >= grid['signup_date_only']]
    grid = grid.drop(columns=['signup_date_only'])
    
    return grid
```

**Key Points**:
- **Cartesian product**: Every user × every day
- **Temporal constraint**: Only days after signup
- **Dummy key trick**: Pandas cross join via merge

**Visual Example**:
```
users:
user_id | signup_date
--------|------------
1       | 2025-01-01
2       | 2025-01-02

dates: [2025-01-01, 2025-01-02, 2025-01-03]

Grid (before filter):
user_id | signup_date | as_of_date
--------|-------------|------------
1       | 2025-01-01  | 2025-01-01  ✅ (on/after signup)
1       | 2025-01-01  | 2025-01-02  ✅
1       | 2025-01-01  | 2025-01-03  ✅
2       | 2025-01-02  | 2025-01-01  ❌ (before signup)
2       | 2025-01-02  | 2025-01-02  ✅
2       | 2025-01-02  | 2025-01-03  ✅

Grid (after filter): 5 rows
```

#### Step 4: Aggregate Events

```python
def _aggregate_daily_events(events: pd.DataFrame) -> pd.DataFrame:
    """
    Group events by (user_id, event_date) and compute daily metrics
    
    Metrics:
    - total_logins: Count of 'login' events
    - total_watch_minutes: Sum of watch_minutes (video_watch events)
    - total_quiz_attempts: Count of 'quiz_attempt' events
    - distinct_courses: Unique courses accessed
    - total_events: Total event count
    """
    # Ensure event_date is date type
    events['event_date'] = pd.to_datetime(events['event_date'])
    
    # Group by user and date
    daily = events.groupby(['user_id', 'event_date']).agg({
        'event_id': 'count',  # Total events
        'event_type': lambda x: (x == 'login').sum(),  # Count logins
        'watch_minutes': 'sum',  # Total watch time
        'course_name': 'nunique',  # Distinct courses
    }).reset_index()
    
    # Rename columns
    daily.columns = ['user_id', 'event_date', 'total_events', 'total_logins', 'total_watch_minutes', 'distinct_courses']
    
    # Count quiz attempts (separate aggregation)
    quiz_counts = events[events['event_type'] == 'quiz_attempt'].groupby(['user_id', 'event_date']).size().reset_index(name='total_quiz_attempts')
    
    # Merge back
    daily = daily.merge(quiz_counts, on=['user_id', 'event_date'], how='left')
    daily['total_quiz_attempts'] = daily['total_quiz_attempts'].fillna(0).astype(int)
    
    return daily
```

**Key Points**:
- **groupby + agg**: Core pandas aggregation pattern
- **Lambda functions**: Custom aggregations (e.g., count logins)
- **Separate aggregations**: Some metrics need filtering first (quiz attempts)

#### Step 5: Join Grid + Aggregations

```python
def prepare_dataset(settings: PrepareSettings) -> pd.DataFrame:
    """
    Main pipeline: Raw data → user_daily.csv
    
    Steps:
    1. Load and validate
    2. Clean users and events
    3. Build user-day grid
    4. Aggregate events by day
    5. Join grid + aggregations (left join)
    6. Fill missing metrics with 0 (no activity)
    """
    # Load raw data
    users_raw = pd.read_csv(settings.users_path)
    events_raw = pd.read_csv(settings.events_path)
    
    # Validate (from Section 05)
    users_result = validate_users(users_raw)
    events_result = validate_events(events_raw)
    if not users_result.is_valid or not events_result.is_valid:
        raise ValueError("Validation failed!")
    
    # Clean
    users = _clean_users(users_raw)
    events = _clean_events(events_raw)
    
    # Determine date range
    if settings.start_date:
        start_date = datetime.fromisoformat(settings.start_date).date()
    else:
        start_date = events['event_date'].min()
    
    if settings.end_date:
        end_date = datetime.fromisoformat(settings.end_date).date()
    else:
        end_date = events['event_date'].max()
    
    # Build grid
    grid = _build_user_day_grid(users, events, start_date, end_date)
    
    # Aggregate events
    daily_agg = _aggregate_daily_events(events)
    
    # Join: grid (all user-days) LEFT JOIN daily_agg (active days only)
    user_daily = grid.merge(
        daily_agg,
        left_on=['user_id', 'as_of_date'],
        right_on=['user_id', 'event_date'],
        how='left'
    )
    
    # Fill missing metrics with 0 (days with no activity)
    metric_cols = ['total_events', 'total_logins', 'total_watch_minutes', 'total_quiz_attempts', 'distinct_courses']
    for col in metric_cols:
        user_daily[col] = user_daily[col].fillna(0).astype(int)
    
    # Drop redundant event_date column
    user_daily = user_daily.drop(columns=['event_date'], errors='ignore')
    
    # Sort for reproducibility
    user_daily = user_daily.sort_values(['user_id', 'as_of_date']).reset_index(drop=True)
    
    # Save
    user_daily.to_csv(settings.output_path, index=False)
    
    return user_daily
```

**Key Points**:
- **Left join**: Keep all user-days (even zero activity)
- **Fill with 0**: Explicit "no activity" (not missing data)
- **Sort before save**: Reproducible output order

---

## User-Day Grid Pattern

### What is a Temporal Grid?

**Definition**: A table where **every entity** (user) has a row for **every time period** (day).

### Why Build a Grid?

**Problem**: Events are sparse (users don't act every day)

```
Events (sparse):
user_id | event_date | logins
--------|------------|-------
1       | 2025-01-01 | 2
1       | 2025-01-03 | 1   ← Missing 2025-01-02!
2       | 2025-01-02 | 3
```

**Grid (dense)**:
```
user_id | as_of_date | logins
--------|------------|-------
1       | 2025-01-01 | 2
1       | 2025-01-02 | 0   ← Explicit zero (not missing)
1       | 2025-01-03 | 1
2       | 2025-01-01 | 0
2       | 2025-01-02 | 3
2       | 2025-01-03 | 0
```

**Benefits**:
- ✅ **Rolling windows work**: Can calculate 7-day average (even if some days are 0)
- ✅ **No gaps**: Every day represented
- ✅ **Consistent**: All users have same time range

### Cartesian Product Implementation

```python
# Method 1: Dummy key trick (what we use)
users['_key'] = 1
dates['_key'] = 1
grid = users.merge(dates, on='_key')

# Method 2: pandas 1.2+ (cleaner)
grid = users.merge(dates, how='cross')

# Method 3: itertools (explicit)
import itertools
user_ids = users['user_id'].tolist()
dates = pd.date_range(start, end).tolist()
grid = pd.DataFrame(list(itertools.product(user_ids, dates)), columns=['user_id', 'date'])
```

---

## Temporal Aggregation

### GroupBy Aggregation Pattern

```python
# Basic pattern
df.groupby(['group_col1', 'group_col2']).agg({
    'value_col1': 'sum',
    'value_col2': 'mean',
    'value_col3': lambda x: custom_function(x),
})
```

### Common Aggregations

| Function | Description | Example |
|----------|-------------|---------|
| `count` | Number of rows | Count of events |
| `sum` | Total of values | Total watch minutes |
| `mean` | Average | Average quiz score |
| `min` / `max` | Extremes | First/last event time |
| `nunique` | Unique count | Distinct courses |
| `std` | Standard deviation | Variability in scores |
| `lambda` | Custom logic | Count of specific type |

### Example: Multiple Aggregations

```python
daily = events.groupby(['user_id', 'event_date']).agg({
    'event_id': 'count',                          # Total events
    'event_type': lambda x: (x == 'login').sum(), # Login count
    'watch_minutes': ['sum', 'mean', 'max'],      # Multiple stats
    'course_name': 'nunique',                     # Distinct courses
}).reset_index()

# Result columns:
# ('event_id', 'count')
# ('event_type', '<lambda>')
# ('watch_minutes', 'sum')
# ('watch_minutes', 'mean')
# ('watch_minutes', 'max')
# ('course_name', 'nunique')

# Flatten multi-index columns
daily.columns = ['_'.join(col).strip() for col in daily.columns.values]
```

---

## Pandas Performance Optimization

### Rule 1: Vectorize (Don't Loop)

#### ❌ Slow (Row-by-Row Loop)
```python
# 180,000 rows × slow Python loop = 30 seconds
for idx, row in user_daily.iterrows():
    if row['total_logins'] > 0:
        user_daily.at[idx, 'is_active'] = 1
    else:
        user_daily.at[idx, 'is_active'] = 0
```

#### ✅ Fast (Vectorized)
```python
# 180,000 rows × fast NumPy operation = 0.01 seconds
user_daily['is_active'] = (user_daily['total_logins'] > 0).astype(int)
```

**Speedup**: 3000x faster!

### Rule 2: Use Appropriate Data Types

```python
# ❌ Inefficient (default int64, float64)
df = pd.read_csv('data.csv')
# user_id: int64 (8 bytes per row)
# country: object (variable bytes + pointer overhead)

# ✅ Optimized
df = pd.read_csv('data.csv', dtype={
    'user_id': 'int32',      # 4 bytes (sufficient for 2 billion IDs)
    'country': 'category',   # Categorical (stores codes, not strings)
    'is_paid': 'int8',       # 1 byte (0 or 1)
})

# Memory savings: ~50% for large datasets
```

### Rule 3: Filter Early

```python
# ❌ Inefficient (aggregate all, then filter)
all_events = pd.read_csv('events.csv')  # 10 million rows
daily = all_events.groupby(['user_id', 'event_date']).size()
recent = daily[daily.index.get_level_values('event_date') >= '2025-01-01']

# ✅ Efficient (filter first, then aggregate)
all_events = pd.read_csv('events.csv')
recent_events = all_events[all_events['event_date'] >= '2025-01-01']  # Now 1 million rows
daily = recent_events.groupby(['user_id', 'event_date']).size()
```

### Rule 4: Use Merge Strategy Wisely

```python
# ❌ Slow (merge in loop)
result = users
for events_chunk in event_chunks:
    result = result.merge(events_chunk, on='user_id')

# ✅ Fast (concat then merge once)
all_events = pd.concat(event_chunks)
result = users.merge(all_events, on='user_id')
```

---

## Memory Management

### Check Memory Usage

```python
# Check dataframe memory
df.info(memory_usage='deep')

# Check specific columns
df.memory_usage(deep=True)

# Example output:
# user_id         1440000 bytes (int64)
# country        11520000 bytes (object)
# Total: ~13 MB
```

### Optimize with Categories

```python
# Before: object dtype (stores full strings)
df['country'].memory_usage(deep=True)
# 11,520,000 bytes

# After: category dtype (stores integer codes + lookup table)
df['country'] = df['country'].astype('category')
df['country'].memory_usage(deep=True)
# 180,000 bytes (64x smaller!)

# Lookup table:
# 0 → 'US'
# 1 → 'UK'
# 2 → 'IN'
# ...
```

**When to use categories**:
- Low cardinality (< 50% unique values)
- Repeated strings (country, plan, event_type)

**When NOT to use categories**:
- High cardinality (user_id, event_id)
- Numeric data (already efficient)

### Chunked Processing

```python
# For very large files (>10GB)
chunk_size = 100_000
chunks = []

for chunk in pd.read_csv('huge_file.csv', chunksize=chunk_size):
    # Process chunk
    processed = chunk[chunk['total_logins'] > 0]
    chunks.append(processed)

# Combine results
result = pd.concat(chunks, ignore_index=True)
```

---

## Idempotency and Reproducibility

### What is Idempotency?

**Definition**: Running the pipeline multiple times produces the **same result**.

```bash
# Run 1
python prepare_data.py  # Produces user_daily_v1.csv

# Run 2 (same inputs)
python prepare_data.py  # Produces user_daily_v2.csv

# Idempotent if: v1 == v2 (bit-for-bit identical)
```

### Why It Matters

- **Debugging**: Re-run pipeline without worrying about side effects
- **Collaboration**: Team members get same results
- **Auditing**: Prove results are reproducible

### Achieving Idempotency

#### 1. **Sort Before Save**
```python
# ❌ Non-deterministic (groupby order undefined)
df.groupby('user_id').sum().to_csv('output.csv')

# ✅ Deterministic (sorted by index)
df.groupby('user_id').sum().sort_index().to_csv('output.csv')
```

#### 2. **Drop Timestamps**
```python
# ❌ Includes processing timestamp (changes every run)
df['processed_at'] = datetime.now()

# ✅ Deterministic (no timestamps)
# If needed, store in metadata file separately
```

#### 3. **Use Explicit Defaults**
```python
# ❌ Implicit behavior (may change with pandas version)
df.fillna(method='ffill')

# ✅ Explicit behavior (always clear)
df.fillna(0)
```

---

## Hands-On Exercise

### Exercise 1: Run Data Preparation Pipeline

```bash
# Generate raw data (if not already done)
python -m churn_mlops.data.generate_synthetic --seed 42

# Validate
python -c "
from churn_mlops.data.validate import validate_users, validate_events
import pandas as pd
users = pd.read_csv('data/raw/users.csv')
events = pd.read_csv('data/raw/events.csv')
assert validate_users(users).is_valid
assert validate_events(events).is_valid
print('✅ Validation passed!')
"

# Prepare dataset
python -m churn_mlops.data.prepare_dataset

# Check output
head data/processed/user_daily.csv
wc -l data/processed/user_daily.csv  # Count rows
```

**Expected**:
- 1000 users × ~180 days = ~180,000 rows

### Exercise 2: Analyze User-Day Grid

```python
import pandas as pd

user_daily = pd.read_csv('data/processed/user_daily.csv')

# Check grid completeness
users_count = user_daily['user_id'].nunique()
dates_count = user_daily['as_of_date'].nunique()
expected_rows = users_count * dates_count
actual_rows = len(user_daily)

print(f"Users: {users_count}")
print(f"Dates: {dates_count}")
print(f"Expected rows: {expected_rows}")
print(f"Actual rows: {actual_rows}")
print(f"Grid complete: {actual_rows == expected_rows}")
```

### Exercise 3: Compare Active vs Inactive Days

```python
import pandas as pd

user_daily = pd.read_csv('data/processed/user_daily.csv')

# Mark active days (any activity)
user_daily['is_active'] = (user_daily['total_events'] > 0).astype(int)

# Count active vs inactive
active_days = user_daily['is_active'].sum()
inactive_days = len(user_daily) - active_days

print(f"Active days: {active_days} ({active_days/len(user_daily):.1%})")
print(f"Inactive days: {inactive_days} ({inactive_days/len(user_daily):.1%})")

# By plan
print("\nBy plan:")
print(user_daily.groupby('plan')['is_active'].mean())
```

### Exercise 4: Memory Optimization Challenge

**Task**: Optimize memory usage of `user_daily.csv`

```python
import pandas as pd

# Load with default types
df = pd.read_csv('data/processed/user_daily.csv')
print(f"Original memory: {df.memory_usage(deep=True).sum() / 1024**2:.2f} MB")

# Optimize types
df_opt = pd.read_csv('data/processed/user_daily.csv', dtype={
    'user_id': 'int32',
    'plan': 'category',
    'country': 'category',
    'is_paid': 'int8',
    'total_logins': 'int16',
    'total_watch_minutes': 'float32',
    'total_quiz_attempts': 'int16',
    'total_events': 'int16',
    'distinct_courses': 'int8',
})

print(f"Optimized memory: {df_opt.memory_usage(deep=True).sum() / 1024**2:.2f} MB")
print(f"Savings: {(1 - df_opt.memory_usage(deep=True).sum() / df.memory_usage(deep=True).sum()):.1%}")
```

### Exercise 5: Build Custom Aggregation

**Task**: Add `payment_success_count` to user_daily

```python
import pandas as pd

# Load raw events
events = pd.read_csv('data/raw/events.csv')

# Count payment successes by user-date
payments = events[events['event_type'] == 'payment_success']
payment_counts = payments.groupby(['user_id', 'event_date']).size().reset_index(name='payment_success_count')

# Load user_daily
user_daily = pd.read_csv('data/processed/user_daily.csv')

# Merge
user_daily = user_daily.merge(
    payment_counts,
    left_on=['user_id', 'as_of_date'],
    right_on=['user_id', 'event_date'],
    how='left'
)
user_daily['payment_success_count'] = user_daily['payment_success_count'].fillna(0).astype(int)

# Check
print(user_daily[user_daily['payment_success_count'] > 0].head())
```

---

## Assessment Questions

### Question 1: Multiple Choice
Why do we build a user-day grid instead of just aggregating events?

A) To make the file larger  
B) **To ensure temporal continuity (no missing days)** ✅  
C) To slow down processing  
D) Because pandas requires it  

**Explanation**: Grid ensures every user has a row for every day (including zero-activity days), enabling rolling window calculations.

---

### Question 2: True/False
**Statement**: Filling missing values with 0 is always the right choice.

**Answer**: False ❌  
**Explanation**: Only fill if 0 is defensible (e.g., "no logins" = 0 logins). Don't fill nulls in `user_id` or `event_time` (those should be dropped).

---

### Question 3: Short Answer
What is the difference between `left join` and `inner join` when merging grid + aggregations?

**Answer**:
- **Left join**: Keep all user-days (even with no events) → Preserves grid completeness
- **Inner join**: Keep only user-days WITH events → Loses inactive days

We use **left join** to maintain full temporal grid.

---

### Question 4: Code Analysis
What does this code do?

```python
grid['signup_date_only'] = grid['signup_date'].dt.date
grid = grid[grid['as_of_date'].dt.date >= grid['signup_date_only']]
```

**Answer**:
- Filters grid to only include days ON or AFTER signup_date
- Prevents illogical rows (user activity before they existed)
- Ensures temporal consistency

---

### Question 5: Design Challenge
You need to process 100 GB of events data. How would you modify `prepare_dataset.py`?

**Answer**:
```python
# Use chunked processing
chunk_size = 1_000_000
chunks = []

for events_chunk in pd.read_csv('huge_events.csv', chunksize=chunk_size):
    # Aggregate each chunk
    daily_agg = _aggregate_daily_events(events_chunk)
    chunks.append(daily_agg)

# Combine and re-aggregate (daily_agg is much smaller than raw events)
all_daily = pd.concat(chunks).groupby(['user_id', 'event_date']).sum().reset_index()
```

Alternative: Use Dask or Spark for distributed processing.

---

## Key Takeaways

### ✅ What You Learned

1. **Data Processing Flow**
   - Raw → Clean → Grid → Aggregate → Processed
   - Validation gates at each stage
   - Reproducible pipelines

2. **User-Day Grid Pattern**
   - Cartesian product (users × dates)
   - Ensures temporal continuity
   - Enables rolling window features

3. **Pandas Optimization**
   - Vectorize (don't loop)
   - Use appropriate dtypes (category, int32)
   - Filter early, merge strategically

4. **Aggregation Techniques**
   - GroupBy + Agg pattern
   - Multiple metrics in one pass
   - Custom lambda functions

5. **Code Structure**
   - `_clean_users()`: Standardize users
   - `_clean_events()`: Standardize events
   - `_build_user_day_grid()`: Cartesian product
   - `_aggregate_daily_events()`: Group and sum
   - `prepare_dataset()`: Orchestrate pipeline

---

## Next Steps

You now know how to process raw data into structured tables!

**Next Section**: [Section 07: Feature Engineering Deep Dive](./section-07-feature-engineering.md)

In the next section, we'll:
- Build rolling window features (7d, 14d, 30d)
- Calculate recency metrics (days since last activity)
- Prevent label leakage (critical!)
- Create feature catalog

---

## Additional Resources

### Pandas Performance:
- [Pandas Performance Guide](https://pandas.pydata.org/pandas-docs/stable/user_guide/enhancingperf.html)
- [Effective Pandas](https://github.com/TomAugspurger/effective-pandas)

### Time-Series Processing:
- [Time Series with Pandas](https://pandas.pydata.org/pandas-docs/stable/user_guide/timeseries.html)
- [Temporal Aggregation Patterns](https://towardsdatascience.com/temporal-aggregation-in-pandas-2ed68e0e3ed5)

### Memory Optimization:
- [Reducing Pandas Memory Usage](https://towardsdatascience.com/pandas-memory-optimization-8a9c28c5a8fa)
- [Category Dtype Guide](https://pandas.pydata.org/pandas-docs/stable/user_guide/categorical.html)

---

**🎉 Congratulations!** You've completed Section 06!

Next: **[Section 07: Feature Engineering Deep Dive](./section-07-feature-engineering.md)** →
