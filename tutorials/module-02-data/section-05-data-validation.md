# Section 05: Data Validation Gates

**Duration**: 2 hours  
**Level**: Intermediate  
**Prerequisites**: Section 04

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand the "fail-fast" philosophy in ML pipelines
- ✅ Implement schema validation checks
- ✅ Build data integrity validators
- ✅ Create business rule validation
- ✅ Handle validation errors gracefully
- ✅ Design validation reports
- ✅ Integrate validation into pipelines

---

## 📚 Table of Contents

1. [Why Data Validation Matters](#why-data-validation-matters)
2. [The Fail-Fast Philosophy](#the-fail-fast-philosophy)
3. [Three Types of Validation](#three-types-of-validation)
4. [Code Walkthrough: validate.py](#code-walkthrough)
5. [Schema Validation](#schema-validation)
6. [Integrity Validation](#integrity-validation)
7. [Business Rule Validation](#business-rule-validation)
8. [Validation Reports](#validation-reports)
9. [Integration with Pipelines](#integration-with-pipelines)
10. [Hands-On Exercise](#hands-on-exercise)
11. [Assessment Questions](#assessment-questions)

---

## Why Data Validation Matters

### The 87% Problem (Revisited)

Remember from Section 01:
> **87% of ML projects fail** — most due to data quality issues, not model issues.

### Real-World Failure Examples

#### Example 1: The Missing Column
```python
# Training data
df_train = pd.read_csv("train.csv")  # Has 'country' column
model.fit(df_train[['age', 'country']])

# Production data (6 months later)
df_prod = pd.read_csv("prod.csv")  # 'country' column was removed!
model.predict(df_prod)  # 💥 KeyError: 'country'

# RESULT: Model crashes in production
```

#### Example 2: The Invalid Dates
```python
# Training data: dates in YYYY-MM-DD format
# Production data: dates in MM/DD/YYYY format

# Model trained on 2025-01-15 (Jan 15)
# Production gets 01/15/2025 → parsed as 2025-01-15 (lucky!)
# Production gets 15/01/2025 → parsed as 2025-15-01 (INVALID!)

# RESULT: Silent failures, wrong predictions
```

#### Example 3: The Negative Payment
```python
# Training data: all payments positive
# Production data: someone enters -$100 (refund)

# Model never saw negatives in training
# Extrapolates incorrectly → bad predictions

# RESULT: Business logic broken
```

### The Cost of Bad Data

```
Bad Data Enters Pipeline
        │
        ↓
No Validation
        │
        ↓
Model Trained on Garbage
        │
        ↓
Model Deployed to Production
        │
        ↓
Wrong Predictions
        │
        ↓
Business Decisions Made on Lies
        │
        ↓
$$$ Lost, Trust Damaged $$$
```

**Solution**: Validation gates that **fail fast** and **fail loud**.

---

## The Fail-Fast Philosophy

### What is Fail-Fast?

> **Fail-Fast**: Detect errors as early as possible and immediately stop execution.

**Anti-Pattern** (Fail-Slow):
```python
# Bad: Continue even if data is invalid
df = pd.read_csv("data.csv")
df = df.fillna(0)  # Hide missing values
df = df[df['age'] > 0]  # Silently drop invalid rows
model.fit(df)  # Train on incomplete data
# RESULT: Model trained on garbage, you don't know it
```

**Best Practice** (Fail-Fast):
```python
# Good: Validate first, fail if invalid
df = pd.read_csv("data.csv")

validation = validate_data(df)
if not validation.is_valid:
    # ❌ STOP IMMEDIATELY
    print(validation.errors)
    raise ValueError("Data validation failed!")

# ✅ Only proceed if data is clean
model.fit(df)
```

### Benefits of Fail-Fast

| Benefit | Description |
|---------|-------------|
| **Early Detection** | Catch errors before they propagate |
| **Clear Errors** | Know exactly what's wrong (not vague "model failed") |
| **No Corruption** | Bad data never reaches model |
| **Fast Debugging** | Errors happen at validation stage (not inference) |
| **Trust** | Team trusts pipeline won't silently fail |

---

## Three Types of Validation

### 1. Schema Validation
**Question**: "Does the data have the right structure?"

```python
# Check columns exist
required_columns = ['user_id', 'signup_date', 'plan']
missing = set(required_columns) - set(df.columns)
if missing:
    raise ValueError(f"Missing columns: {missing}")

# Check data types
if df['user_id'].dtype != 'int64':
    raise TypeError("user_id must be integer")
```

### 2. Integrity Validation
**Question**: "Are the values logically consistent?"

```python
# Check foreign key relationships
users_in_events = set(events_df['user_id'])
users_in_users = set(users_df['user_id'])
orphans = users_in_events - users_in_users
if orphans:
    raise ValueError(f"Events reference non-existent users: {orphans}")

# Check date ordering
if (users_df['signup_date'] > users_df['last_login']).any():
    raise ValueError("Signup date cannot be after last login!")
```

### 3. Business Rule Validation
**Question**: "Do the values make business sense?"

```python
# Check realistic ranges
if (events_df['watch_minutes'] < 0).any():
    raise ValueError("Watch minutes cannot be negative!")

if (events_df['watch_minutes'] > 1440).any():
    raise ValueError("Watch minutes cannot exceed 24 hours!")

# Check enum values
valid_plans = {'free', 'paid'}
invalid_plans = set(users_df['plan']) - valid_plans
if invalid_plans:
    raise ValueError(f"Invalid plans: {invalid_plans}")
```

---

## Code Walkthrough

### File: `src/churn_mlops/data/validate.py`

Let's walk through the validation implementation:

#### ValidationResult Data Class

```python
@dataclass
class ValidationResult:
    """Container for validation results"""
    is_valid: bool
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    
    def add_error(self, message: str) -> None:
        """Add error and mark as invalid"""
        self.errors.append(message)
        self.is_valid = False
    
    def add_warning(self, message: str) -> None:
        """Add warning (doesn't invalidate)"""
        self.warnings.append(message)
```

**Why separate errors and warnings?**
- **Errors**: Must fix (blocking)
- **Warnings**: Should investigate (non-blocking)

Example:
```
Error: "Missing required column 'user_id'" → STOP
Warning: "Only 10 users in dataset (expected >100)" → PROCEED WITH CAUTION
```

#### Helper: Require Columns

```python
def _require_columns(df: pd.DataFrame, required: List[str], result: ValidationResult, entity: str) -> None:
    """Check if required columns exist"""
    missing = set(required) - set(df.columns)
    if missing:
        result.add_error(f"{entity}: Missing required columns {missing}")
```

**Usage**:
```python
result = ValidationResult(is_valid=True)
_require_columns(users_df, ['user_id', 'signup_date'], result, "users")

# If missing: result.is_valid = False, result.errors = ["users: Missing required columns {'signup_date'}"]
```

#### Helper: Date Parsing

```python
def _as_date(value: Any) -> Optional[date]:
    """Parse string/datetime to date object"""
    if pd.isna(value):
        return None
    if isinstance(value, date):
        return value
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, str):
        return datetime.fromisoformat(value.split()[0]).date()
    return None

def _as_datetime(value: Any) -> Optional[datetime]:
    """Parse string/date to datetime object"""
    if pd.isna(value):
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, date):
        return datetime.combine(value, datetime.min.time())
    if isinstance(value, str):
        return datetime.fromisoformat(value)
    return None
```

**Why robust parsing?**
- Pandas reads dates differently (string vs datetime64)
- Need consistent format for comparisons
- Gracefully handle None/NaN

#### Main Function: Validate Users

```python
def validate_users(df: pd.DataFrame) -> ValidationResult:
    """
    Validate users.csv data
    
    Checks:
    1. Schema: Required columns exist
    2. Integrity: No nulls in critical fields
    3. Business Rules: Valid plans, countries
    """
    result = ValidationResult(is_valid=True)
    
    # ========== SCHEMA VALIDATION ==========
    required_cols = ["user_id", "signup_date", "plan", "is_paid", "country", "marketing_source"]
    _require_columns(df, required_cols, result, "users")
    
    if not result.is_valid:
        return result  # Stop if schema is broken
    
    # ========== INTEGRITY VALIDATION ==========
    # Check for null user_ids
    null_ids = df["user_id"].isna().sum()
    if null_ids > 0:
        result.add_error(f"users: Found {null_ids} rows with null user_id")
    
    # Check for duplicate user_ids
    duplicates = df["user_id"].duplicated().sum()
    if duplicates > 0:
        result.add_error(f"users: Found {duplicates} duplicate user_id values")
    
    # Check signup_date is parseable
    try:
        signup_dates = df["signup_date"].apply(_as_date)
        null_dates = signup_dates.isna().sum()
        if null_dates > 0:
            result.add_error(f"users: {null_dates} rows have invalid signup_date")
    except Exception as e:
        result.add_error(f"users: Error parsing signup_date: {e}")
    
    # ========== BUSINESS RULE VALIDATION ==========
    # Check plan values
    valid_plans = {"free", "paid"}
    invalid_plans = set(df["plan"]) - valid_plans
    if invalid_plans:
        result.add_error(f"users: Invalid plan values {invalid_plans}")
    
    # Check is_paid matches plan
    mismatches = ((df["plan"] == "paid") != (df["is_paid"] == 1)).sum()
    if mismatches > 0:
        result.add_warning(f"users: {mismatches} rows have plan/is_paid mismatch")
    
    # Check country codes (2-letter ISO)
    invalid_countries = df[df["country"].str.len() != 2]
    if len(invalid_countries) > 0:
        result.add_warning(f"users: {len(invalid_countries)} rows have invalid country codes")
    
    # Check dataset size
    if len(df) < 10:
        result.add_warning(f"users: Only {len(df)} rows (expected >10 for meaningful training)")
    
    return result
```

**Key Points**:
- **Early return**: If schema fails, don't bother with other checks
- **Granular errors**: "Found 5 duplicate user_id" (not just "data invalid")
- **Warnings for suspicious** (not blocking): size too small, mismatches

#### Main Function: Validate Events

```python
def validate_events(df: pd.DataFrame) -> ValidationResult:
    """
    Validate events.csv data
    
    Checks:
    1. Schema: Required columns exist
    2. Integrity: Valid timestamps, no future events
    3. Business Rules: Valid event types, realistic watch_minutes
    """
    result = ValidationResult(is_valid=True)
    
    # ========== SCHEMA VALIDATION ==========
    required_cols = ["event_id", "user_id", "event_time", "event_type", "event_date"]
    _require_columns(df, required_cols, result, "events")
    
    if not result.is_valid:
        return result
    
    # ========== INTEGRITY VALIDATION ==========
    # Check for null event_ids
    null_ids = df["event_id"].isna().sum()
    if null_ids > 0:
        result.add_error(f"events: Found {null_ids} rows with null event_id")
    
    # Check for duplicate event_ids
    duplicates = df["event_id"].duplicated().sum()
    if duplicates > 0:
        result.add_error(f"events: Found {duplicates} duplicate event_id values")
    
    # Check event_time is parseable
    try:
        event_times = df["event_time"].apply(_as_datetime)
        null_times = event_times.isna().sum()
        if null_times > 0:
            result.add_error(f"events: {null_times} rows have invalid event_time")
        
        # Check no future events
        now = datetime.now()
        future_events = (event_times > now).sum()
        if future_events > 0:
            result.add_error(f"events: {future_events} events are in the future")
    except Exception as e:
        result.add_error(f"events: Error parsing event_time: {e}")
    
    # ========== BUSINESS RULE VALIDATION ==========
    # Check event_type values
    EVENT_TYPES = {
        "login", "course_enroll", "video_watch", "quiz_attempt",
        "payment_success", "payment_failed", "support_ticket"
    }
    invalid_types = set(df["event_type"]) - EVENT_TYPES
    if invalid_types:
        result.add_error(f"events: Invalid event_type values {invalid_types}")
    
    # Check watch_minutes (if present)
    if "watch_minutes" in df.columns:
        watch_df = df[df["event_type"] == "video_watch"]
        
        # Cannot be negative
        negative_watch = (watch_df["watch_minutes"] < 0).sum()
        if negative_watch > 0:
            result.add_error(f"events: {negative_watch} video_watch events have negative watch_minutes")
        
        # Cannot exceed 24 hours (1440 minutes)
        excessive_watch = (watch_df["watch_minutes"] > 1440).sum()
        if excessive_watch > 0:
            result.add_warning(f"events: {excessive_watch} video_watch events exceed 24 hours")
    
    # Check quiz_score range (if present)
    if "quiz_score" in df.columns:
        quiz_df = df[df["event_type"] == "quiz_attempt"]
        
        invalid_scores = quiz_df[(quiz_df["quiz_score"] < 0) | (quiz_df["quiz_score"] > 100)]
        if len(invalid_scores) > 0:
            result.add_error(f"events: {len(invalid_scores)} quiz_attempt events have invalid scores (must be 0-100)")
    
    # Check payment amounts (if present)
    if "amount" in df.columns:
        payment_df = df[df["event_type"].isin(["payment_success", "payment_failed"])]
        
        negative_amounts = (payment_df["amount"] < 0).sum()
        if negative_amounts > 0:
            result.add_error(f"events: {negative_amounts} payment events have negative amounts")
    
    return result
```

**Key Points**:
- **Type-specific validation**: Only check `watch_minutes` for `video_watch` events
- **Future events check**: Catches time zone issues, incorrect timestamps
- **Range validation**: Realistic bounds (0-100 for quiz, 0-1440 for watch)

---

## Schema Validation

### What is Schema?

**Schema** = The structure of your data (columns, types, constraints)

```python
# Expected schema for users.csv
USERS_SCHEMA = {
    "user_id": int,
    "signup_date": str,  # or datetime
    "plan": str,
    "is_paid": int,
    "country": str,
    "marketing_source": str,
}
```

### Column Existence Check

```python
def _require_columns(df: pd.DataFrame, required: List[str], result: ValidationResult, entity: str):
    missing = set(required) - set(df.columns)
    if missing:
        result.add_error(f"{entity}: Missing required columns {missing}")
```

**Test Case**:
```python
# Good data
df = pd.DataFrame({"user_id": [1, 2], "plan": ["free", "paid"]})
result = ValidationResult(is_valid=True)
_require_columns(df, ["user_id", "plan"], result, "users")
assert result.is_valid  # ✅

# Bad data (missing 'plan')
df = pd.DataFrame({"user_id": [1, 2]})
result = ValidationResult(is_valid=True)
_require_columns(df, ["user_id", "plan"], result, "users")
assert not result.is_valid  # ❌
assert "Missing required columns {'plan'}" in result.errors[0]
```

### Data Type Check (Optional Enhancement)

```python
# Not in current code, but useful extension:
def _check_types(df: pd.DataFrame, schema: Dict[str, type], result: ValidationResult):
    for col, expected_type in schema.items():
        actual_type = df[col].dtype
        if not np.issubdtype(actual_type, expected_type):
            result.add_error(f"Column '{col}' has type {actual_type}, expected {expected_type}")
```

---

## Integrity Validation

### What is Integrity?

**Integrity** = Internal consistency (no duplicates, no nulls, foreign keys valid)

### Check for Nulls

```python
# Critical columns cannot be null
null_ids = df["user_id"].isna().sum()
if null_ids > 0:
    result.add_error(f"Found {null_ids} rows with null user_id")
```

**Why this matters**:
- `user_id` is primary key → must be unique & non-null
- Null user_id → cannot join with events → breaks pipeline

### Check for Duplicates

```python
duplicates = df["user_id"].duplicated().sum()
if duplicates > 0:
    result.add_error(f"Found {duplicates} duplicate user_id values")
```

**Example of duplicate problem**:
```
user_id | signup_date
--------|------------
1       | 2025-01-01
2       | 2025-01-02
1       | 2025-01-03  ← DUPLICATE!

# Which signup_date is correct? Both? Neither?
# ML model will see conflicting records → unstable predictions
```

### Foreign Key Check

```python
def validate_referential_integrity(users_df: pd.DataFrame, events_df: pd.DataFrame) -> ValidationResult:
    """Check that events reference valid users"""
    result = ValidationResult(is_valid=True)
    
    users_in_events = set(events_df['user_id'])
    users_in_users = set(users_df['user_id'])
    
    # Orphan events (user doesn't exist)
    orphans = users_in_events - users_in_users
    if orphans:
        result.add_error(f"Events reference non-existent users: {orphans}")
    
    return result
```

**Example**:
```
users.csv:
user_id | plan
--------|-----
1       | free
2       | paid

events.csv:
event_id | user_id | event_type
---------|---------|------------
100      | 1       | login
101      | 3       | login  ← ERROR: user 3 doesn't exist!
```

---

## Business Rule Validation

### What are Business Rules?

**Business Rules** = Domain-specific constraints (valid enums, realistic ranges)

### Enum Validation

```python
# Check plan values
valid_plans = {"free", "paid"}
invalid_plans = set(df["plan"]) - valid_plans
if invalid_plans:
    result.add_error(f"Invalid plan values {invalid_plans}")
```

**Why this matters**:
- Model trained on `{"free", "paid"}`
- Production sees `"premium"` → model breaks (unknown category)

### Range Validation

```python
# Check watch_minutes (cannot exceed 24 hours)
excessive_watch = (watch_df["watch_minutes"] > 1440).sum()
if excessive_watch > 0:
    result.add_warning(f"{excessive_watch} video_watch events exceed 24 hours")
```

**Why warnings (not errors)?**:
- Maybe user left video playing overnight
- Suspicious but not impossible
- Flag for investigation (not blocking)

### Logical Consistency

```python
# Check signup_date vs last_activity_date
invalid = (df["signup_date"] > df["last_activity_date"]).sum()
if invalid > 0:
    result.add_error(f"{invalid} users have signup_date after last_activity_date")
```

---

## Validation Reports

### Creating Human-Readable Reports

```python
def print_validation_report(result: ValidationResult, entity: str):
    """Print formatted validation report"""
    print(f"\n{'='*60}")
    print(f"Validation Report: {entity}")
    print(f"{'='*60}")
    
    if result.is_valid:
        print("✅ Status: PASSED")
    else:
        print("❌ Status: FAILED")
    
    if result.errors:
        print(f"\n🔴 Errors ({len(result.errors)}):")
        for i, error in enumerate(result.errors, 1):
            print(f"  {i}. {error}")
    
    if result.warnings:
        print(f"\n🟡 Warnings ({len(result.warnings)}):")
        for i, warning in enumerate(result.warnings, 1):
            print(f"  {i}. {warning}")
    
    print(f"{'='*60}\n")

# Usage
users_df = pd.read_csv("data/raw/users.csv")
result = validate_users(users_df)
print_validation_report(result, "Users Data")
```

**Example Output**:
```
============================================================
Validation Report: Users Data
============================================================
❌ Status: FAILED

🔴 Errors (2):
  1. users: Found 3 rows with null user_id
  2. users: Invalid plan values {'premium', 'trial'}

🟡 Warnings (1):
  1. users: 15 rows have plan/is_paid mismatch
============================================================
```

---

## Integration with Pipelines

### Pipeline Stage: Validate → Process → Train

```python
# scripts/prepare_data.sh
#!/bin/bash
set -e  # Exit on any error

echo "Step 1: Validate raw data..."
python -m churn_mlops.data.validate --input data/raw/ || {
    echo "❌ Validation failed! Cannot proceed."
    exit 1
}

echo "✅ Validation passed!"
echo "Step 2: Prepare dataset..."
python -m churn_mlops.data.prepare_dataset

echo "Step 3: Build features..."
python -m churn_mlops.features.build_features
```

### Python Pipeline with Validation

```python
def run_data_pipeline():
    """Run full data pipeline with validation gates"""
    
    # Load raw data
    users = pd.read_csv("data/raw/users.csv")
    events = pd.read_csv("data/raw/events.csv")
    
    # GATE 1: Validate raw data
    users_result = validate_users(users)
    events_result = validate_events(events)
    
    if not users_result.is_valid or not events_result.is_valid:
        print_validation_report(users_result, "Users")
        print_validation_report(events_result, "Events")
        raise ValueError("Raw data validation failed!")
    
    # GATE 2: Validate referential integrity
    ref_result = validate_referential_integrity(users, events)
    if not ref_result.is_valid:
        print_validation_report(ref_result, "Referential Integrity")
        raise ValueError("Referential integrity check failed!")
    
    # ✅ All gates passed - proceed with processing
    user_daily = prepare_dataset(users, events)
    
    # GATE 3: Validate processed data
    processed_result = validate_user_daily(user_daily)
    if not processed_result.is_valid:
        raise ValueError("Processed data validation failed!")
    
    return user_daily
```

---

## Hands-On Exercise

### Exercise 1: Run Validation on Generated Data

```bash
# Generate data (if not already done)
python -m churn_mlops.data.generate_synthetic --seed 42

# Run validation
python -c "
import pandas as pd
from churn_mlops.data.validate import validate_users, validate_events

users = pd.read_csv('data/raw/users.csv')
events = pd.read_csv('data/raw/events.csv')

users_result = validate_users(users)
events_result = validate_events(events)

print('Users Valid:', users_result.is_valid)
print('Events Valid:', events_result.is_valid)
"
```

### Exercise 2: Introduce Errors and Detect

```python
import pandas as pd
from churn_mlops.data.validate import validate_users

# Load clean data
users = pd.read_csv('data/raw/users.csv')

# Introduce error: duplicate user_id
users_dirty = pd.concat([users, users.head(5)], ignore_index=True)

# Validate
result = validate_users(users_dirty)
print("Is Valid:", result.is_valid)
print("Errors:", result.errors)

# Expected: "Found 5 duplicate user_id values"
```

### Exercise 3: Introduce Missing Column

```python
# Load clean data
users = pd.read_csv('data/raw/users.csv')

# Drop critical column
users_broken = users.drop(columns=['plan'])

# Validate
result = validate_users(users_broken)
print("Errors:", result.errors)

# Expected: "Missing required columns {'plan'}"
```

### Exercise 4: Test Future Events

```python
import pandas as pd
from datetime import datetime, timedelta
from churn_mlops.data.validate import validate_events

events = pd.read_csv('data/raw/events.csv')

# Add future event
future_date = (datetime.now() + timedelta(days=365)).isoformat()
events.loc[0, 'event_time'] = future_date

# Validate
result = validate_events(events)
print("Errors:", result.errors)

# Expected: "1 events are in the future"
```

### Exercise 5: Build Custom Validator

**Task**: Create validator for `user_daily.csv`

```python
from dataclasses import dataclass, field
from typing import List
import pandas as pd

@dataclass
class ValidationResult:
    is_valid: bool
    errors: List[str] = field(default_factory=list)
    
    def add_error(self, message: str):
        self.errors.append(message)
        self.is_valid = False

def validate_user_daily(df: pd.DataFrame) -> ValidationResult:
    """Validate user_daily aggregation table"""
    result = ValidationResult(is_valid=True)
    
    # TODO: Add checks
    # 1. Required columns: user_id, as_of_date, total_logins, total_watch_minutes
    # 2. total_logins >= 0
    # 3. total_watch_minutes >= 0
    # 4. No duplicate (user_id, as_of_date) pairs
    
    # YOUR CODE HERE
    
    return result

# Test it
user_daily = pd.read_csv('data/processed/user_daily.csv')
result = validate_user_daily(user_daily)
print("Valid:", result.is_valid)
```

**Solution** (try first before looking!):
<details>
<summary>Click to reveal solution</summary>

```python
def validate_user_daily(df: pd.DataFrame) -> ValidationResult:
    result = ValidationResult(is_valid=True)
    
    # Check required columns
    required = ["user_id", "as_of_date", "total_logins", "total_watch_minutes"]
    missing = set(required) - set(df.columns)
    if missing:
        result.add_error(f"Missing columns: {missing}")
        return result
    
    # Check non-negative values
    if (df["total_logins"] < 0).any():
        result.add_error("total_logins cannot be negative")
    
    if (df["total_watch_minutes"] < 0).any():
        result.add_error("total_watch_minutes cannot be negative")
    
    # Check for duplicates
    duplicates = df[["user_id", "as_of_date"]].duplicated().sum()
    if duplicates > 0:
        result.add_error(f"Found {duplicates} duplicate (user_id, as_of_date) pairs")
    
    return result
```
</details>

---

## Assessment Questions

### Question 1: Multiple Choice
What is the "fail-fast" philosophy?

A) Continue processing even if data is invalid  
B) **Detect errors early and stop immediately** ✅  
C) Log errors but don't fail the pipeline  
D) Only validate production data, not training data  

**Explanation**: Fail-fast means stop as soon as an error is detected, preventing propagation.

---

### Question 2: True/False
**Statement**: Warnings should cause the pipeline to fail.

**Answer**: False ❌  
**Explanation**: Warnings are non-blocking alerts (investigate but don't stop). Errors are blocking.

---

### Question 3: Short Answer
Why do we validate raw data BEFORE processing?

**Answer**:
- Catch errors early (fail-fast)
- Avoid wasting compute on bad data
- Clear error messages (not vague "processing failed")
- Prevents garbage data from reaching model

---

### Question 4: Code Analysis
What does this validation check?

```python
duplicates = df["user_id"].duplicated().sum()
if duplicates > 0:
    result.add_error(f"Found {duplicates} duplicate user_id values")
```

**Answer**:
- Checks for duplicate `user_id` values (violates primary key constraint)
- Duplicates cause ambiguity (which record is correct?)
- Errors reported as count of duplicates

---

### Question 5: Design Challenge
You discover 20% of events have `watch_minutes = 0`. Should this be an error, warning, or ignored?

**Answer**:
- **Warning** (not error)  
- Reason: User might open video but not watch (valid behavior)
- But 20% is suspiciously high → investigate
- Don't block pipeline, but alert data team

---

## Key Takeaways

### ✅ What You Learned

1. **Fail-Fast Philosophy**
   - Detect errors early
   - Stop immediately (don't propagate)
   - Clear, actionable error messages

2. **Three Validation Types**
   - **Schema**: Structure (columns, types)
   - **Integrity**: Consistency (no duplicates, valid FKs)
   - **Business Rules**: Domain logic (valid enums, realistic ranges)

3. **ValidationResult Pattern**
   - Separate errors (blocking) from warnings (alerts)
   - Accumulate multiple issues (not just first one)
   - Human-readable reports

4. **Pipeline Integration**
   - Validate at every stage (raw → processed → features)
   - Use `set -e` in bash scripts (exit on error)
   - Raise exceptions on validation failure

5. **Code Structure**
   - `validate_users()`: Check users.csv
   - `validate_events()`: Check events.csv
   - `_require_columns()`: Reusable helper
   - `ValidationResult`: Structured error reporting

---

## Next Steps

You now know how to build robust validation gates!

**Next Section**: [Section 06: Data Processing Pipeline](./section-06-data-processing.md)

In the next section, we'll:
- Clean raw data
- Build aggregation tables (user_daily)
- Implement temporal grids
- Optimize pandas performance

---

## Additional Resources

### Data Quality:
- [Great Expectations](https://greatexpectations.io/) - Advanced validation framework
- [Pandera](https://pandera.readthedocs.io/) - Schema validation for pandas
- [Pydantic](https://pydantic-docs.helpmanual.io/) - Data validation using Python type hints

### Testing Data Pipelines:
- [Testing Data Pipelines (Databricks)](https://databricks.com/blog/2019/09/11/testing-data-engineering-pipelines.html)
- [Data Pipeline Testing Best Practices](https://towardsdatascience.com/data-pipeline-testing-best-practices-7f5a8c3a5d6f)

---

**🎉 Congratulations!** You've completed Section 05!

Next: **[Section 06: Data Processing Pipeline](./section-06-data-processing.md)** →
