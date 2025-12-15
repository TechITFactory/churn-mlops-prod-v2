# Section 14: Container Optimization

**Duration**: 2 hours  
**Level**: Advanced  
**Prerequisites**: Sections 12-13 (Docker Fundamentals, Multi-Stage Builds)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Minimize Docker image size aggressively
- ✅ Optimize layer caching for faster builds
- ✅ Implement security hardening
- ✅ Use BuildKit advanced features
- ✅ Profile and analyze images
- ✅ Apply production optimization patterns

---

## 📚 Table of Contents

1. [Image Size Optimization](#image-size-optimization)
2. [Layer Caching Strategies](#layer-caching-strategies)
3. [Security Hardening](#security-hardening)
4. [BuildKit Features](#buildkit-features)
5. [Image Analysis Tools](#image-analysis-tools)
6. [Production Patterns](#production-patterns)
7. [Hands-On Exercise](#hands-on-exercise)
8. [Assessment Questions](#assessment-questions)

---

## Image Size Optimization

### Size Hierarchy

```
Base Image Sizes:
ubuntu:22.04        →  77 MB
python:3.10         → 917 MB  (includes dev tools!)
python:3.10-slim    → 125 MB  (minimal, recommended)
python:3.10-alpine  →  50 MB  (very minimal, may need compilation)

Typical Project Sizes:
Base (slim)                    125 MB
+ Python packages              250 MB
+ Application code              10 MB
+ Build artifacts               50 MB
─────────────────────────────────────
Single-stage total:            435 MB

Multi-stage (excludes build):
Base (slim)                    125 MB
+ Python packages (compiled)   200 MB
+ Application code              10 MB
─────────────────────────────────────
Multi-stage total:             335 MB  (23% smaller)

Optimized:
Base (alpine)                   50 MB
+ Python packages (wheels)     180 MB
+ Application code (minimal)     5 MB
─────────────────────────────────────
Optimized total:               235 MB  (46% smaller)
```

### Technique 1: Choose Minimal Base

```dockerfile
# ❌ Large base (917 MB)
FROM python:3.10

# ✅ Better: slim variant (125 MB)
FROM python:3.10-slim

# ✅ Best: alpine (50 MB, but harder)
FROM python:3.10-alpine
# Note: May need to compile packages, slower builds
```

**Trade-offs**:
| Base | Size | Compatibility | Build Speed |
|------|------|---------------|-------------|
| `python:3.10` | 917 MB | ✅ Excellent | ✅ Fast |
| `python:3.10-slim` | 125 MB | ✅ Good | ✅ Fast |
| `python:3.10-alpine` | 50 MB | ⚠️ May need tweaks | ⚠️ Slow (compiles) |

**Recommendation**: Use `slim` for most cases (good balance)

### Technique 2: --no-cache-dir

```dockerfile
# ❌ Caches pip downloads (50+ MB wasted)
RUN pip install scikit-learn pandas

# ✅ No cache (saves 50-100 MB)
RUN pip install --no-cache-dir scikit-learn pandas
```

**Impact**:
```bash
# With cache
RUN pip install scikit-learn
# Downloads to ~/.cache/pip (50 MB)
# Installs to site-packages (200 MB)
# Total: 250 MB in image

# Without cache
RUN pip install --no-cache-dir scikit-learn
# Installs to site-packages (200 MB)
# Total: 200 MB in image (20% smaller)
```

### Technique 3: Clean Up in Same Layer

```dockerfile
# ❌ Cleanup in separate layer (doesn't reduce size!)
RUN apt-get update && apt-get install -y gcc
RUN rm -rf /var/lib/apt/lists/*
# Problem: First RUN creates layer with 100 MB
# Second RUN creates new layer (removes files but layer still exists!)

# ✅ Cleanup in same RUN (reduces size)
RUN apt-get update && apt-get install -y gcc \
    && rm -rf /var/lib/apt/lists/*
# Single layer: Install + cleanup = only gcc remains
```

**Layer Explanation**:
```
Docker layers are immutable:

RUN apt-get update               Layer 1: + 100 MB (apt cache)
RUN apt-get install gcc          Layer 2: + 50 MB (gcc)
RUN rm -rf /var/lib/apt/lists/*  Layer 3: - 0 MB (marks files deleted)
Total: 150 MB (Layer 1 still exists!)

vs.

RUN apt-get update && \
    apt-get install gcc && \
    rm -rf /var/lib/apt/lists/*  Layer 1: + 50 MB (only gcc)
Total: 50 MB (cleanup happened before layer saved)
```

### Technique 4: Multi-Stage Builds (Recap)

```dockerfile
# Builder: Can be huge (1 GB+)
FROM python:3.10-slim AS builder
RUN apt-get update && apt-get install -y build-essential gcc g++
RUN pip install scikit-learn pandas numpy
# Size: 1.2 GB (but discarded!)

# Runtime: Only copy artifacts
FROM python:3.10-slim
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
# Size: 335 MB (65% smaller!)
```

### Technique 5: .dockerignore

```dockerignore
# Exclude unnecessary files from build context

# Version control
.git
.github
.gitignore

# Python
__pycache__
*.pyc
*.pyo
.pytest_cache
.mypy_cache
*.egg-info

# Virtual environments
.venv
venv/
env/

# Data (large!)
data/raw/*
data/processed/*
artifacts/models/*

# IDE
.vscode
.idea
*.swp

# Documentation
*.md
docs/

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db
```

**Impact**:
```bash
# Without .dockerignore
Sending build context to Docker daemon  2.5 GB
# Includes .git (500 MB), data/ (1.5 GB), .venv (500 MB)

# With .dockerignore
Sending build context to Docker daemon  50 MB
# Only src/, requirements.txt, config/

Build time: 10 min → 30 sec (20× faster!)
```

### Technique 6: Use Wheels

```dockerfile
# ❌ Install from source (requires build tools)
RUN pip install scikit-learn
# Downloads source → Compiles C code → Installs
# Requires: gcc, g++, python-dev (300 MB build tools)

# ✅ Use pre-built wheels (no compilation)
RUN pip install --only-binary :all: scikit-learn
# Downloads wheel → Installs
# No build tools needed!
```

**Wheel Benefits**:
- ✅ Faster (no compilation)
- ✅ Smaller (no build dependencies)
- ⚠️ May not exist for all platforms (fallback to source)

---

## Layer Caching Strategies

### Strategy 1: Order Matters

```dockerfile
# ❌ BAD: Code copied first
FROM python:3.10-slim
COPY . /app                      # Layer 1: Changes often
WORKDIR /app
RUN pip install -r requirements.txt  # Layer 2: Reinstalls every time!

# Every code change → Invalidates cache → Reinstalls packages

# ✅ GOOD: Dependencies first
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .          # Layer 1: Changes rarely
RUN pip install -r requirements.txt  # Layer 2: Cached!
COPY . .                         # Layer 3: Changes often (but doesn't affect above)

# Code change → Layer 3 rebuilds, Layer 1-2 cached!
```

**Build Time**:
```
Bad order:
Code change → Rebuilds layers 1-2 → 5 min

Good order:
Code change → Rebuilds layer 3 only → 5 sec (60× faster!)
```

### Strategy 2: Split Dependencies

```dockerfile
# ✅ Split requirements by change frequency
COPY requirements/base.txt .
RUN pip install -r base.txt       # Changes rarely → Cached

COPY requirements/serving.txt .
RUN pip install -r serving.txt    # Changes occasionally

COPY requirements/dev.txt .
RUN pip install -r dev.txt        # Changes often (but only in dev)
```

### Strategy 3: Use COPY --link (BuildKit)

```dockerfile
# Requires BuildKit enabled
# docker buildx build ...

# ✅ Independent layers (better caching)
COPY --link requirements.txt .
COPY --link src /app/src
COPY --link config /app/config

# Each COPY is independent → Can be reordered without invalidating cache
```

### Strategy 4: Cache Mounts (BuildKit)

```dockerfile
# Mount cache directory (persists across builds)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# First build: Downloads to /root/.cache/pip
# Second build: Reuses cache (even if layer invalidated!)
```

---

## Security Hardening

### 1. Run as Non-Root User

```dockerfile
# ❌ BAD: Runs as root (UID 0)
FROM python:3.10-slim
COPY src /app/src
CMD ["python", "/app/src/main.py"]
# Security risk: If app compromised, attacker has root!

# ✅ GOOD: Run as non-root user
FROM python:3.10-slim
RUN useradd -m -u 1000 appuser
COPY src /app/src
RUN chown -R appuser:appuser /app
USER appuser
CMD ["python", "/app/src/main.py"]
```

**Why?**
- Containers share host kernel
- Root in container = root-like access to host (if misconfigured)
- Non-root user limits damage if compromised

### 2. Read-Only Filesystem

```bash
# Run container with read-only root filesystem
docker run --read-only --tmpfs /tmp my-app

# Forces app to write only to /tmp (explicit temporary storage)
```

**Dockerfile Support**:
```dockerfile
# Create writable directories
RUN mkdir -p /app/tmp && chmod 1777 /app/tmp
VOLUME /app/tmp

# Application writes only to /app/tmp
```

### 3. Drop Capabilities

```bash
# Run with minimal capabilities
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE my-app

# Only allows binding to privileged ports (< 1024)
# No other capabilities (no raw sockets, no setuid, etc.)
```

### 4. Scan for Vulnerabilities

```bash
# Scan image with Docker Scout
docker scout cves my-app:v1.0

# Scan with Trivy
trivy image my-app:v1.0

# Example output:
# CVE-2023-1234 (HIGH): openssl 1.1.1k → Upgrade to 1.1.1l
# CVE-2023-5678 (MEDIUM): libcurl 7.68 → Upgrade to 7.81
```

**Fix vulnerabilities**:
```dockerfile
# Update base image
FROM python:3.10-slim
# Ensures latest security patches

# Update packages
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
```

### 5. Secrets Management

```dockerfile
# ❌ BAD: Secrets in image
ENV DATABASE_PASSWORD=mysecretpass
# Visible in image layers!

# ✅ GOOD: Secrets at runtime
# No ENV for secrets in Dockerfile
# Pass at runtime:
docker run -e DATABASE_PASSWORD=mysecretpass my-app

# ✅ BETTER: Use secrets management
docker run --secret my-secret my-app
# Or: Kubernetes secrets, AWS Secrets Manager, etc.
```

---

## BuildKit Features

### What is BuildKit?

> **BuildKit**: Next-generation Docker build system (faster, more features)

**Enable BuildKit**:
```bash
# One-time (Linux/Mac)
export DOCKER_BUILDKIT=1
docker build ...

# Windows (PowerShell)
$env:DOCKER_BUILDKIT=1
docker build ...

# Or use buildx (BuildKit by default)
docker buildx build ...
```

### Feature 1: Parallel Builds

```dockerfile
# Without BuildKit: Sequential
RUN pip install pandas      # Step 1: 30s
RUN pip install scikit-learn  # Step 2: 60s (waits for Step 1)
# Total: 90s

# With BuildKit: Parallel (if independent)
FROM python:3.10-slim AS pandas-builder
RUN pip install pandas      # 30s

FROM python:3.10-slim AS sklearn-builder
RUN pip install scikit-learn  # 60s (runs in parallel!)

FROM python:3.10-slim
COPY --from=pandas-builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=sklearn-builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
# Total: 60s (33% faster)
```

### Feature 2: Cache Mounts

```dockerfile
# Cache pip downloads across builds
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Benefits:
# - First build: Downloads packages
# - Second build: Reuses downloads (even if requirements.txt changed!)
# - Saves time and bandwidth
```

### Feature 3: Secret Mounts

```dockerfile
# Mount secret (never saved in image!)
RUN --mount=type=secret,id=github_token \
    pip install git+https://$(cat /run/secrets/github_token)@github.com/private/repo.git

# Build:
docker build --secret id=github_token,src=./token.txt .

# Secret is mounted temporarily, never saved in image layers!
```

### Feature 4: SSH Mounts

```dockerfile
# Mount SSH keys (for git clone)
RUN --mount=type=ssh \
    git clone git@github.com:private/repo.git

# Build:
docker build --ssh default .

# Uses host SSH keys, doesn't copy into image
```

---

## Image Analysis Tools

### 1. docker history

```bash
docker history my-app:v1.0

# Output:
IMAGE          CREATED BY                                      SIZE
abc123         CMD ["python", "main.py"]                      0B
def456         COPY . /app                                    10MB
ghi789         RUN pip install -r requirements.txt            250MB
jkl012         COPY requirements.txt .                        1KB
mno345         WORKDIR /app                                   0B
pqr678         FROM python:3.10-slim                          125MB
```

**Identify large layers**:
```bash
docker history my-app:v1.0 | sort -k 2 -h
# Sorts by size → Find largest layers
```

### 2. dive (Interactive Tool)

```bash
# Install
# Linux: wget https://github.com/wagoodman/dive/releases/download/v0.11.0/dive_0.11.0_linux_amd64.deb
# Mac: brew install dive
# Windows: scoop install dive

# Analyze image
dive my-app:v1.0

# Interactive UI:
# - View each layer
# - See files added/removed
# - Wasted space highlighted
```

### 3. docker scout

```bash
# Analyze image (CVEs, recommendations)
docker scout cves my-app:v1.0

# Compare with base image
docker scout compare --to python:3.10-slim my-app:v1.0

# Recommendations
docker scout recommendations my-app:v1.0
```

### 4. Custom Analysis Script

```python
import docker
import json

client = docker.from_env()
image = client.images.get("my-app:v1.0")

# Get image details
print(f"Size: {image.attrs['Size'] / 1024 / 1024:.2f} MB")
print(f"Layers: {len(image.attrs['RootFS']['Layers'])}")

# Layer sizes
history = image.history()
for layer in history:
    size_mb = layer['Size'] / 1024 / 1024
    command = layer['CreatedBy'][:50]
    print(f"{size_mb:6.2f} MB  {command}")
```

---

## Production Patterns

### Pattern 1: Distroless Images (Ultra-Minimal)

```dockerfile
# Google's distroless images (no shell, no package manager)
FROM python:3.10-slim AS builder
RUN pip install scikit-learn

FROM gcr.io/distroless/python3
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY src /app/src
CMD ["python", "/app/src/main.py"]

# Size: ~60 MB (smaller than slim!)
# Security: No shell (can't execute arbitrary commands)
```

**Trade-off**:
- ✅ Ultra-minimal (50-60 MB)
- ✅ Very secure (no shell, no package manager)
- ❌ Hard to debug (no shell!)
- ❌ Can't run bash, can't apt-get

### Pattern 2: Layer Ordering

```dockerfile
# Order by change frequency (least → most)
FROM python:3.10-slim

# 1. System packages (change rarely)
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# 2. Python dependencies (change occasionally)
COPY requirements.txt .
RUN pip install -r requirements.txt

# 3. Application code (change often)
COPY src /app/src

# 4. Configuration (change very often)
COPY config /app/config
```

### Pattern 3: Health Checks

```dockerfile
# Comprehensive healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "
import sys
try:
    import requests
    r = requests.get('http://localhost:8000/health', timeout=5)
    sys.exit(0 if r.status_code == 200 else 1)
except Exception as e:
    print(f'Health check failed: {e}')
    sys.exit(1)
"
```

### Pattern 4: Metadata Labels

```dockerfile
# Rich metadata
LABEL org.opencontainers.image.title="Churn MLOps API" \
      org.opencontainers.image.description="Real-time churn prediction API" \
      org.opencontainers.image.authors="TechITFactory <devops@techitfactory.com>" \
      org.opencontainers.image.vendor="TechITFactory" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/techitfactory/churn-mlops"
```

---

## Hands-On Exercise

### Exercise 1: Optimize Image Size

```bash
# Original image
docker build -f docker/Dockerfile.api -t api:original .
docker images | grep api:original
# api:original  320 MB

# Create optimized version
cat > Dockerfile.optimized <<'EOF'
FROM python:3.10-alpine AS builder
RUN apk add --no-cache build-base
COPY requirements/api.txt .
RUN pip install --no-cache-dir -r api.txt

FROM python:3.10-alpine
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY src /app/src
CMD ["python", "-m", "uvicorn", "app.main:app"]
EOF

docker build -f Dockerfile.optimized -t api:optimized .
docker images | grep api:optimized
# api:optimized  180 MB (44% smaller!)
```

### Exercise 2: Analyze with dive

```bash
# Build image
docker build -f docker/Dockerfile.api -t api:analyze .

# Analyze with dive
dive api:analyze

# Look for:
# - Large layers (> 50 MB)
# - Wasted space (files added then removed)
# - Inefficient caching
```

### Exercise 3: Cache Mount Optimization

```dockerfile
# Dockerfile.cache
FROM python:3.10-slim

# Enable BuildKit
# docker buildx build -f Dockerfile.cache .

WORKDIR /app
COPY requirements.txt .

# Use cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

COPY src /app/src
CMD ["python", "src/main.py"]
```

Build and time:

```bash
# First build (no cache)
time docker buildx build -f Dockerfile.cache -t api:cache .
# Real: 2m 30s

# Second build (cache hit, even with different requirements!)
echo "requests==2.31.0" >> requirements.txt
time docker buildx build -f Dockerfile.cache -t api:cache .
# Real: 5s (30× faster!)
```

### Exercise 4: Security Scan

```bash
# Build image
docker build -f docker/Dockerfile.api -t api:security .

# Scan with Docker Scout
docker scout cves api:security

# Fix vulnerabilities
docker pull python:3.10-slim  # Get latest patches
docker build -f docker/Dockerfile.api -t api:security-fixed .

# Compare
docker scout compare api:security api:security-fixed
```

### Exercise 5: Non-Root User Testing

```bash
# Run as root (default)
docker run --rm api:original whoami
# root  ← Bad!

# Run as non-root
docker run --rm api:security whoami
# apiuser  ← Good!

# Try to write to /etc (should fail)
docker run --rm api:security touch /etc/test
# touch: /etc/test: Permission denied  ← Good! (security)
```

---

## Assessment Questions

### Question 1: Multiple Choice
Which base image is smallest?

A) `python:3.10`  
B) `python:3.10-slim`  
C) **`python:3.10-alpine`** ✅  
D) `ubuntu:22.04`  

**Sizes**: alpine (50 MB) < slim (125 MB) < ubuntu (77 MB, but needs Python) < python:3.10 (917 MB)

---

### Question 2: True/False
**Statement**: Cleaning up files in a separate RUN command reduces image size.

**Answer**: False ❌  
**Explanation**: Layers are immutable. Cleanup must be in same RUN command to prevent layer from being saved with files.

---

### Question 3: Short Answer
Why copy `requirements.txt` before copying application code?

**Answer**:
- Layer caching! If `requirements.txt` unchanged → `RUN pip install` cached
- Code changes often, dependencies rarely
- Avoids reinstalling packages on every code change

---

### Question 4: Code Fix
Optimize this Dockerfile:

```dockerfile
FROM python:3.10
RUN apt-get update
RUN apt-get install -y gcc
COPY . /app
RUN pip install -r /app/requirements.txt
```

**Answer**:
```dockerfile
FROM python:3.10-slim AS builder
RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.10-slim
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY src /app/src
WORKDIR /app
```

**Improvements**:
- Multi-stage (discards gcc)
- slim base (smaller)
- Copy requirements first (caching)
- Cleanup in same layer
- --no-cache-dir (smaller)

---

### Question 5: Design Challenge
Your image is 500 MB but application code is only 10 MB. How do you investigate?

**Answer**:
```bash
# 1. Analyze layer sizes
docker history my-app:v1.0 | sort -k 2 -h

# 2. Use dive for interactive analysis
dive my-app:v1.0

# 3. Check for:
# - Large base image (use slim/alpine)
# - Pip cache (use --no-cache-dir)
# - Apt cache (rm -rf /var/lib/apt/lists/*)
# - Logs, test files (use .dockerignore)
# - Build tools (use multi-stage)

# 4. Expected breakdown (500 MB):
# - Base image: 125 MB (slim)
# - Python packages: 300 MB
# - App code: 10 MB
# - Wasted: 65 MB (caches, build tools)
```

---

## Key Takeaways

### ✅ What You Learned

1. **Size Optimization**
   - Use `slim` or `alpine` base images
   - `--no-cache-dir` for pip
   - Cleanup in same layer
   - Multi-stage builds
   - .dockerignore

2. **Caching Strategies**
   - Order: Dependencies → Code
   - Split requirements
   - Use cache mounts (BuildKit)

3. **Security Hardening**
   - Non-root user
   - Read-only filesystem
   - Drop capabilities
   - Scan for vulnerabilities
   - No secrets in images

4. **BuildKit Features**
   - Parallel builds
   - Cache mounts
   - Secret mounts
   - SSH mounts

5. **Analysis Tools**
   - `docker history`
   - `dive` (interactive)
   - `docker scout` (CVEs)

---

## Next Steps

Continue to **[Section 15: Docker Compose](section-15-docker-compose.md)**

In the next section, we'll:
- Orchestrate multi-container applications
- Define services with docker-compose.yml
- Manage volumes and networks
- Implement development workflows

---

## Additional Resources

- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [BuildKit Documentation](https://docs.docker.com/build/buildkit/)
- [dive Tool](https://github.com/wagoodman/dive)
- [Docker Scout](https://docs.docker.com/scout/)

---

**Progress**: 12/34 sections complete (35%) → **13/34 (38%)**
