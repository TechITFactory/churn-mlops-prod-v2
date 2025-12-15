# Section 04: Data Architecture & Design

**Duration**: 2 hours  
**Level**: Beginner to Intermediate  
**Prerequisites**: Sections 01-03

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand e-learning platform data model
- ✅ Design entity-relationship diagrams for ML
- ✅ Master synthetic data generation techniques
- ✅ Understand realistic behavior simulation
- ✅ Apply data versioning strategies
- ✅ Recognize patterns in time-series data

---

## 📚 Table of Contents

1. [E-Learning Data Model](#e-learning-data-model)
2. [Entity-Relationship Diagram](#entity-relationship-diagram)
3. [Synthetic Data Generation](#synthetic-data-generation)
4. [Code Walkthrough: generate_synthetic.py](#code-walkthrough)
5. [Realistic Behavior Simulation](#realistic-behavior-simulation)
6. [Data Versioning Strategies](#data-versioning-strategies)
7. [Hands-On Exercise](#hands-on-exercise)
8. [Assessment Questions](#assessment-questions)

---

## E-Learning Data Model

### The Business Context

**TechITFactory** is an e-learning platform where:
- Users sign up (free or paid plans)
- Users enroll in courses (k8s-mastery, devops-warrior, etc.)
- Users watch videos, take quizzes, make payments
- Some users **churn** (stop engaging)

### Core Entities

```
┌─────────────┐
│   USERS     │  - Who are they?
└─────────────┘
      │
      │ 1:N
      ↓
┌─────────────┐
│   EVENTS    │  - What do they do?
└─────────────┘
```

#### Users Table Schema

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| user_id | int | Unique identifier | 12345 |
| signup_date | date | When they joined | 2025-01-01 |
| plan | string | Subscription type | free, paid |
| is_paid | int | 0=free, 1=paid | 1 |
| country | string | User location | IN, US, UK |
| marketing_source | string | How they found us | organic, ads, youtube |
| engagement_score | float | **Synthetic only**: Latent engagement (0-1) | 0.75 |

**Why `engagement_score`?**
- Hidden variable that drives behavior
- High engagement → more activity, less churn
- Used only in **generation**, not in features
- Simulates real-world "user motivation"

#### Events Table Schema

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| event_id | int | Unique event ID | 98765 |
| user_id | int | Foreign key to users | 12345 |
| event_time | datetime | When it happened | 2025-01-15 14:30:00 |
| event_type | string | Action type | login, video_watch, payment_success |
| event_date | date | Date (derived) | 2025-01-15 |
| course_name | string | Which course? | k8s-mastery |
| watch_minutes | float | Video duration | 45.5 |
| quiz_score | float | Quiz result (0-100) | 85.0 |
| amount | float | Payment amount | 999.00 |

**Event Types**:
```python
EVENT_TYPES = [
    "login",              # User logged in
    "course_enroll",      # Enrolled in new course
    "video_watch",        # Watched video
    "quiz_attempt",       # Took quiz
    "payment_success",    # Payment succeeded
    "payment_failed",     # Payment failed (churn signal!)
    "support_ticket",     # Contacted support (churn signal!)
]
```

---

## Entity-Relationship Diagram

### Simplified ERD

```
┌────────────────────────────────┐
│          USERS                 │
├────────────────────────────────┤
│ PK  user_id         INT        │
│     signup_date     DATE       │
│     plan            VARCHAR    │
│     is_paid         INT        │
│     country         VARCHAR    │
│     marketing_source VARCHAR   │
│     engagement_score FLOAT     │ (synthetic only)
└──────────┬─────────────────────┘
           │
           │ 1:N (one user, many events)
           │
           ↓
┌────────────────────────────────┐
│          EVENTS                │
├────────────────────────────────┤
│ PK  event_id        INT        │
│ FK  user_id         INT        │────┐
│     event_time      DATETIME   │    │
│     event_type      VARCHAR    │    │
│     event_date      DATE       │    │
│     course_name     VARCHAR    │    │ References
│     watch_minutes   FLOAT      │    │ USERS.user_id
│     quiz_score      FLOAT      │    │
│     amount          FLOAT      │    │
└────────────────────────────────┘◄───┘

Relationship: One user generates many events over time
```

### Data Flow for ML

```
Raw Data
  │
  ├─> users.csv          (baseline user info)
  └─> events.csv         (time-series activity)
        │
        ↓
  Aggregation: user_daily.csv
        │
        │ (user_id, as_of_date, daily_metrics)
        ↓
  Feature Engineering: user_features_daily.csv
        │
        │ (rolling windows, recency, etc.)
        ↓
  Training: training_dataset.csv
        │
        │ (features + churn_label)
        ↓
  Model Training
```

---

## Synthetic Data Generation

### Why Synthetic Data?

**In production**: You'd use real user data  
**For this course**: We generate realistic synthetic data

**Benefits**:
- ✅ No privacy concerns (PII)
- ✅ Reproducible (with seed)
- ✅ Controllable (adjust churn rate, user count)
- ✅ Free (no data collection costs)

**Realism**:
- Behavior patterns match real e-learning platforms
- Churn signals (payment failures, support tickets)
- Seasonal patterns (weekday/weekend differences)

### Generation Parameters

```python
@dataclass
class GeneratorSettings:
    n_users: int = 1000              # How many users?
    days: int = 180                  # How many days of history?
    start_date: str = "2025-01-01"   # Starting date
    seed: int = 42                   # For reproducibility
    paid_ratio: float = 0.3          # 30% paid users
    churn_base_rate: float = 0.25    # 25% churn rate
    output_dir: str = "data/raw"     # Where to save?
```

---

## Code Walkthrough

### File: `src/churn_mlops/data/generate_synthetic.py`

Let's walk through the key functions:

#### Step 1: Generate Users

```python
def _build_users(rng: np.random.Generator, settings: GeneratorSettings) -> pd.DataFrame:
    """Generate synthetic user base"""
    start_dt = _parse_date(settings.start_date)
    signup_spread_days = max(30, settings.days // 3)
    
    # Sequential user IDs
    user_ids = np.arange(1, settings.n_users + 1)
    
    # Stagger signups over time (realistic growth)
    signup_offsets = rng.integers(0, signup_spread_days, size=settings.n_users)
    signup_dates = [start_dt - timedelta(days=int(x)) for x in signup_offsets]
    
    # 30% paid, 70% free (controlled by paid_ratio)
    is_paid = rng.random(settings.n_users) < settings.paid_ratio
    plan = np.where(is_paid, "paid", "free")
    
    # Random demographics
    countries = _random_choice(rng, ["IN", "US", "UK", "CA", "AU", "SG"], settings.n_users)
    sources = _random_choice(
        rng, ["organic", "referral", "ads", "youtube", "community"], settings.n_users
    )
    
    # CRITICAL: Latent engagement score (Beta distribution)
    # Beta(2, 2.5) gives bell-shaped curve slightly skewed left
    # Higher score = more active, less likely to churn
    engagement = rng.beta(a=2.0, b=2.5, size=settings.n_users)
    
    users = pd.DataFrame({
        "user_id": user_ids,
        "signup_date": [d.date().isoformat() for d in signup_dates],
        "plan": plan,
        "is_paid": is_paid.astype(int),
        "country": countries,
        "marketing_source": sources,
        "engagement_score": engagement,  # Not used in features!
    })
    return users
```

**Key Insights**:
- **Signup spread**: Users don't all join on day 1
- **Beta distribution**: Models engagement realistically
  - Beta(2, 2.5) → Most users moderate engagement
  - Some highly engaged, some disengaged
- **Controlled randomness**: Seed makes it reproducible

#### Step 2: Determine Churn Dates

```python
def _assign_churn_dates(
    rng: np.random.Generator,
    users: pd.DataFrame,
    settings: GeneratorSettings,
) -> Dict[int, Optional[datetime]]:
    """
    Decide when each user churns (or None if they don't).
    
    Logic:
    - Higher engagement → lower churn probability
    - Paid users churn slightly less
    - Some users never churn (active at end)
    """
    start_dt = _parse_date(settings.start_date)
    end_dt = start_dt + timedelta(days=settings.days - 1)
    
    churn_map = {}
    for _, row in users.iterrows():
        uid = int(row["user_id"])
        engagement = row["engagement_score"]
        is_paid = row["is_paid"]
        
        # Adjust churn probability based on engagement
        # High engagement (0.8) → 0.25 * (1 - 0.8) = 0.05 (5% churn)
        # Low engagement (0.2) → 0.25 * (1 - 0.2) = 0.20 (20% churn)
        churn_prob = settings.churn_base_rate * (1 - engagement)
        
        # Paid users get small discount (10% less likely to churn)
        if is_paid:
            churn_prob *= 0.9
        
        if rng.random() < churn_prob:
            # User will churn - pick random date in range
            days_until_churn = rng.integers(7, settings.days - 30)
            churn_date = start_dt + timedelta(days=days_until_churn)
            churn_map[uid] = churn_date if churn_date <= end_dt else None
        else:
            # User stays active (no churn)
            churn_map[uid] = None
    
    return churn_map
```

**Key Insights**:
- Engagement **inversely** correlates with churn
- Paid users more sticky
- Churn happens gradually (not all at once)

#### Step 3: Generate Events

```python
def _generate_events_for_user(
    rng: np.random.Generator,
    user_id: int,
    signup_date: datetime,
    churn_date: Optional[datetime],
    engagement: float,
    is_paid: int,
    start_dt: datetime,
    end_dt: datetime,
) -> List[Dict]:
    """Generate event stream for one user"""
    events = []
    event_id_counter = user_id * 100000  # Unique event IDs
    
    current_dt = max(signup_date, start_dt)
    
    while current_dt <= end_dt:
        # After churn date, user is inactive
        if churn_date and current_dt >= churn_date:
            break
        
        # Daily activity probability (based on engagement)
        # High engagement (0.8) → 0.7 chance of activity
        # Low engagement (0.2) → 0.3 chance of activity
        daily_activity_prob = 0.5 + 0.3 * engagement
        
        # Weekday boost (Mon-Fri more active than Sat-Sun)
        if current_dt.weekday() < 5:  # Monday = 0, Friday = 4
            daily_activity_prob *= 1.2
        
        if rng.random() < daily_activity_prob:
            # User is active today!
            
            # Login (always first event of the day)
            events.append({
                "event_id": event_id_counter,
                "user_id": user_id,
                "event_time": current_dt.replace(hour=rng.integers(7, 23)),
                "event_type": "login",
                "event_date": current_dt.date(),
            })
            event_id_counter += 1
            
            # Additional events (based on engagement)
            num_events = rng.poisson(lam=2.0 * engagement)  # High engagement → more events
            
            for _ in range(num_events):
                event_type = rng.choice([
                    "video_watch",     # Most common
                    "course_enroll",   # Occasional
                    "quiz_attempt",    # Less common
                ])
                
                event_data = {
                    "event_id": event_id_counter,
                    "user_id": user_id,
                    "event_time": current_dt.replace(hour=rng.integers(7, 23)),
                    "event_type": event_type,
                    "event_date": current_dt.date(),
                }
                
                # Add event-specific details
                if event_type == "video_watch":
                    event_data["watch_minutes"] = rng.uniform(5, 60)
                    event_data["course_name"] = rng.choice(COURSE_POOL)
                elif event_type == "quiz_attempt":
                    # Higher engagement → better quiz scores
                    base_score = 50 + 30 * engagement
                    event_data["quiz_score"] = min(100, rng.normal(base_score, 15))
                
                events.append(event_data)
                event_id_counter += 1
        
        current_dt += timedelta(days=1)
    
    # Churn signals near end (if user churned)
    if churn_date:
        # Payment failures (2-4 weeks before churn)
        if is_paid and rng.random() < 0.6:
            fail_date = churn_date - timedelta(days=rng.integers(14, 28))
            events.append({
                "event_id": event_id_counter,
                "user_id": user_id,
                "event_time": fail_date,
                "event_type": "payment_failed",
                "event_date": fail_date.date(),
                "amount": 999.0,
            })
            event_id_counter += 1
        
        # Support tickets (frustration signal)
        if rng.random() < 0.4:
            ticket_date = churn_date - timedelta(days=rng.integers(7, 21))
            events.append({
                "event_id": event_id_counter,
                "user_id": user_id,
                "event_time": ticket_date,
                "event_type": "support_ticket",
                "event_date": ticket_date.date(),
            })
    
    return events
```

**Key Insights**:
- **Poisson distribution** for event count (realistic variability)
- **Weekday/weekend patterns** (humans behave differently)
- **Churn signals**: Payment failures & support tickets before churn
- **Engagement drives everything**: activity frequency, quiz scores

---

## Realistic Behavior Simulation

### What Makes It Realistic?

#### 1. Temporal Patterns

```
Weekday:  █████████████ 80% chance of activity
Weekend:  ████████░░░░░ 60% chance of activity

Before churn:  ████░░░░░░ Activity declines
After churn:   ░░░░░░░░░░ Zero activity
```

#### 2. Engagement Distribution

```
Beta(2, 2.5) Distribution:

Frequency
    │     ╱▔▔╲
    │    ╱    ╲
    │   ╱      ╲___
    │  ╱           ╲___
    └─────────────────────→ Engagement
    0.0    0.5    1.0

Most users: 0.4-0.6 (moderate engagement)
Few users: <0.2 (very disengaged) or >0.8 (power users)
```

#### 3. Event Sequences

**Engaged User** (engagement=0.8):
```
Day 1: login → video_watch(45m) → video_watch(30m) → quiz_attempt(90)
Day 2: login → course_enroll → video_watch(60m)
Day 3: login → video_watch(25m) → video_watch(40m) → quiz_attempt(85)
```

**Disengaged User** (engagement=0.2):
```
Day 1: login
Day 2: (no activity)
Day 3: (no activity)
Day 4: login → video_watch(10m)
Day 5-10: (no activity)
```

#### 4. Churn Signals

**User about to churn**:
```
Week -3: Normal activity
Week -2: payment_failed ← SIGNAL
Week -1: support_ticket ← SIGNAL, declining activity
Week 0:  Zero activity (churned)
```

---

## Data Versioning Strategies

### Why Version Data?

- ✅ **Reproducibility**: Re-run experiments with same data
- ✅ **Debugging**: Compare model trained on v1 vs v2
- ✅ **Compliance**: Audit trail for regulatory requirements

### Versioning Approaches

#### Option 1: Timestamped Directories

```
data/
├── raw/
│   ├── 2025-01-15/
│   │   ├── users.csv
│   │   └── events.csv
│   └── 2025-01-22/
│       ├── users.csv
│       └── events.csv
└── processed/
    ├── 2025-01-15/
    └── 2025-01-22/
```

#### Option 2: DVC (Data Version Control)

```bash
# Track data with DVC
dvc add data/raw/users.csv
git add data/raw/users.csv.dvc

# DVC creates hash-based versioning
# users.csv stored in .dvc/cache/
# Git tracks only metadata
```

#### Option 3: Hash-Based (What We Use)

```python
import hashlib

def hash_dataframe(df: pd.DataFrame) -> str:
    """Generate deterministic hash of dataframe"""
    return hashlib.sha256(
        pd.util.hash_pandas_object(df, index=False).values
    ).hexdigest()[:16]

# Generate data
users, events = generate_synthetic_data(seed=42)

# Version by hash
hash_v = hash_dataframe(pd.concat([users, events]))
output_dir = f"data/raw/{hash_v}/"
```

### Our Approach: Seed-Based Reproducibility

```bash
# Same seed → Same data every time
python -m churn_mlops.data.generate_synthetic --seed 42 --n-users 1000

# Different seed → Different data
python -m churn_mlops.data.generate_synthetic --seed 123 --n-users 1000
```

**Pros**:
- Simple to implement
- No extra storage
- Fully reproducible

**Cons**:
- Must regenerate (not cached)
- Only works for synthetic data

---

## Hands-On Exercise

### Exercise 1: Generate Your First Dataset

```bash
# Activate environment
source .venv/bin/activate

# Generate data (1000 users, 180 days)
python -m churn_mlops.data.generate_synthetic \
    --n-users 1000 \
    --days 180 \
    --seed 42

# Check output
ls -lh data/raw/
head -n 5 data/raw/users.csv
head -n 5 data/raw/events.csv
```

**Questions**:
1. How many rows in users.csv?
2. How many rows in events.csv?
3. What's the date range of events?

### Exercise 2: Analyze Churn Rate

```bash
python -c "
import pandas as pd
users = pd.read_csv('data/raw/users.csv')
events = pd.read_csv('data/raw/events.csv')

# Count users with zero events
last_event = events.groupby('user_id')['event_date'].max()
all_users = set(users['user_id'])
active_users = set(last_event.index)
churned_users = all_users - active_users

churn_rate = len(churned_users) / len(all_users)
print(f'Churn Rate: {churn_rate:.2%}')
print(f'Churned: {len(churned_users)}/{len(all_users)} users')
"
```

### Exercise 3: Custom Generation

**Task**: Generate smaller dataset for testing

```bash
# Quick test dataset
python -m churn_mlops.data.generate_synthetic \
    --n-users 100 \
    --days 30 \
    --seed 999 \
    --output-dir data/raw-test/

# Check size difference
du -sh data/raw/
du -sh data/raw-test/
```

### Exercise 4: Explore Engagement Distribution

```python
import pandas as pd
import matplotlib.pyplot as plt

users = pd.read_csv('data/raw/users.csv')

# Plot engagement score distribution
users['engagement_score'].hist(bins=30, edgecolor='black')
plt.xlabel('Engagement Score')
plt.ylabel('Frequency')
plt.title('User Engagement Distribution (Beta(2, 2.5))')
plt.savefig('engagement_distribution.png')

# Summary statistics
print(users['engagement_score'].describe())
```

---

## Assessment Questions

### Question 1: Multiple Choice
What is the purpose of `engagement_score` in the users table?

A) Used as a feature for model training  
B) **Hidden variable that drives synthetic behavior** ✅  
C) Displayed to users in the app  
D) Calculated from event history  

**Explanation**: It's a latent variable used ONLY in generation, never as a feature (to avoid leakage).

---

### Question 2: True/False
**Statement**: In production ML systems, you should always use synthetic data.

**Answer**: False ❌  
**Explanation**: Synthetic data is for development/testing. Production needs real data. But synthetics are valuable for privacy, testing, and demos.

---

### Question 3: Short Answer
Why do paid users have lower churn rates in the synthetic data?

**Answer**:
- Paid users invested money → more committed
- Code applies 0.9x multiplier to churn probability
- Realistic business assumption

---

### Question 4: Code Analysis
What does this code do?

```python
daily_activity_prob = 0.5 + 0.3 * engagement
if current_dt.weekday() < 5:
    daily_activity_prob *= 1.2
```

**Answer**:
- Base probability 0.5, boosted by engagement (0.0-0.3)
- Weekdays (Mon-Fri) get 20% boost
- Models realistic weekly patterns

---

### Question 5: Design Challenge
You need to generate data for A/B testing (control vs treatment groups). How would you modify `generate_synthetic.py`?

**Answer**:
```python
# Add treatment flag
is_treatment = rng.random(settings.n_users) < 0.5  # 50/50 split
users["treatment_group"] = np.where(is_treatment, "treatment", "control")

# Adjust behavior for treatment (e.g., higher engagement)
if treatment_row["treatment_group"] == "treatment":
    engagement *= 1.1  # 10% boost
```

---

## Key Takeaways

### ✅ What You Learned

1. **E-Learning Data Model**
   - Users (who) + Events (what they do)
   - One-to-many relationship
   - Time-series nature

2. **Synthetic Data Generation**
   - Reproducible with seeds
   - Realistic patterns (weekday/weekend, churn signals)
   - Latent engagement variable drives behavior

3. **Behavior Simulation**
   - Beta distribution for engagement
   - Poisson for event counts
   - Temporal patterns (declining before churn)

4. **Data Versioning**
   - Seed-based reproducibility
   - Hash-based versioning
   - DVC for large-scale projects

5. **Code Structure**
   - `_build_users()`: Generate user base
   - `_assign_churn_dates()`: Determine who churns when
   - `_generate_events_for_user()`: Create event stream

---

## Next Steps

You now understand how data is structured and generated!

**Next Section**: [Section 05: Data Validation Gates](./section-05-data-validation.md)

In the next section, we'll:
- Build quality checks for data
- Implement validation gates
- Prevent bad data from reaching models
- Handle errors gracefully

---

## Additional Resources

### Data Modeling:
- [Dimensional Modeling](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/)
- [Time-Series Data Design](https://www.timescale.com/learn/time-series-data)

### Synthetic Data:
- [SDV: Synthetic Data Vault](https://sdv.dev/)
- [Faker: Generate realistic data](https://faker.readthedocs.io/)

### Statistical Distributions:
- [Beta Distribution](https://en.wikipedia.org/wiki/Beta_distribution)
- [Poisson Distribution](https://en.wikipedia.org/wiki/Poisson_distribution)

---

**🎉 Congratulations!** You've completed Section 04!

Next: **[Section 05: Data Validation Gates](./section-05-data-validation.md)** →
