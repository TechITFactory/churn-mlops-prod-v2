# Section 02: Project Setup & Environment

**Duration**: 1.5 hours  
**Level**: Beginner  
**Prerequisites**: Section 01

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand the complete project structure
- ✅ Set up Python virtual environment
- ✅ Install all dependencies correctly
- ✅ Configure the project settings
- ✅ Run your first ML pipeline command
- ✅ Understand configuration management

---

## 📚 Table of Contents

1. [Repository Structure](#repository-structure)
2. [Python Environment Setup](#python-environment-setup)
3. [Dependencies Explained](#dependencies-explained)
4. [Configuration Management](#configuration-management)
5. [Directory Conventions](#directory-conventions)
6. [Testing Your Setup](#testing-your-setup)
7. [Troubleshooting](#troubleshooting)
8. [Hands-On Exercise](#hands-on-exercise)
9. [Assessment Questions](#assessment-questions)

---

## Repository Structure

### High-Level Overview

```
churn-mlops-prod/
├── src/churn_mlops/          # Main Python package (all ML code)
├── scripts/                  # Shell wrappers for pipeline steps
├── config/                   # YAML configuration files
├── data/                     # Data storage (gitignored)
├── artifacts/                # Model & metrics storage (gitignored)
├── docker/                   # Dockerfiles for containers
├── k8s/                      # Kubernetes manifests
├── .github/workflows/        # CI/CD pipelines
├── argocd/                   # ArgoCD application configs
├── requirements/             # Python dependencies
├── tests/                    # Unit and integration tests
├── course-notes/             # Quick reference guides
├── tutorials/                # This comprehensive course
├── Makefile                  # Common commands shortcuts
├── pyproject.toml            # Python project metadata
└── ruff.toml                 # Linting configuration
```

### The src/ Package Structure

```
src/churn_mlops/
├── __init__.py               # Package marker
├── common/                   # Shared utilities
│   ├── config.py             # ⭐ YAML config loader
│   ├── paths.py              # Project root helper
│   ├── logging.py            # Centralized logging
│   └── utils.py              # Utility functions
├── data/                     # Data pipeline
│   ├── generate_synthetic.py # ⭐ Synthetic data generation
│   ├── validate.py           # ⭐ Data quality gates
│   └── prepare_dataset.py    # ⭐ Data cleaning
├── features/                 # Feature engineering
│   └── build_features.py     # ⭐ Rolling window features
├── training/                 # Model training
│   ├── build_labels.py       # ⭐ Churn label creation
│   ├── build_training_set.py # ⭐ Join features + labels
│   ├── train_baseline.py     # ⭐ Baseline model training
│   ├── train_candidate.py    # ⭐ Candidate model training
│   └── promote_model.py      # ⭐ Model promotion
├── inference/                # Prediction
│   └── batch_score.py        # ⭐ Batch scoring
├── monitoring/               # Observability
│   ├── api_metrics.py        # ⭐ Prometheus metrics
│   ├── drift.py              # ⭐ Drift detection (PSI)
│   ├── run_drift_check.py    # Drift check runner
│   └── run_score_proxy.py    # Score proxy runner
└── api/                      # Serving layer
    └── app.py                # ⭐ FastAPI application
```

**⭐ = Core files we'll study in detail**

---

## Python Environment Setup

### Step 1: Check Python Version

```bash
python --version
# Required: Python 3.10 or higher
```

**Why Python 3.10+?**
- Modern type hints support
- Better performance
- Latest scikit-learn features
- FastAPI compatibility

### Step 2: Create Virtual Environment

```bash
# Navigate to project root
cd churn-mlops-prod

# Create virtual environment
python -m venv .venv

# Activate (Linux/macOS)
source .venv/bin/activate

# Activate (Windows)
.venv\Scripts\activate

# Verify activation (should show .venv path)
which python  # Linux/macOS
where python  # Windows
```

**Why Virtual Environment?**
- ✅ Isolates project dependencies
- ✅ Prevents version conflicts
- ✅ Reproducible across machines
- ✅ Easy to clean/recreate

### Step 3: Upgrade pip

```bash
pip install --upgrade pip
# Latest pip has better dependency resolution
```

### Step 4: Install Dependencies

```bash
# Install base dependencies (ML libraries)
pip install -r requirements/base.txt

# Install development dependencies (testing, linting)
pip install -r requirements/dev.txt

# Install API dependencies (FastAPI, uvicorn)
pip install -r requirements/api.txt

# Install package in editable mode
pip install -e .
```

**What is `-e .`?**
- Installs package in "editable" mode
- Changes to code immediately reflected
- No need to reinstall after edits
- Creates `churn_mlops.egg-info/` directory

---

## Dependencies Explained

### requirements/base.txt

```text
numpy>=1.26              # Numerical computing
pandas>=2.1              # Data manipulation
scikit-learn>=1.3        # Machine learning
imbalanced-learn>=0.11   # Handling class imbalance
pydantic>=2.5            # Data validation
PyYAML>=6.0              # YAML config parsing
joblib>=1.3              # Model serialization
python-dotenv>=1.0       # Environment variables
```

**Why these libraries?**
- **pandas**: Data wrangling, CSV I/O
- **scikit-learn**: Model training, pipelines
- **imbalanced-learn**: SMOTE, class_weight
- **pydantic**: Type-safe config, validation
- **joblib**: Efficient model pickling

### requirements/dev.txt

```text
-r runtime.txt           # Includes base dependencies
-r api.txt               # Includes API dependencies
pytest>=7.0              # Testing framework
ruff>=0.5                # Fast Python linter
black>=24.0              # Code formatter
```

**Why these tools?**
- **pytest**: Write and run tests
- **ruff**: 10-100x faster than flake8/pylint
- **black**: Auto-format code consistently

### requirements/api.txt

```text
fastapi>=0.110           # Web framework
uvicorn>=0.23            # ASGI server
prometheus-client>=0.20  # Metrics exporter
```

**Why FastAPI?**
- ⚡ Fast (async/await)
- 🎯 Type hints = auto validation
- 📚 Auto-generated docs
- 🔧 Easy testing

---

## Configuration Management

### File: config/config.yaml

```yaml
app:
  name: churn-mlops
  env: dev
  log_level: INFO

paths:
  data: /app/data                    # Container path
  raw: /app/data/raw
  processed: /app/data/processed
  features: /app/data/features
  predictions: /app/data/predictions
  artifacts: /app/artifacts          # Models & metrics
  models: /app/artifacts/models
  metrics: /app/artifacts/metrics

features:
  windows_days: [7, 14, 30]          # Rolling windows
  
training:
  test_size: 0.2                     # 20% test set
  random_state: 42                   # Reproducibility
  imbalance_strategy: class_weight   # Handle imbalance

inference:
  batch_size: 1000                   # Batch scoring
  score_threshold: 0.7               # High-risk threshold
```

### How It Works: config.py

```python
# src/churn_mlops/common/config.py

def load_config(config_path: str | None = None) -> dict:
    """
    Load YAML config with environment variable substitution.
    
    Example:
        paths:
          data: ${CHURN_DATA_DIR:/app/data}
          
    If CHURN_DATA_DIR env var is set, use it. 
    Otherwise, use default /app/data
    """
    if config_path is None:
        # Default to config/config.yaml
        config_path = str(PROJECT_ROOT / "config" / "config.yaml")
    
    with open(config_path) as f:
        config = yaml.safe_load(f)
    
    # Recursively substitute ${VAR:default} patterns
    return _substitute_env_vars(config)
```

**Environment Variable Override Example:**
```bash
# Override data path for local testing
export CHURN_DATA_DIR=/tmp/churn-data

# Now config will use /tmp/churn-data instead of /app/data
python -m churn_mlops.data.generate_synthetic
```

---

## Directory Conventions

### Data Directories (Auto-created)

```
data/
├── raw/                 # Source data (users.csv, events.csv)
├── processed/           # Cleaned data (user_daily.csv, labels_daily.csv)
├── features/            # Feature tables (user_features_daily.csv, training_dataset.csv)
└── predictions/         # Batch scores (predictions_YYYY-MM-DD.csv)
```

### Artifacts Directories

```
artifacts/
├── models/              # Model files (.joblib)
│   ├── baseline_logreg_20250115_120000.joblib
│   ├── candidate_hgb_20250120_150000.joblib
│   └── production_latest.joblib  # Symlink/copy to current production model
└── metrics/             # Metrics files (.json)
    ├── baseline_logreg_20250115_120000.json
    └── candidate_hgb_20250120_150000.json
```

**File Naming Convention:**
```
{model_type}_{timestamp}.{extension}

Examples:
- baseline_logreg_20250115_120000.joblib
- candidate_hgb_20250115_120000.joblib
- drift_report_20250115.json
```

---

## Testing Your Setup

### 1. Verify Installation

```bash
# Check installed packages
pip list | grep -E "(pandas|sklearn|fastapi)"

# Expected output:
# fastapi          0.110.0
# pandas           2.1.0
# scikit-learn     1.3.0
```

### 2. Test Package Import

```bash
python -c "from churn_mlops.common.config import load_config; print('✅ Import successful')"
```

### 3. Run Linting

```bash
make lint
# Should show: "All checks passed!"
```

### 4. Run Tests

```bash
make test
# Should show: "X passed in Y seconds"
```

### 5. Generate First Data

```bash
# This creates data/raw/users.csv and data/raw/events.csv
./scripts/generate_data.sh

# Check output
ls -lh data/raw/
```

**Expected Output:**
```
-rw-r--r--  1 user  staff   2.1M Jan 15 12:00 events.csv
-rw-r--r--  1 user  staff    45K Jan 15 12:00 users.csv
```

### 6. Run Full Pipeline

```bash
make all
# Runs: data → features → labels → train → batch → test → lint
```

---

## Troubleshooting

### Issue: Python version too old

```bash
# Error: Python 3.9 detected, need 3.10+

# Solution: Install Python 3.10+
# - Linux: sudo apt install python3.10
# - macOS: brew install python@3.10
# - Windows: Download from python.org
```

### Issue: Permission denied on scripts

```bash
# Error: ./scripts/generate_data.sh: Permission denied

# Solution: Make scripts executable
chmod +x scripts/*.sh
```

### Issue: Module not found

```bash
# Error: ModuleNotFoundError: No module named 'churn_mlops'

# Solution: Install package in editable mode
pip install -e .
```

### Issue: Config file not found

```bash
# Error: FileNotFoundError: config/config.yaml

# Solution: Verify you're in project root
pwd  # Should show /path/to/churn-mlops-prod

# Or set CHURN_MLOPS_CONFIG env var
export CHURN_MLOPS_CONFIG=/full/path/to/config.yaml
```

### Issue: Import errors after editing code

```bash
# If you edited Python files but changes not reflected:

# 1. Check if installed in editable mode
pip show churn-mlops | grep Location
# Should show: Location: /path/to/churn-mlops-prod

# 2. Reinstall if needed
pip install -e .

# 3. Restart Python interpreter
```

---

## Hands-On Exercise

### Exercise 1: Setup Checklist

Complete these steps and verify each:

```bash
# ☐ 1. Clone repository
git clone https://github.com/Dhananjaiah/churn-mlops-prod.git
cd churn-mlops-prod

# ☐ 2. Create virtual environment
python -m venv .venv
source .venv/bin/activate

# ☐ 3. Install dependencies
pip install -r requirements/dev.txt
pip install -e .

# ☐ 4. Run tests
make test

# ☐ 5. Generate data
./scripts/generate_data.sh

# ☐ 6. Check data created
ls data/raw/
```

### Exercise 2: Explore the Config

```bash
# 1. View the config
cat config/config.yaml

# 2. Override a path with environment variable
export CHURN_DATA_DIR=/tmp/my-data

# 3. Test that it's used
python -c "
from churn_mlops.common.config import load_config
config = load_config()
print(f'Data path: {config[\"paths\"][\"data\"]}')
"

# Expected: Data path: /tmp/my-data
```

### Exercise 3: Navigate the Codebase

Find and open these files:

1. **Config loader**: `src/churn_mlops/common/config.py`
2. **Data generator**: `src/churn_mlops/data/generate_synthetic.py`
3. **API app**: `src/churn_mlops/api/app.py`
4. **Makefile**: `Makefile` (see available commands)

---

## Assessment Questions

### Question 1: Multiple Choice
What is the purpose of `pip install -e .`?

A) Install package normally  
B) **Install package in editable mode** ✅  
C) Install from PyPI  
D) Install dependencies  

**Explanation**: `-e` means editable. Code changes take effect immediately without reinstalling.

---

### Question 2: True/False
**Statement**: The `data/` and `artifacts/` directories should be committed to Git.

**Answer**: False ❌  
**Explanation**: These contain generated data and models (large files). They're in `.gitignore`. Only code and configs go in Git.

---

### Question 3: Fill in the Blank
The main Python package is located in ______ directory.

**Answer**: `src/churn_mlops/`

---

### Question 4: Matching
Match the file to its purpose:

| File | Purpose |
|------|---------|
| 1. requirements/base.txt | A. Testing & linting tools |
| 2. requirements/dev.txt | B. Web framework & server |
| 3. requirements/api.txt | C. ML libraries |

**Answer**: 1-C, 2-A, 3-B

---

### Question 5: Short Answer
Why do we use virtual environments in Python projects?

**Answer**:
- Isolate dependencies per project
- Prevent version conflicts between projects
- Make environment reproducible
- Easy to recreate or delete

---

## Key Takeaways

### ✅ What You Learned

1. **Project Structure**
   - `src/churn_mlops/`: All Python code
   - `scripts/`: Shell wrappers
   - `config/`: YAML configs
   - `data/` & `artifacts/`: Generated files

2. **Environment Setup**
   - Virtual environment for isolation
   - Editable install (`pip install -e .`)
   - Separate requirements files (base, dev, api)

3. **Configuration Management**
   - YAML for config
   - Environment variable overrides
   - Container-friendly paths

4. **Directory Conventions**
   - `data/raw/` → `data/processed/` → `data/features/`
   - `artifacts/models/` for model files
   - Timestamped file naming

5. **Testing Setup**
   - `make test` runs pytest
   - `make lint` checks code quality
   - `make all` runs full pipeline

---

## Next Steps

You now have a working development environment!

**Next Section**: [Section 03: Understanding the Business Problem](./section-03-business-problem.md)

In the next section, we'll:
- Deep dive into churn prediction
- Understand the business metrics
- Learn about e-learning user behavior
- Define success criteria

---

## Additional Resources

### Project Setup:
- [Python Virtual Environments Guide](https://docs.python.org/3/tutorial/venv.html)
- [pip Editable Installs](https://pip.pypa.io/en/stable/topics/local-project-installs/#editable-installs)
- [YAML Syntax](https://yaml.org/spec/1.2.2/)

### Tools Documentation:
- [pytest](https://docs.pytest.org/)
- [ruff](https://docs.astral.sh/ruff/)
- [black](https://black.readthedocs.io/)

---

**🎉 Congratulations!** You've completed Section 02!

Next: **[Section 03: Understanding the Business Problem](./section-03-business-problem.md)** →
