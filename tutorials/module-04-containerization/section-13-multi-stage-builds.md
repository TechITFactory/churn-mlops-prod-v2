# Section 13: Multi-Stage Docker Builds

**Duration**: 2 hours  
**Level**: Intermediate  
**Prerequisites**: Section 12 (Docker Fundamentals)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand multi-stage build architecture
- ✅ Separate builder and runtime stages
- ✅ Reduce image size dramatically
- ✅ Optimize for security (no build tools in production)
- ✅ Copy artifacts between stages
- ✅ Implement production-grade Dockerfiles

---

## 📚 Table of Contents

1. [The Problem with Single-Stage Builds](#the-problem)
2. [Multi-Stage Build Architecture](#multi-stage-architecture)
3. [Stage 1: Builder](#stage-1-builder)
4. [Stage 2: Runtime](#stage-2-runtime)
5. [Copying Between Stages](#copying-between-stages)
6. [Advanced Patterns](#advanced-patterns)
7. [Code Walkthrough](#code-walkthrough)
8. [Hands-On Exercise](#hands-on-exercise)
9. [Assessment Questions](#assessment-questions)

---

## The Problem with Single-Stage Builds

### Single-Stage Dockerfile

```dockerfile
FROM python:3.10-slim

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    cmake \
    git

# Install Python packages
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy application
COPY src /app/src
WORKDIR /app

CMD ["python", "src/main.py"]
```

### Problems

**1. Large Image Size**
```
Image size: 1.2 GB

Breakdown:
- Base image (python:3.10-slim): 125 MB
- Build tools (gcc, g++, cmake):  300 MB  ← Not needed at runtime!
- Python packages:                 400 MB
- Application code:                 10 MB
- Cached package downloads:        365 MB  ← Wasted space!

Runtime actually needs: ~535 MB (base + packages + code)
Wasted space: 665 MB (55%!)
```

**2. Security Risk**
```
Production image contains:
✅ Python 3.10          (needed)
✅ scikit-learn         (needed)
❌ gcc, g++, cmake      (dangerous! Can compile malicious code)
❌ git                  (unnecessary)
❌ Build artifacts      (unnecessary)

If attacker gains access:
→ Can compile malware inside container
→ Can clone malicious repos
→ Larger attack surface
```

**3. Slow Builds**
```
Every build installs:
- Build tools (even if cached)
- Compiles packages from source
- Downloads unnecessary dependencies

Build time: 5-10 minutes
```

---

## Multi-Stage Build Architecture

### Concept

```
┌─────────────────────────────────────────────┐
│      Multi-Stage Build (2 Stages)           │
├─────────────────────────────────────────────┤
│                                             │
│  Stage 1: Builder (build-heavy)             │
│  ┌──────────────────────────────────┐      │
│  │ FROM python:3.10-slim AS builder │      │
│  │ - Install build tools (gcc, g++) │      │
│  │ - Compile packages                │      │
│  │ - Create wheels                   │      │
│  │ Size: 1.2 GB (but discarded!)     │      │
│  └──────────────────────────────────┘      │
│               │                             │
│               │ COPY artifacts only         │
│               ↓                             │
│  Stage 2: Runtime (lightweight)             │
│  ┌──────────────────────────────────┐      │
│  │ FROM python:3.10-slim            │      │
│  │ - Copy compiled packages only    │      │
│  │ - No build tools                 │      │
│  │ - Copy application code          │      │
│  │ Size: 300 MB ✅                  │      │
│  └──────────────────────────────────┘      │
│                                             │
└─────────────────────────────────────────────┘

Final image = Only Stage 2 (Stage 1 discarded!)
```

### Benefits

| Benefit | Single-Stage | Multi-Stage |
|---------|-------------|-------------|
| **Image Size** | 1.2 GB | 300 MB (4× smaller) |
| **Build Tools** | ❌ Included | ✅ Excluded |
| **Security** | ⚠️ High attack surface | ✅ Minimal surface |
| **Build Time** | 10 min | 3 min (caching) |
| **Complexity** | Simple | Moderate |

---

## Stage 1: Builder

### Purpose

**Builder stage** = Environment for compiling and building artifacts

```dockerfile
# Stage 1: Builder
FROM python:3.10-slim AS builder
# AS builder → Named stage (can reference later)

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install packages (may compile from source)
RUN pip install --no-cache-dir -r requirements.txt
```

**What happens here**:
1. Install build tools (gcc, g++, make)
2. Download Python packages
3. **Compile** packages that need native extensions
   - Example: `scikit-learn` → Compiles C/C++ code
   - Example: `numpy` → Compiles BLAS/LAPACK
4. Store compiled packages in `/usr/local/lib/python3.10/site-packages`

**Key Point**: This stage can be **huge** (1+ GB) because it has all build tools. But we'll **discard** this stage and only copy the compiled artifacts!

---

## Stage 2: Runtime

### Purpose

**Runtime stage** = Minimal environment for running application

```dockerfile
# Stage 2: Runtime
FROM python:3.10-slim
# Fresh base image (no build tools!)

WORKDIR /app

# Copy compiled packages from builder
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
# --from=builder → Copy from named stage

# Copy application code
COPY src ./src

CMD ["python", "src/main.py"]
```

**What happens here**:
1. Start fresh (no build tools)
2. Copy **only** compiled packages (not source code, not build tools)
3. Copy application code
4. Result: Small, secure image

**Key Point**: Final image = Only this stage (Stage 1 thrown away)

---

## Copying Between Stages

### COPY --from Syntax

```dockerfile
COPY --from=STAGE SOURCE DESTINATION

# Examples:

# Copy from named stage
COPY --from=builder /build/app.whl /tmp/app.whl

# Copy from stage index (0-based)
COPY --from=0 /build/dist /app/dist

# Copy from external image
COPY --from=node:16 /usr/local/bin/node /usr/local/bin/node
```

### What to Copy

```dockerfile
# ✅ COPY compiled packages
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages

# ✅ COPY executables (if created)
COPY --from=builder /usr/local/bin/uvicorn /usr/local/bin/uvicorn

# ❌ DON'T COPY build tools
# NO: COPY --from=builder /usr/bin/gcc /usr/bin/gcc

# ❌ DON'T COPY source code (unless needed)
# NO: COPY --from=builder /build/src /app/src
```

### Example: Copying Python Packages

```dockerfile
# Builder stage
FROM python:3.10-slim AS builder
WORKDIR /build
RUN pip install scikit-learn pandas

# Runtime stage
FROM python:3.10-slim
WORKDIR /app

# Copy site-packages (contains all installed packages)
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages

# Copy scripts (uvicorn, etc.)
COPY --from=builder /usr/local/bin /usr/local/bin

# Test
RUN python -c "import sklearn; print(sklearn.__version__)"
# ✅ Works! scikit-learn available (but gcc, g++ not in image)
```

---

## Advanced Patterns

### Pattern 1: Multiple Builders

```dockerfile
# Builder for Python dependencies
FROM python:3.10-slim AS python-builder
COPY requirements.txt .
RUN pip install -r requirements.txt

# Builder for Node.js assets (if needed)
FROM node:16 AS node-builder
COPY package.json package-lock.json ./
RUN npm ci
COPY assets ./assets
RUN npm run build

# Runtime: Copy from both builders
FROM python:3.10-slim
COPY --from=python-builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=node-builder /app/dist ./static
```

### Pattern 2: Test Stage

```dockerfile
# Builder
FROM python:3.10-slim AS builder
COPY requirements.txt .
RUN pip install -r requirements.txt

# Test stage (not included in final image)
FROM builder AS test
COPY tests ./tests
COPY src ./src
RUN pytest tests/
# If tests fail, build fails!

# Runtime (doesn't include test dependencies)
FROM python:3.10-slim
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY src ./src
```

**Usage**:
```bash
# Build and run tests (stops at test stage)
docker build --target test -t my-app:test .

# Build production image (skips test stage)
docker build -t my-app:prod .
```

### Pattern 3: Development Stage

```dockerfile
# Builder
FROM python:3.10-slim AS builder
RUN pip install scikit-learn pandas

# Development stage (includes dev tools)
FROM builder AS development
RUN pip install pytest black mypy ipython
COPY . .
CMD ["bash"]

# Production stage (minimal)
FROM python:3.10-slim AS production
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY src ./src
CMD ["python", "src/main.py"]
```

**Usage**:
```bash
# Development image (includes dev tools)
docker build --target development -t my-app:dev .
docker run -it my-app:dev bash

# Production image (minimal)
docker build --target production -t my-app:prod .
```

---

## Code Walkthrough

### File: `docker/Dockerfile.api` (Multi-Stage)

```dockerfile
# ============================================================
# Stage 1: Builder
# ============================================================
FROM python:3.10-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*
# Purpose: Compile packages with C extensions (e.g., scikit-learn)

# Copy requirements and install Python dependencies
COPY requirements ./requirements
COPY pyproject.toml README.md ./

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements/api.txt
# Installs: fastapi, uvicorn, scikit-learn, pandas, etc.
# Result: Compiled packages in /usr/local/lib/python3.10/site-packages

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM python:3.10-slim

WORKDIR /app

# Install runtime dependencies (no build tools!)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/* && \
    apt-get clean
# Only curl (for healthcheck), no gcc/g++!

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
# Copies: scikit-learn, fastapi, uvicorn executables
# Doesn't copy: gcc, g++, build-essential

# Copy application code
COPY pyproject.toml README.md ./
COPY config ./config
COPY src ./src

# Install the package (in editable mode)
RUN pip install --no-cache-dir .

# Create directories
RUN mkdir -p /app/artifacts/{models,registry} && \
    chmod -R 755 /app/artifacts

# Create non-root user
RUN groupadd -r apiuser && useradd -r -g apiuser apiuser && \
    chown -R apiuser:apiuser /app

USER apiuser

# Environment variables
ENV CHURN_MLOPS_CONFIG=/app/config/config.yaml \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Metadata
ARG BUILD_DATE
ARG VCS_REF
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="Churn MLOps API" \
      org.opencontainers.image.description="Real-time prediction API" \
      org.opencontainers.image.vendor="TechITFactory"

CMD ["uvicorn", "churn_mlops.api.app:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Size Comparison**:
```bash
# Single-stage (hypothetical)
docker build -f Dockerfile.single -t api:single .
api:single    1.2 GB

# Multi-stage (actual)
docker build -f docker/Dockerfile.api -t api:multi .
api:multi     320 MB  (4× smaller!)
```

### File: `docker/Dockerfile.ml` (ML Container)

```dockerfile
# Stage 1: Builder
FROM python:3.10-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

COPY requirements ./requirements
COPY pyproject.toml README.md ./

# Install base + dev dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    -r requirements/base.txt \
    -r requirements/dev.txt && \
    if [ -f requirements/serving.txt ]; then \
      pip install --no-cache-dir -r requirements/serving.txt; \
    fi

# Stage 2: Runtime
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    bash \
    && rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application
COPY src ./src
COPY config ./config
COPY scripts ./scripts
COPY pyproject.toml README.md ./

# Make scripts executable
RUN chmod +x ./scripts/*.sh

# Install package
RUN pip install --no-cache-dir .

# Create directories
RUN mkdir -p /app/data/{raw,processed,features,predictions} \
    /app/artifacts/{models,metrics,reports,registry} && \
    chmod -R 755 /app/data /app/artifacts

# Non-root user
RUN groupadd -r mlops && useradd -r -g mlops mlops && \
    chown -R mlops:mlops /app

USER mlops

ENV CHURN_MLOPS_CONFIG=/app/config/config.yaml \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import churn_mlops; print('healthy')" || exit 1

ARG BUILD_DATE
ARG VCS_REF
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="Churn MLOps ML" \
      org.opencontainers.image.description="ML training and batch scoring container" \
      org.opencontainers.image.vendor="TechITFactory"

CMD ["bash"]
```

---

## Hands-On Exercise

### Exercise 1: Single-Stage vs Multi-Stage Comparison

Create single-stage Dockerfile:

```dockerfile
# File: Dockerfile.single
FROM python:3.10-slim

WORKDIR /app

# Install build tools (not removed!)
RUN apt-get update && apt-get install -y \
    build-essential gcc g++

COPY requirements/api.txt .
RUN pip install -r api.txt

COPY src ./src
CMD ["python", "-m", "uvicorn", "src.churn_mlops.api.app:app"]
```

Build and compare:

```bash
# Build single-stage
docker build -f Dockerfile.single -t churn-api:single .

# Build multi-stage
docker build -f docker/Dockerfile.api -t churn-api:multi .

# Compare sizes
docker images | grep churn-api
# churn-api:single   800 MB
# churn-api:multi    320 MB  (60% smaller!)

# Check for build tools
docker run --rm churn-api:single which gcc
# /usr/bin/gcc  ← Present (bad!)

docker run --rm churn-api:multi which gcc
# (no output)  ← Not present (good!)
```

### Exercise 2: Build with Build Args

```bash
# Build with metadata
docker build \
  -f docker/Dockerfile.api \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t techitfactory/churn-api:v1.0.0 \
  .

# Check labels
docker inspect techitfactory/churn-api:v1.0.0 | grep -A 10 Labels
```

### Exercise 3: Build Specific Stage

```dockerfile
# Add test stage to Dockerfile.api (after builder, before runtime)
FROM builder AS test
COPY tests ./tests
COPY src ./src
RUN pip install pytest
RUN pytest tests/
```

Build and test:

```bash
# Build up to test stage (runs tests)
docker build --target test -t churn-api:test -f docker/Dockerfile.api .

# If tests pass, build production
docker build --target production -t churn-api:prod -f docker/Dockerfile.api .
```

### Exercise 4: Analyze Layer Sizes

```bash
# Build image
docker build -f docker/Dockerfile.api -t analyze:latest .

# Analyze layers
docker history analyze:latest

# Example output:
# IMAGE          CREATED BY                                      SIZE
# abc123         CMD ["uvicorn", ...]                           0B
# def456         HEALTHCHECK ...                                0B
# ghi789         EXPOSE 8000                                    0B
# jkl012         ENV ...                                        0B
# mno345         USER apiuser                                   0B
# pqr678         COPY --from=builder /usr/local/lib ...         250MB  ← Packages
# stu901         FROM python:3.10-slim                          125MB  ← Base
```

### Exercise 5: Multi-Builder Pattern

```dockerfile
# Dockerfile.multi-builder
FROM python:3.10-slim AS python-builder
COPY requirements.txt .
RUN pip install -r requirements.txt

FROM alpine:3.18 AS config-builder
COPY config.yaml.template config.yaml.template
RUN apk add --no-cache envsubst
RUN envsubst < config.yaml.template > config.yaml

FROM python:3.10-slim
COPY --from=python-builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=config-builder /config.yaml /app/config.yaml
COPY src /app/src
```

---

## Assessment Questions

### Question 1: Multiple Choice
What is the main benefit of multi-stage builds?

A) Faster builds  
B) **Smaller, more secure images** ✅  
C) Easier to write  
D) Better caching  

**Explanation**: Multi-stage builds discard build tools, resulting in smaller images with reduced attack surface.

---

### Question 2: True/False
**Statement**: In multi-stage builds, all stages are included in the final image.

**Answer**: False ❌  
**Explanation**: Only the **last stage** (or `--target` stage) is included. Earlier stages are discarded.

---

### Question 3: Short Answer
Why copy `/usr/local/lib/python3.10/site-packages` from builder to runtime?

**Answer**:
- Contains compiled Python packages (scikit-learn, pandas, etc.)
- Pre-compiled → No need for build tools in runtime
- Runtime can import packages without gcc/g++

---

### Question 4: Code Analysis
What's wrong with this multi-stage Dockerfile?

```dockerfile
FROM python:3.10-slim AS builder
RUN apt-get install -y gcc g++
RUN pip install scikit-learn

FROM python:3.10-slim
RUN pip install scikit-learn  # ← Problem!
COPY src /app/src
```

**Answer**:
- Runtime stage reinstalls packages (defeats purpose!)
- Should copy from builder instead:
  ```dockerfile
  COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
  ```
- Current version: Still needs build tools (not multi-stage benefit)

---

### Question 5: Design Challenge
Your image needs Python packages AND Node.js-built frontend assets. Design multi-stage build.

**Answer**:
```dockerfile
# Python builder
FROM python:3.10-slim AS python-builder
COPY requirements.txt .
RUN pip install -r requirements.txt

# Node.js builder
FROM node:18 AS node-builder
COPY package.json package-lock.json ./
RUN npm ci
COPY frontend ./frontend
RUN npm run build  # → Creates frontend/dist

# Runtime: Combine both
FROM python:3.10-slim
COPY --from=python-builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=node-builder /app/frontend/dist /app/static
COPY src /app/src
```

---

## Key Takeaways

### ✅ What You Learned

1. **Multi-Stage Benefits**
   - 60-75% smaller images
   - No build tools in production (security)
   - Cleaner separation (builder vs runtime)

2. **Stage Syntax**
   - `FROM image AS stage-name` → Named stage
   - `COPY --from=stage-name` → Copy between stages
   - Only last stage in final image

3. **What to Copy**
   - ✅ Compiled packages (`site-packages`)
   - ✅ Executables (`/usr/local/bin`)
   - ❌ Build tools (gcc, g++, cmake)
   - ❌ Source code (unless needed)

4. **Advanced Patterns**
   - Multiple builders (Python + Node)
   - Test stage (fail build if tests fail)
   - Development vs production stages

5. **Size Optimization**
   - Single-stage: 1.2 GB
   - Multi-stage: 300 MB (4× smaller)

---

## Next Steps

Continue to **[Section 14: Container Optimization](section-14-container-optimization.md)**

In the next section, we'll:
- Optimize layer caching
- Minimize image size further
- Implement security hardening
- Use BuildKit features

---

## Additional Resources

- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Best Practices for Python Docker Images](https://pythonspeed.com/articles/docker-caching-model/)
- [Reducing Docker Image Size](https://docs.docker.com/develop/dev-best-practices/)

---

**Progress**: 11/34 sections complete (32%) → **12/34 (35%)**
