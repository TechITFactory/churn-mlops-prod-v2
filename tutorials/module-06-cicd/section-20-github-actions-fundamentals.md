# Section 20: GitHub Actions Fundamentals

**Duration**: 2.5 hours  
**Level**: Intermediate  
**Prerequisites**: Basic Git knowledge, Module 5 (Kubernetes)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand GitHub Actions architecture
- ✅ Create workflows with YAML syntax
- ✅ Use actions from the marketplace
- ✅ Implement workflow triggers
- ✅ Manage secrets and environment variables
- ✅ Use job dependencies and artifacts
- ✅ Debug failing workflows

---

## 📚 Table of Contents

1. [What is GitHub Actions?](#what-is-github-actions)
2. [GitHub Actions Architecture](#github-actions-architecture)
3. [Workflow YAML Syntax](#workflow-yaml-syntax)
4. [Triggers and Events](#triggers-and-events)
5. [Jobs and Steps](#jobs-and-steps)
6. [Secrets and Variables](#secrets-and-variables)
7. [Artifacts and Caching](#artifacts-and-caching)
8. [Code Walkthrough](#code-walkthrough)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## What is GitHub Actions?

> **GitHub Actions**: CI/CD platform integrated into GitHub repositories

### Traditional CI/CD vs GitHub Actions

```
Traditional CI/CD (Jenkins, GitLab CI):
┌──────────────┐    Push     ┌──────────────┐
│   GitHub     │ ──────────→ │   Jenkins    │
│  Repository  │             │   Server     │
└──────────────┘             └──────────────┘
                                    ↓
                              Run pipeline
                              (separate system)

GitHub Actions:
┌────────────────────────────────────────┐
│          GitHub Repository             │
│  ┌──────────┐        ┌──────────────┐ │
│  │   Code   │  Push  │   Workflows  │ │
│  │          │ ─────→ │   (built-in) │ │
│  └──────────┘        └──────────────┘ │
└────────────────────────────────────────┘
         All in one place!
```

### Key Benefits

| Feature | Description |
|---------|-------------|
| **Integrated** | No separate CI server needed |
| **Event-driven** | Trigger on push, PR, issue, release, schedule |
| **Marketplace** | 18,000+ pre-built actions |
| **Matrix builds** | Test multiple OS/versions in parallel |
| **Free tier** | 2,000 minutes/month for private repos |

---

## GitHub Actions Architecture

### Components Hierarchy

```
Repository
  └── .github/workflows/          # Workflows directory
        ├── ci.yml                # CI workflow
        ├── cd.yml                # CD workflow
        └── release.yml           # Release workflow

Workflow (ci.yml)
  ├── name: "CI Pipeline"         # Workflow name
  ├── on: [push, pull_request]    # Triggers
  └── jobs:                       # Jobs (run in parallel by default)
        ├── lint:                 # Job 1
        │   └── steps:            # Steps (run sequentially)
        │         ├── Checkout code
        │         ├── Setup Python
        │         └── Run linter
        └── test:                 # Job 2
            └── steps:
                  ├── Checkout code
                  ├── Setup Python
                  └── Run tests
```

### Execution Flow

```
1. Event Trigger
   ↓
2. GitHub Actions Runner (VM)
   - OS: ubuntu-latest, windows-latest, macos-latest
   - Fresh environment for each job
   ↓
3. Job Execution
   - Checkout code
   - Run steps sequentially
   ↓
4. Cleanup
   - VM destroyed after job
```

### Runner Types

| Runner | Description | Use Case |
|--------|-------------|----------|
| **GitHub-hosted** | Managed by GitHub | Most workflows |
| **Self-hosted** | Your own servers | Special hardware, GPUs, cost savings |

**GitHub-hosted specs**:
```yaml
ubuntu-latest:
  - CPU: 2-core
  - Memory: 7 GB
  - Storage: 14 GB SSD

windows-latest:
  - CPU: 2-core
  - Memory: 7 GB
  - Storage: 14 GB SSD

macos-latest:
  - CPU: 3-core
  - Memory: 14 GB
  - Storage: 14 GB SSD
```

---

## Workflow YAML Syntax

### Basic Structure

```yaml
name: Workflow Name

# When to run
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

# Environment variables (workflow-level)
env:
  PYTHON_VERSION: "3.10"

# Jobs
jobs:
  job-name:
    name: Human-Readable Name
    runs-on: ubuntu-latest  # Runner OS
    
    steps:
      - name: Step 1
        run: echo "Hello, World!"
      
      - name: Step 2
        uses: actions/checkout@v4
```

### Complete Example

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  PYTHON_VERSION: "3.10"

jobs:
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    
    steps:
      # Use an action from marketplace
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      # Run shell command
      - name: Install dependencies
        run: |
          pip install ruff black
      
      - name: Run Ruff
        run: ruff check .
      
      - name: Check Black
        run: black --check .
  
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    needs: lint  # Wait for lint job to succeed
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: Install dependencies
        run: |
          pip install -r requirements/dev.txt
          pip install -e .
      
      - name: Run pytest
        run: pytest tests/ -v
```

---

## Triggers and Events

### Event Types

| Event | Description | Use Case |
|-------|-------------|----------|
| `push` | Code pushed to branch | CI on every commit |
| `pull_request` | PR opened/updated | CI on PRs |
| `release` | Release published | Deploy on releases |
| `schedule` | Cron schedule | Nightly builds |
| `workflow_dispatch` | Manual trigger | On-demand workflows |

### Push Trigger

```yaml
on:
  push:
    branches:
      - main        # Only main branch
      - develop
    paths:
      - 'src/**'    # Only if src/ changed
      - 'tests/**'
    paths-ignore:
      - 'docs/**'   # Ignore docs changes
```

### Pull Request Trigger

```yaml
on:
  pull_request:
    types:
      - opened      # PR opened
      - synchronize # New commits pushed
      - reopened    # PR reopened
    branches:
      - main        # Only PRs to main
```

### Schedule Trigger

```yaml
on:
  schedule:
    # Cron syntax: minute hour day month day-of-week
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
    - cron: '0 */6 * * *'  # Every 6 hours
```

### Manual Trigger (workflow_dispatch)

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production
      log-level:
        description: 'Log level'
        required: false
        default: 'info'
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to ${{ inputs.environment }}
        run: |
          echo "Deploying to ${{ inputs.environment }}"
          echo "Log level: ${{ inputs.log-level }}"
```

### Multiple Triggers

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:
```

---

## Jobs and Steps

### Job Structure

```yaml
jobs:
  job-id:
    name: Human-Readable Name
    runs-on: ubuntu-latest  # Required
    env:                    # Job-level env vars
      JOB_VAR: value
    steps:
      - name: Step name
        run: echo "Hello"
```

### Job Dependencies

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Building..."
  
  test:
    runs-on: ubuntu-latest
    needs: build  # Wait for build to complete
    steps:
      - run: echo "Testing..."
  
  deploy:
    runs-on: ubuntu-latest
    needs: [build, test]  # Wait for both
    steps:
      - run: echo "Deploying..."
```

**Execution Flow**:
```
build
  ↓
test
  ↓
deploy
```

### Conditional Jobs

```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    steps:
      - run: echo "Deploy to staging"
  
  deploy-production:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - run: echo "Deploy to production"
```

### Matrix Strategy

> **Matrix**: Run job with multiple configurations in parallel

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        python-version: ['3.9', '3.10', '3.11']
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      
      - name: Run tests
        run: pytest tests/
```

**Result**: 9 jobs run in parallel (3 OS × 3 Python versions)

### Step Types

**1. Run Shell Command**:
```yaml
- name: Print message
  run: echo "Hello, World!"

- name: Multi-line command
  run: |
    echo "Line 1"
    echo "Line 2"
    pip install -r requirements.txt
```

**2. Use Action**:
```yaml
- name: Checkout code
  uses: actions/checkout@v4  # org/repo@version

- name: Setup Python
  uses: actions/setup-python@v5
  with:  # Action inputs
    python-version: '3.10'
    cache: 'pip'
```

**3. Conditional Step**:
```yaml
- name: Deploy (only on main)
  if: github.ref == 'refs/heads/main'
  run: ./deploy.sh
```

---

## Secrets and Variables

### Repository Secrets

**Settings → Secrets and variables → Actions → New repository secret**

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production
        env:
          AWS_ACCESS_KEY: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          aws s3 sync ./build s3://my-bucket
```

**Important**:
- Secrets are **encrypted** at rest
- **Never** logged in output (masked as ***)
- Only available to workflows in that repo

### Environment Variables

**Scope Levels**:
```yaml
# 1. Workflow level
env:
  WORKFLOW_VAR: value

jobs:
  job1:
    # 2. Job level
    env:
      JOB_VAR: value
    
    steps:
      # 3. Step level
      - name: Step
        env:
          STEP_VAR: value
        run: |
          echo $WORKFLOW_VAR
          echo $JOB_VAR
          echo $STEP_VAR
```

### Context Variables

```yaml
${{ github.ref }}           # refs/heads/main
${{ github.sha }}           # commit SHA
${{ github.actor }}         # username who triggered
${{ github.repository }}    # owner/repo
${{ github.event_name }}    # push, pull_request, etc.
${{ runner.os }}            # Linux, Windows, macOS
${{ job.status }}           # success, failure, cancelled
```

**Example**:
```yaml
- name: Print context
  run: |
    echo "Branch: ${{ github.ref }}"
    echo "SHA: ${{ github.sha }}"
    echo "Actor: ${{ github.actor }}"
    echo "Event: ${{ github.event_name }}"
```

---

## Artifacts and Caching

### Artifacts

> **Artifacts**: Files generated by workflow (logs, binaries, reports)

**Upload Artifact**:
```yaml
- name: Run tests
  run: pytest --cov=. --cov-report=xml

- name: Upload coverage report
  uses: actions/upload-artifact@v4
  with:
    name: coverage-report
    path: coverage.xml
    retention-days: 30  # Keep for 30 days
```

**Download Artifact** (in another job):
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: pytest --cov=. --cov-report=xml
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage.xml
  
  report:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: coverage
      
      - name: View coverage
        run: cat coverage.xml
```

### Caching

> **Caching**: Store dependencies between workflow runs

**Cache pip dependencies**:
```yaml
- name: Set up Python
  uses: actions/setup-python@v5
  with:
    python-version: '3.10'
    cache: 'pip'  # Auto-cache pip packages

- name: Install dependencies
  run: pip install -r requirements.txt
```

**Manual caching**:
```yaml
- name: Cache pip packages
  uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('requirements.txt') }}
    restore-keys: |
      ${{ runner.os }}-pip-

- name: Install dependencies
  run: pip install -r requirements.txt
```

**How it works**:
```
Run 1:
- Cache miss (no cache found)
- Install packages (slow)
- Save to cache

Run 2:
- Cache hit (cache found with same key)
- Restore from cache (fast!)
- Skip installation
```

---

## Code Walkthrough

### Real-World CI Workflow

```yaml
name: CI - Build, Test, Lint

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [develop]

env:
  PYTHON_VERSION: "3.10"

jobs:
  # Job 1: Linting
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
          cache: 'pip'  # Cache pip packages

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements/dev.txt
          pip install -e .

      - name: Run Ruff linting
        run: ruff check . --output-format=github

      - name: Check Black formatting
        run: black --check .

  # Job 2: Unit Tests
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
            --cov-report=term

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          file: ./coverage.xml
          flags: unittests
        continue-on-error: true

  # Job 3: Security Scan
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

      - name: Install security tools
        run: |
          pip install safety bandit

      - name: Run Safety check
        run: safety check --json
        continue-on-error: true

      - name: Run Bandit
        run: bandit -r src/ -f screen
        continue-on-error: true

  # Job 4: Build Validation
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
          push: false
          tags: churn-mlops-ml:test
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**Workflow Visualization**:
```
Pull Request → GitHub Actions

├── lint-and-format  ──┐
├── unit-tests        ─┼→ All must pass
├── security-scan     ─┤  before merge
└── build-validation ──┘
```

---

## Hands-On Exercise

### Exercise 1: Create Basic Workflow

```yaml
# .github/workflows/hello.yml
name: Hello World

on:
  push:
    branches: [main]

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - name: Print greeting
        run: echo "Hello, GitHub Actions!"
      
      - name: Print date
        run: date
      
      - name: List files
        run: ls -la
```

**Commit and push**:
```bash
git add .github/workflows/hello.yml
git commit -m "Add hello world workflow"
git push
```

**View**: Go to **Actions** tab in GitHub

### Exercise 2: Multi-Job Workflow

```yaml
# .github/workflows/multi-job.yml
name: Multi-Job Example

on: [push]

jobs:
  job1:
    runs-on: ubuntu-latest
    steps:
      - name: Job 1
        run: echo "Job 1 running"
  
  job2:
    runs-on: ubuntu-latest
    needs: job1  # Wait for job1
    steps:
      - name: Job 2
        run: echo "Job 2 running after Job 1"
```

### Exercise 3: Matrix Build

```yaml
# .github/workflows/matrix.yml
name: Matrix Build

on: [push]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
        python-version: ['3.9', '3.10', '3.11']
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      
      - name: Print info
        run: |
          echo "OS: ${{ matrix.os }}"
          echo "Python: ${{ matrix.python-version }}"
          python --version
```

### Exercise 4: Artifacts

```yaml
# .github/workflows/artifacts.yml
name: Artifacts Example

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Create artifact
        run: |
          mkdir output
          echo "Build timestamp: $(date)" > output/build-info.txt
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: output/
  
  consume:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: build-output
      
      - name: Display artifact
        run: cat build-info.txt
```

### Exercise 5: Manual Trigger

```yaml
# .github/workflows/manual.yml
name: Manual Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        run: |
          echo "Deploying to ${{ inputs.environment }}"
```

**Trigger**: Go to **Actions** → Select workflow → **Run workflow**

---

## Assessment Questions

### Question 1: Multiple Choice
What triggers a GitHub Actions workflow?

A) Only manual triggers  
B) **Events like push, PR, schedule, manual** ✅  
C) Only pull requests  
D) Only on main branch  

---

### Question 2: True/False
**Statement**: Jobs in a workflow run sequentially by default.

**Answer**: False ❌  
**Explanation**: Jobs run in **parallel** by default. Use `needs` to create dependencies.

---

### Question 3: Short Answer
What's the difference between artifacts and caching?

**Answer**:
- **Artifacts**: Store build outputs (logs, binaries) to download later or share between jobs. Retained for 90 days by default.
- **Caching**: Store dependencies (pip packages, npm modules) to speed up workflows. Automatically deleted after 7 days if not accessed.

---

### Question 4: Code Analysis
What's wrong with this workflow?

```yaml
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Run tests
        run: pytest tests/
```

**Answer**:
- Missing `actions/checkout@v4` - code not checked out!
- Missing Python setup - pytest not installed
- Should be:
```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-python@v5
    with:
      python-version: '3.10'
  - run: pip install pytest
  - run: pytest tests/
```

---

### Question 5: Design Challenge
Create workflow that:
- Runs on PR to main
- Lints code (job 1)
- Tests code (job 2, after lint succeeds)
- Only runs tests if src/ or tests/ changed

**Answer**:
```yaml
name: CI
on:
  pull_request:
    branches: [main]
    paths:
      - 'src/**'
      - 'tests/**'

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
      - run: pip install ruff
      - run: ruff check .
  
  test:
    needs: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
          cache: 'pip'
      - run: pip install -r requirements/dev.txt
      - run: pytest tests/
```

---

## Key Takeaways

### ✅ What You Learned

1. **GitHub Actions Basics**
   - Integrated CI/CD in GitHub
   - Event-driven automation
   - No separate server needed

2. **Workflow Structure**
   - YAML syntax
   - Jobs (parallel by default)
   - Steps (sequential)
   - Triggers (push, PR, schedule, manual)

3. **Advanced Features**
   - Matrix builds (test multiple OS/versions)
   - Job dependencies (`needs`)
   - Artifacts (share files between jobs)
   - Caching (speed up workflows)

4. **Secrets Management**
   - Encrypted repository secrets
   - Environment variables
   - Context variables (${{ github.* }})

---

## Next Steps

Continue to **[Section 21: CI Pipeline](./section-21-ci-pipeline.md)**

In the next section, we'll:
- Build complete CI pipeline
- Implement testing strategies
- Add code quality checks
- Integrate security scanning

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Actions Marketplace](https://github.com/marketplace?type=actions)
- [Workflow Syntax Reference](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

---

**Progress**: 18/34 sections complete (53%) → **19/34 (56%)**
