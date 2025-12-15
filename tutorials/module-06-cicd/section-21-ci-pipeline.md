# Section 21: CI Pipeline - Testing, Linting, Security

**Duration**: 3 hours  
**Level**: Intermediate  
**Prerequisites**: Section 20 (GitHub Actions Fundamentals)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Build complete CI pipeline with GitHub Actions
- ✅ Implement automated testing strategies
- ✅ Add code quality checks (linting, formatting)
- ✅ Integrate security scanning
- ✅ Validate Docker builds
- ✅ Generate test coverage reports
- ✅ Configure PR checks and branch protection

---

## 📚 Table of Contents

1. [CI Pipeline Overview](#ci-pipeline-overview)
2. [Testing Strategy](#testing-strategy)
3. [Code Quality Checks](#code-quality-checks)
4. [Security Scanning](#security-scanning)
5. [Docker Build Validation](#docker-build-validation)
6. [Test Coverage](#test-coverage)
7. [Branch Protection](#branch-protection)
8. [Code Walkthrough](#code-walkthrough)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## CI Pipeline Overview

### What is Continuous Integration?

> **CI**: Automatically build, test, and validate code on every commit

```
Developer Workflow:

1. Write code
   ↓
2. Commit + Push
   ↓
3. CI Pipeline Runs
   ├── Lint code
   ├── Run tests
   ├── Security scan
   └── Build validation
   ↓
4. ✅ Pass → Merge allowed
   ❌ Fail → Fix issues
```

### CI Pipeline for MLOps

```
┌─────────────────────────────────────────────────────────┐
│              CI Pipeline (on PR to main)                 │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Stage 1: Code Quality (parallel)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  Lint        │  │  Format      │  │  Type Check  │ │
│  │  (Ruff)      │  │  (Black)     │  │  (MyPy)      │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  Stage 2: Testing (parallel)                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  Unit Tests  │  │  Integration │  │  Data Tests  │ │
│  │  (pytest)    │  │  Tests       │  │  (Great Exp.)│ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  Stage 3: Security (parallel)                           │
│  ┌──────────────┐  ┌──────────────┐                   │
│  │  Dependency  │  │  Code Scan   │                   │
│  │  (Safety)    │  │  (Bandit)    │                   │
│  └──────────────┘  └──────────────┘                   │
│                                                          │
│  Stage 4: Build Validation                              │
│  ┌──────────────┐  ┌──────────────┐                   │
│  │  Docker ML   │  │  Docker API  │                   │
│  │  (no push)   │  │  (no push)   │                   │
│  └──────────────┘  └──────────────┘                   │
│                                                          │
│  All stages pass → ✅ Merge allowed                     │
└─────────────────────────────────────────────────────────┘
```

---

## Testing Strategy

### Test Pyramid for MLOps

```
         ┌───────────────┐
        /  E2E Tests      \ ← Few (slow, expensive)
       /   (API + Model)  \
      /─────────────────────\
     /  Integration Tests   \ ← Some (medium speed)
    /   (Pipeline, Data)    \
   /─────────────────────────\
  /      Unit Tests          \ ← Many (fast, cheap)
 /  (Functions, Classes)     \
/─────────────────────────────\
```

### Unit Tests

> **Unit Tests**: Test individual functions/classes in isolation

```python
# tests/unit/test_features.py
import pytest
import pandas as pd
from churn_mlops.features.engineering import create_rolling_features

def test_create_rolling_features():
    """Test rolling feature creation."""
    # Arrange
    df = pd.DataFrame({
        'user_id': ['user1'] * 10,
        'date': pd.date_range('2023-01-01', periods=10),
        'logins': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    })
    
    # Act
    result = create_rolling_features(df, windows=[3, 7])
    
    # Assert
    assert 'logins_3d' in result.columns
    assert 'logins_7d' in result.columns
    assert result['logins_3d'].iloc[2] == 6  # 1+2+3
    assert result['logins_7d'].iloc[6] == 28  # 1+2+3+4+5+6+7

def test_rolling_features_empty_data():
    """Test with empty dataframe."""
    df = pd.DataFrame(columns=['user_id', 'date', 'logins'])
    
    result = create_rolling_features(df, windows=[7])
    
    assert result.empty
    assert 'logins_7d' in result.columns
```

### Integration Tests

> **Integration Tests**: Test how components work together

```python
# tests/integration/test_pipeline.py
import pytest
from pathlib import Path
from churn_mlops.data.processing import prepare_data
from churn_mlops.features.engineering import build_features

def test_data_pipeline_end_to_end(tmp_path):
    """Test full data → features pipeline."""
    # Arrange
    raw_data_path = tmp_path / "raw"
    processed_path = tmp_path / "processed"
    features_path = tmp_path / "features"
    
    # Create sample raw data
    raw_data = pd.DataFrame({
        'user_id': ['user1'] * 30,
        'date': pd.date_range('2023-01-01', periods=30),
        'event': ['login'] * 30
    })
    raw_data_path.mkdir(parents=True)
    raw_data.to_parquet(raw_data_path / "events.parquet")
    
    # Act
    prepare_data(raw_data_path, processed_path)
    build_features(processed_path, features_path, windows=[7, 14])
    
    # Assert
    assert (features_path / "user_features.parquet").exists()
    features = pd.read_parquet(features_path / "user_features.parquet")
    assert not features.empty
    assert 'logins_7d' in features.columns
    assert 'logins_14d' in features.columns
```

### Data Validation Tests

```python
# tests/integration/test_data_validation.py
import pytest
import great_expectations as ge
from churn_mlops.data.validation import validate_raw_data

def test_raw_data_validation():
    """Test data validation with Great Expectations."""
    # Arrange
    df = pd.DataFrame({
        'user_id': ['user1', 'user2', 'user3'],
        'date': pd.to_datetime(['2023-01-01', '2023-01-02', '2023-01-03']),
        'logins': [5, 10, 15]
    })
    
    # Act
    result = validate_raw_data(df)
    
    # Assert
    assert result.success
    assert len(result.results) > 0

def test_invalid_data_fails_validation():
    """Test that invalid data fails validation."""
    df = pd.DataFrame({
        'user_id': [None, 'user2', 'user3'],  # Null user_id
        'date': ['not-a-date', '2023-01-02', '2023-01-03'],
        'logins': [-5, 10, 15]  # Negative logins
    })
    
    result = validate_raw_data(df)
    
    assert not result.success
```

### GitHub Actions Testing Job

```yaml
jobs:
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'
          cache: 'pip'

      - name: Install dependencies
        run: |
          pip install -r requirements/base.txt
          pip install -r requirements/dev.txt
          pip install -e .

      - name: Run pytest
        run: |
          pytest tests/ \
            -v \
            --cov=churn_mlops \
            --cov-report=xml \
            --cov-report=term \
            --junitxml=test-results.xml

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: test-results.xml

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: ./coverage.xml
          flags: unittests
        continue-on-error: true
```

---

## Code Quality Checks

### Linting with Ruff

> **Ruff**: Fast Python linter (10-100x faster than Flake8)

**Configuration** (`ruff.toml`):
```toml
line-length = 88
target-version = "py310"

[lint]
select = [
    "E",    # pycodestyle errors
    "F",    # pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "C4",   # flake8-comprehensions
]
ignore = [
    "E501",  # line too long (handled by Black)
]

[lint.per-file-ignores]
"__init__.py" = ["F401"]  # Allow unused imports
```

**GitHub Actions Job**:
```yaml
jobs:
  lint:
    name: Lint & Format Check
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'

      - name: Install dependencies
        run: |
          pip install ruff black

      - name: Run Ruff linting
        run: |
          ruff check . --output-format=github

      - name: Check Black formatting
        run: |
          black --check .
```

**Ruff Output**:
```
src/churn_mlops/api/app.py:15:1: F401 `pandas` imported but unused
src/churn_mlops/features/engineering.py:42:5: E711 comparison to None should be 'if cond is None:'
Found 2 errors.
```

### Formatting with Black

> **Black**: Opinionated code formatter (no configuration debates)

```python
# Before Black
def my_function(x,y,z):
    return x+y+z

result=my_function(1,2,3)

# After Black
def my_function(x, y, z):
    return x + y + z


result = my_function(1, 2, 3)
```

**Auto-format**:
```bash
# Format all files
black .

# Check without modifying
black --check .

# Show what would change
black --diff .
```

### Type Checking with MyPy (Optional)

```python
# src/churn_mlops/features/engineering.py
from typing import List, Optional
import pandas as pd

def create_features(
    df: pd.DataFrame,
    windows: List[int],
    user_col: str = "user_id"
) -> pd.DataFrame:
    """Create rolling window features."""
    ...
```

**GitHub Actions**:
```yaml
- name: Run type checking
  run: |
    if pip list | grep -q mypy; then
      mypy src/churn_mlops
    fi
  continue-on-error: true
```

---

## Security Scanning

### Dependency Scanning with Safety

> **Safety**: Check dependencies for known vulnerabilities

```yaml
jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'

      - name: Install Security tools
        run: |
          pip install safety bandit

      - name: Run Safety check
        run: |
          safety check --json || true
        continue-on-error: true

      - name: Generate Safety report
        run: |
          safety check --full-report > safety-report.txt || true

      - name: Upload Safety report
        uses: actions/upload-artifact@v4
        with:
          name: safety-report
          path: safety-report.txt
        if: always()
```

**Safety Output**:
```
+==============================================================================+
|                                                                              |
|                               /$$$$$$            /$$                         |
|                              /$$__  $$          | $$                         |
|           /$$$$$$$  /$$$$$$ | $$  \__//$$$$$$  /$$$$$$   /$$   /$$          |
|          /$$_____/ |____  $$| $$$$   /$$__  $$|_  $$_/  | $$  | $$          |
|         |  $$$$$$   /$$$$$$$| $$_/  | $$$$$$$$  | $$    | $$  | $$          |
|          \____  $$ /$$__  $$| $$    | $$_____/  | $$ /$$| $$  | $$          |
|          /$$$$$$$/|  $$$$$$$| $$    |  $$$$$$$  |  $$$$/|  $$$$$$$          |
|         |_______/  \_______/|__/     \_______/   \___/   \____  $$          |
|                                                            /$$  | $$          |
|                                                           |  $$$$$$/          |
|  by pyup.io                                                \______/           |
|                                                                              |
+==============================================================================+

 REPORT 

  Safety is using PyUp's free open-source vulnerability database.

  Scanning dependencies in requirements file:
  -> requirements/base.txt

+============================================================================================+
| VULNERABILITY REPORT                                                                       |
+============================================================================================+
| package: urllib3                                                                          |
| installed: 1.26.5                                                                         |
| vulnerable: <1.26.18                                                                      |
| CVE: CVE-2023-45803                                                                       |
| severity: HIGH                                                                            |
| description: urllib3 Cookie request header isn't stripped during cross-origin redirects  |
+============================================================================================+
```

### Code Security with Bandit

> **Bandit**: Find common security issues in Python code

```yaml
- name: Run Bandit security linting
  run: |
    bandit -r src/ -f json -o bandit-report.json || true
    bandit -r src/ -f screen
  continue-on-error: true

- name: Upload Bandit report
  uses: actions/upload-artifact@v4
  with:
    name: bandit-report
    path: bandit-report.json
  if: always()
```

**Bandit checks for**:
- Hardcoded passwords
- SQL injection
- Shell injection
- Insecure random numbers
- Weak crypto

**Example Issue**:
```python
# BAD: Hardcoded password
password = "MySecretPassword123"

# GOOD: Use environment variable
password = os.environ.get("DB_PASSWORD")
```

---

## Docker Build Validation

### Build Without Pushing

```yaml
jobs:
  build-validation:
    name: Validate Docker Builds
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build ML Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile.ml
          push: false  # Don't push, just validate build
          tags: churn-mlops-ml:test
          cache-from: type=gha  # Use GitHub Actions cache
          cache-to: type=gha,mode=max

      - name: Build API Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile.api
          push: false
          tags: churn-mlops-api:test
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**Why validate builds in CI?**
- Catch Dockerfile errors early
- Ensure multi-stage builds work
- Verify dependencies install correctly
- Test on clean environment

### Docker Layer Caching

```yaml
- name: Build with cache
  uses: docker/build-push-action@v5
  with:
    context: .
    file: docker/Dockerfile.ml
    push: false
    cache-from: type=gha  # Pull cache from GitHub
    cache-to: type=gha,mode=max  # Save cache to GitHub
```

**Benefits**:
```
Without cache: 5 minutes
With cache: 30 seconds (10x faster!)
```

---

## Test Coverage

### Coverage Report

```yaml
- name: Run pytest with coverage
  run: |
    pytest tests/ \
      --cov=churn_mlops \
      --cov-report=xml \
      --cov-report=term \
      --cov-report=html

- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v4
  with:
    file: ./coverage.xml
    flags: unittests
    name: codecov-umbrella
  env:
    CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

**Terminal Output**:
```
---------- coverage: platform linux, python 3.10.12 -----------
Name                                      Stmts   Miss  Cover
-------------------------------------------------------------
src/churn_mlops/__init__.py                   2      0   100%
src/churn_mlops/data/processing.py           45      3    93%
src/churn_mlops/features/engineering.py      78      8    90%
src/churn_mlops/training/train.py            56     12    79%
-------------------------------------------------------------
TOTAL                                       181     23    87%
```

### Coverage Badges

Add to README.md:
```markdown
[![codecov](https://codecov.io/gh/username/repo/branch/main/graph/badge.svg)](https://codecov.io/gh/username/repo)
```

Result: ![Coverage](https://img.shields.io/badge/coverage-87%25-green)

---

## Branch Protection

### PR Checks

**Settings → Branches → Add rule**

```
Branch name pattern: main

✅ Require a pull request before merging
✅ Require approvals: 1

✅ Require status checks to pass before merging
  - lint-and-format
  - unit-tests
  - security-scan
  - build-validation

✅ Require branches to be up to date before merging

✅ Include administrators
```

**Result**:
```
Pull Request #42
├── ✅ lint-and-format passed
├── ✅ unit-tests passed
├── ✅ security-scan passed
└── ✅ build-validation passed

[Merge pull request] button enabled
```

---

## Code Walkthrough

### Complete CI Workflow

```yaml
# .github/workflows/ci.yml
name: CI - Build, Test, Lint

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [develop]

env:
  PYTHON_VERSION: "3.10"

jobs:
  # ============================================
  # Stage 1: Code Quality
  # ============================================
  lint-and-format:
    name: Lint & Format Check
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
          cache: 'pip'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements/dev.txt
          pip install -e .

      - name: Run Ruff linting
        run: |
          ruff check . --output-format=github

      - name: Check Black formatting
        run: |
          black --check .

      - name: Run type checking (optional)
        run: |
          if pip list | grep -q mypy; then
            mypy src/churn_mlops || true
          fi
        continue-on-error: true

  # ============================================
  # Stage 2: Testing
  # ============================================
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
          cache: 'pip'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements/base.txt
          pip install -r requirements/dev.txt
          pip install -e .

      - name: Run pytest
        run: |
          pytest tests/ -v \
            --cov=churn_mlops \
            --cov-report=xml \
            --cov-report=term \
            --junitxml=test-results.xml

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: test-results.xml

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          file: ./coverage.xml
          flags: unittests
          name: codecov-umbrella
        continue-on-error: true

  # ============================================
  # Stage 3: Security
  # ============================================
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install safety bandit

      - name: Run Safety check (dependencies)
        run: |
          safety check --json || true
        continue-on-error: true

      - name: Run Bandit (security linting)
        run: |
          bandit -r src/ -f json -o bandit-report.json || true
          bandit -r src/ -f screen
        continue-on-error: true

      - name: Upload Bandit report
        uses: actions/upload-artifact@v4
        with:
          name: bandit-security-report
          path: bandit-report.json
        if: always()

  # ============================================
  # Stage 4: Build Validation
  # ============================================
  build-validation:
    name: Validate Docker Builds
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build ML Docker image (validation)
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile.ml
          push: false
          tags: churn-mlops-ml:test
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Build API Docker image (validation)
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile.api
          push: false
          tags: churn-mlops-api:test
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## Hands-On Exercise

### Exercise 1: Create CI Workflow

Create `.github/workflows/ci.yml`:
```yaml
name: CI

on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
          cache: 'pip'
      - run: pip install -r requirements/dev.txt
      - run: pip install -e .
      - run: pytest tests/ -v
```

**Test**:
```bash
git checkout -b feature/test-ci
git add .github/workflows/ci.yml
git commit -m "Add CI workflow"
git push origin feature/test-ci
# Create PR on GitHub
```

### Exercise 2: Add Linting

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
      - run: pip install ruff black
      - run: ruff check .
      - run: black --check .
```

### Exercise 3: Add Coverage

```yaml
- name: Run pytest with coverage
  run: |
    pytest tests/ \
      --cov=churn_mlops \
      --cov-report=xml \
      --cov-report=term

- name: Upload coverage
  uses: codecov/codecov-action@v4
  with:
    file: ./coverage.xml
```

### Exercise 4: Add Build Validation

```yaml
build:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: docker/setup-buildx-action@v3
    - uses: docker/build-push-action@v5
      with:
        context: .
        file: docker/Dockerfile.api
        push: false
        tags: test:latest
```

### Exercise 5: Enable Branch Protection

1. Go to **Settings** → **Branches**
2. Click **Add rule**
3. Branch name pattern: `main`
4. Check:
   - ✅ Require pull request
   - ✅ Require status checks (select your jobs)
5. Save

---

## Assessment Questions

### Question 1: Multiple Choice
What's the purpose of `continue-on-error: true`?

A) Ignore all errors  
B) **Let workflow continue even if step fails** ✅  
C) Retry failed steps  
D) Skip the step  

---

### Question 2: True/False
**Statement**: Unit tests should test multiple components together.

**Answer**: False ❌  
**Explanation**: Unit tests test **individual** functions/classes in isolation. Testing multiple components is **integration testing**.

---

### Question 3: Short Answer
Why cache pip packages in CI?

**Answer**:
- **Speed**: Installing packages takes 2-5 minutes. Cache reduces to 10-30 seconds.
- **Cost**: Faster builds = less GitHub Actions minutes used
- **Reliability**: Less dependent on PyPI availability

---

### Question 4: Code Analysis
What's wrong with this test?

```python
def test_model_training():
    # Train model (takes 5 minutes)
    model = train_full_model()
    
    # Test
    assert model.score > 0.8
```

**Answer**:
- **Too slow**: Unit tests should run in milliseconds, not minutes
- **Not isolated**: Depends on training (flaky)
- **Not focused**: Testing too much at once
- **Better**: Mock the training, test model interface:
```python
def test_model_prediction(mock_model):
    prediction = mock_model.predict(sample_features)
    assert 0 <= prediction <= 1
```

---

### Question 5: Design Challenge
Design CI pipeline with 3 stages that run in parallel, then a final stage that runs only if all pass.

**Answer**:
```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ruff check .
  
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pytest tests/
  
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: safety check
  
  deploy-staging:
    needs: [lint, test, security]  # Wait for all
    runs-on: ubuntu-latest
    steps:
      - run: echo "All checks passed, deploying..."
```

---

## Key Takeaways

### ✅ What You Learned

1. **CI Pipeline**
   - Automate testing on every commit
   - Catch bugs before merge
   - Maintain code quality

2. **Testing Strategy**
   - Unit tests (fast, many)
   - Integration tests (medium)
   - Data validation tests

3. **Code Quality**
   - Linting with Ruff
   - Formatting with Black
   - Type checking with MyPy

4. **Security**
   - Dependency scanning (Safety)
   - Code scanning (Bandit)
   - Generate security reports

5. **Build Validation**
   - Test Docker builds in CI
   - Use layer caching (10x faster)
   - Catch Dockerfile errors early

---

## Next Steps

Continue to **[Section 22: CD Pipeline](./section-22-cd-pipeline.md)**

In the next section, we'll:
- Build continuous deployment pipeline
- Push Docker images to registry
- Automate deployments to Kubernetes
- Implement GitOps workflows

---

## Additional Resources

- [pytest Documentation](https://docs.pytest.org/)
- [Ruff Linter](https://github.com/astral-sh/ruff)
- [Codecov](https://codecov.io/)
- [GitHub Actions Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

---

**Progress**: 19/34 sections complete (56%) → **20/34 (59%)**
