# Section 12: Docker Fundamentals

**Duration**: 2.5 hours  
**Level**: Intermediate  
**Prerequisites**: Basic command line knowledge

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Understand Docker architecture and concepts
- ✅ Write Dockerfiles with best practices
- ✅ Build Docker images efficiently
- ✅ Run containers with proper configurations
- ✅ Use Docker layers and caching
- ✅ Implement security best practices
- ✅ Debug container issues

---

## 📚 Table of Contents

1. [What is Docker?](#what-is-docker)
2. [Docker Architecture](#docker-architecture)
3. [Dockerfile Basics](#dockerfile-basics)
4. [Building Images](#building-images)
5. [Running Containers](#running-containers)
6. [Docker Best Practices](#docker-best-practices)
7. [Code Walkthrough](#code-walkthrough)
8. [Hands-On Exercise](#hands-on-exercise)
9. [Assessment Questions](#assessment-questions)

---

## What is Docker?

### Problem: "Works on My Machine"

```
Developer:   ✅ Works on my laptop (Python 3.10.5, pandas 2.0.1)
Staging:     ❌ Fails (Python 3.9.7, pandas 1.5.3)
Production:  ❌ Fails (Python 3.11.0, different libraries)

CI/CD:       ❌ Fails (missing system dependencies)
Colleague:   ❌ Can't reproduce (different OS)
```

**Traditional Approach** (Manual Setup):
1. Install Python 3.10.5
2. Install system dependencies (gcc, libpq-dev, ...)
3. Create virtual environment
4. Install packages (100+ lines in requirements.txt)
5. Set environment variables
6. Configure paths
7. Pray it works 🙏

**Docker Approach**:
```bash
docker run techitfactory/churn-ml:v1.0.0
# ✅ Works everywhere (same image = same environment)
```

### Docker Definition

> **Docker**: Platform for packaging applications with all dependencies into **containers** (lightweight, isolated environments)

**Analogy**: Shipping containers 📦
- Physical goods → Standardized containers → Ship anywhere
- Software → Docker containers → Run anywhere

---

## Docker Architecture

### Components

```
┌─────────────────────────────────────────────┐
│          Docker Architecture                │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────┐        ┌──────────────┐  │
│  │ Dockerfile   │ ──────→│ Docker Image │  │
│  │ (recipe)     │ build  │ (template)   │  │
│  └──────────────┘        └──────┬───────┘  │
│                                 │           │
│                                 │ run       │
│                                 ↓           │
│                          ┌──────────────┐  │
│                          │ Container    │  │
│                          │ (instance)   │  │
│                          └──────────────┘  │
│                                             │
│  Docker Engine (manages containers)         │
└─────────────────────────────────────────────┘
```

| Component | Description | Analogy |
|-----------|-------------|---------|
| **Dockerfile** | Text file with instructions | Recipe |
| **Image** | Read-only template | Class (OOP) |
| **Container** | Running instance | Object (OOP) |
| **Registry** | Image storage (Docker Hub) | GitHub for images |

### Image vs Container

```python
# Think of it like Python classes:

class ChurnMLImage:
    """Docker Image = Class definition"""
    python_version = "3.10"
    dependencies = ["scikit-learn", "pandas", ...]
    code = "src/churn_mlops/"
    
    def run(self):
        """Start container"""
        pass

# Create containers (instances)
container1 = ChurnMLImage()  # Container 1 (runs training)
container2 = ChurnMLImage()  # Container 2 (runs batch score)
container3 = ChurnMLImage()  # Container 3 (runs API)

# All containers share same Image (code + dependencies)
# But each has isolated filesystem, process, network
```

**Key Point**: 
- 1 Image → Many Containers
- Containers are ephemeral (delete/recreate anytime)
- Images are immutable (never change after build)

---

## Dockerfile Basics

### Simple Example

```dockerfile
# Start from base image (Python 3.10)
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install dependencies
RUN pip install -r requirements.txt

# Copy application code
COPY src/ ./src/

# Run command when container starts
CMD ["python", "src/main.py"]
```

**Building**:
```bash
docker build -t my-app:v1 .
```

**Running**:
```bash
docker run my-app:v1
```

### Common Dockerfile Instructions

| Instruction | Purpose | Example |
|-------------|---------|---------|
| `FROM` | Base image | `FROM python:3.10-slim` |
| `WORKDIR` | Set working directory | `WORKDIR /app` |
| `COPY` | Copy files from host | `COPY src/ ./src/` |
| `RUN` | Execute command (build time) | `RUN pip install pandas` |
| `CMD` | Default command (runtime) | `CMD ["python", "main.py"]` |
| `ENTRYPOINT` | Main executable | `ENTRYPOINT ["python"]` |
| `ENV` | Environment variable | `ENV PYTHONUNBUFFERED=1` |
| `EXPOSE` | Document port | `EXPOSE 8000` |
| `ARG` | Build argument | `ARG VERSION=1.0` |
| `USER` | Switch user | `USER appuser` |

### RUN vs CMD vs ENTRYPOINT

```dockerfile
# RUN: Execute at build time (creates layer)
RUN pip install pandas  # Installs pandas in image

# CMD: Default command at runtime (can be overridden)
CMD ["python", "main.py"]

# Override CMD:
# docker run my-app python train.py  ← Replaces CMD

# ENTRYPOINT: Main executable (harder to override)
ENTRYPOINT ["python"]
CMD ["main.py"]  # Arguments to ENTRYPOINT

# Run:
# docker run my-app  → python main.py
# docker run my-app train.py  → python train.py (only CMD overridden)
```

---

## Building Images

### Build Command

```bash
docker build [OPTIONS] PATH

# Examples:
docker build -t my-app:v1.0 .
# -t: Tag (name:version)
# .: Context (current directory)

docker build -f docker/Dockerfile.api -t techitfactory/churn-api:v1.0 .
# -f: Specify Dockerfile path
```

### Build Context

```
Build Context = Files sent to Docker daemon for building

Example:
.
├── src/           ← Included
├── data/          ← Included (large! 1GB)
├── .git/          ← Included (unnecessary!)
├── Dockerfile
└── .dockerignore  ← Excludes files

Docker sends entire directory to daemon
→ Slow build if large files included
→ Use .dockerignore!
```

### .dockerignore

```dockerignore
# Exclude from build context
__pycache__
*.pyc
.git
.github
.venv
venv/
.pytest_cache
.mypy_cache
*.egg-info
data/raw/*           # Large data files
artifacts/models/*   # Trained models
.env
.env.local
*.log
```

**Impact**:
```bash
# Without .dockerignore
Sending build context to Docker daemon  1.2GB  ← Slow!

# With .dockerignore
Sending build context to Docker daemon  10MB   ← Fast!
```

### Layer Caching

**Key Concept**: Docker caches each layer → Reuses if unchanged

```dockerfile
# ❌ BAD: Inefficient caching
FROM python:3.10-slim
COPY . /app              # Changes often → cache invalidated
RUN pip install -r /app/requirements.txt  # Reinstalls every time!
WORKDIR /app
CMD ["python", "main.py"]

# ✅ GOOD: Efficient caching
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .   # Changes rarely
RUN pip install -r requirements.txt  # Cached if requirements.txt unchanged!
COPY . .                  # Copy code last (changes often)
CMD ["python", "main.py"]
```

**Build Times**:
```
First build (no cache):
Step 1/5 : FROM python:3.10-slim     → 30s (download)
Step 2/5 : COPY requirements.txt     → 0.1s
Step 3/5 : RUN pip install           → 60s (install packages)
Step 4/5 : COPY . .                  → 0.2s
Step 5/5 : CMD ["python", "main.py"] → 0.1s
Total: 90s

Second build (code changed, cache used):
Step 1/5 : FROM python:3.10-slim     → 0s (cached)
Step 2/5 : COPY requirements.txt     → 0s (cached)
Step 3/5 : RUN pip install           → 0s (cached!) ← Reuses layer
Step 4/5 : COPY . .                  → 0.2s (changed)
Step 5/5 : CMD ["python", "main.py"] → 0.1s
Total: 0.3s (300× faster!)
```

---

## Running Containers

### Basic Run

```bash
# Run container
docker run [OPTIONS] IMAGE [COMMAND]

# Examples:
docker run python:3.10 python --version
# → Runs Python in container, prints version, exits

docker run -it python:3.10 bash
# -i: Interactive (keep STDIN open)
# -t: TTY (pseudo-terminal)
# → Opens bash shell inside container
```

### Common Options

```bash
# Port mapping
docker run -p 8000:8000 techitfactory/churn-api:v1
# -p HOST:CONTAINER → Maps host port 8000 to container port 8000

# Detached mode (background)
docker run -d -p 8000:8000 techitfactory/churn-api:v1
# -d: Detached (runs in background)

# Name container
docker run -d --name my-api techitfactory/churn-api:v1
# --name: Give container a name (easier to reference)

# Volume mount
docker run -v $(pwd)/data:/app/data techitfactory/churn-ml:v1
# -v HOST:CONTAINER → Mount host directory into container

# Environment variables
docker run -e PYTHONUNBUFFERED=1 -e DEBUG=true my-app
# -e: Set environment variable

# Remove after exit
docker run --rm my-app
# --rm: Automatically remove container after exit
```

### Container Lifecycle

```bash
# 1. Create and start
docker run -d --name my-container my-image

# 2. Check status
docker ps               # Running containers
docker ps -a            # All containers (including stopped)

# 3. View logs
docker logs my-container
docker logs -f my-container  # Follow (tail)

# 4. Execute command in running container
docker exec -it my-container bash
# Opens bash shell in running container

# 5. Stop container
docker stop my-container

# 6. Start stopped container
docker start my-container

# 7. Remove container
docker rm my-container
docker rm -f my-container  # Force remove (even if running)
```

### Useful Commands

```bash
# List images
docker images

# Remove image
docker rmi my-image:v1

# Remove dangling images (unused)
docker image prune

# Remove all stopped containers
docker container prune

# View container resource usage
docker stats

# Inspect container details
docker inspect my-container

# Copy files from container
docker cp my-container:/app/model.pkl ./model.pkl
```

---

## Docker Best Practices

### 1. Use Minimal Base Images

```dockerfile
# ❌ BAD: Large base image
FROM ubuntu:22.04         # ~77MB
RUN apt-get install python3  # + another ~100MB

# ✅ GOOD: Minimal base
FROM python:3.10-slim     # ~125MB (includes Python)

# ✅ BETTER: Alpine (very small)
FROM python:3.10-alpine   # ~50MB
# Note: May need to compile packages (slower build)
```

### 2. Minimize Layers

```dockerfile
# ❌ BAD: Many RUN commands = many layers
RUN pip install pandas
RUN pip install scikit-learn
RUN pip install fastapi
RUN pip install uvicorn

# ✅ GOOD: Combine commands
RUN pip install pandas scikit-learn fastapi uvicorn
```

### 3. Clean Up in Same Layer

```dockerfile
# ❌ BAD: Cleanup in separate layer (doesn't reduce size!)
RUN apt-get update && apt-get install -y build-essential
RUN apt-get clean  # Too late! Layer already saved

# ✅ GOOD: Cleanup in same RUN command
RUN apt-get update && apt-get install -y build-essential \
    && rm -rf /var/lib/apt/lists/*  # Cleanup in same layer
```

### 4. Use .dockerignore

```dockerignore
# Always exclude:
.git
.github
__pycache__
*.pyc
.pytest_cache
.venv
venv/
*.log
.env
```

### 5. Run as Non-Root User

```dockerfile
# ❌ BAD: Run as root (security risk)
CMD ["python", "app.py"]

# ✅ GOOD: Create non-root user
RUN useradd -m -u 1000 appuser
USER appuser
CMD ["python", "app.py"]
```

### 6. Use HEALTHCHECK

```dockerfile
# Add health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Kubernetes can use this to restart unhealthy containers
```

### 7. Label Images

```dockerfile
# Add metadata
LABEL org.opencontainers.image.title="Churn MLOps API"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.vendor="TechITFactory"
```

---

## Code Walkthrough

### File: `docker/Dockerfile.api`

Let's analyze our production API Dockerfile:

```dockerfile
# Stage 1: Builder
FROM python:3.10-slim AS builder
# AS builder → Named stage (for multi-stage builds)

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*
# --no-install-recommends: Skip unnecessary packages
# && rm -rf /var/lib/apt/lists/*: Cleanup in same layer

# Copy requirements and install Python dependencies
COPY requirements ./requirements
COPY pyproject.toml README.md ./

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements/api.txt
# --no-cache-dir: Don't cache pip downloads (saves space)

# Stage 2: Runtime
FROM python:3.10-slim
# Fresh base → Doesn't include build tools (smaller!)

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Copy Python packages from builder (entire site-packages to preserve paths)
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
# --from=builder: Copy from named stage (multi-stage build)

# Copy application code
COPY pyproject.toml README.md ./
COPY config ./config
COPY src ./src

# Install the package
RUN pip install --no-cache-dir .

# Create necessary directories with proper permissions
RUN mkdir -p /app/artifacts/{models,registry} && \
    chmod -R 755 /app/artifacts

# Create non-root user for security
RUN groupadd -r apiuser && useradd -r -g apiuser apiuser && \
    chown -R apiuser:apiuser /app

USER apiuser
# Switch to non-root user (security best practice)

# Environment variables
ENV CHURN_MLOPS_CONFIG=/app/config/config.yaml \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

EXPOSE 8000
# Document port (doesn't actually publish it)

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Labels for metadata
ARG BUILD_DATE
ARG VCS_REF
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="Churn MLOps API" \
      org.opencontainers.image.description="Real-time prediction API" \
      org.opencontainers.image.vendor="TechITFactory"

CMD ["uvicorn", "churn_mlops.api.app:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Key Features**:
- ✅ Multi-stage build (builder + runtime)
- ✅ Non-root user (security)
- ✅ Health check (monitoring)
- ✅ Minimal layers (combined commands)
- ✅ Cleanup in same layer
- ✅ Metadata labels

---

## Hands-On Exercise

### Exercise 1: Build and Run API Image

```bash
# Navigate to project root
cd /path/to/churn-mlops-prod

# Build API image
docker build -f docker/Dockerfile.api -t techitfactory/churn-api:v1.0 .

# Check image size
docker images | grep churn-api

# Run container
docker run -d -p 8000:8000 --name churn-api techitfactory/churn-api:v1.0

# Check logs
docker logs -f churn-api

# Test API
curl http://localhost:8000/health

# Stop and remove
docker stop churn-api
docker rm churn-api
```

### Exercise 2: Interactive Container Exploration

```bash
# Run container with bash
docker run -it --rm techitfactory/churn-api:v1.0 bash

# Inside container:
whoami            # Should be "apiuser" (non-root)
pwd               # /app
ls -la            # See application files
python --version  # 3.10.x
pip list          # Installed packages
exit
```

### Exercise 3: Build ML Image

```bash
# Build ML image
docker build -f docker/Dockerfile.ml -t techitfactory/churn-ml:v1.0 .

# Compare sizes
docker images | grep techitfactory

# Run training in container
docker run --rm -v $(pwd)/data:/app/data -v $(pwd)/artifacts:/app/artifacts \
    techitfactory/churn-ml:v1.0 \
    python -m churn_mlops.training.train_baseline

# Check artifacts
ls -lh artifacts/models/
```

### Exercise 4: Debug Container

```bash
# Run container in background
docker run -d --name debug-test techitfactory/churn-api:v1.0

# Execute commands in running container
docker exec debug-test python --version
docker exec debug-test pip list
docker exec debug-test ls -la /app

# Open shell in running container
docker exec -it debug-test bash

# Inside container:
cat config/config.yaml
python -c "import churn_mlops; print(churn_mlops.__version__)"
exit

# View logs
docker logs debug-test

# Cleanup
docker rm -f debug-test
```

### Exercise 5: Layer Analysis

```bash
# Build with output
docker build -f docker/Dockerfile.api -t test:api .

# Analyze layers
docker history test:api

# Check which layers are cached (rebuild)
docker build -f docker/Dockerfile.api -t test:api .
# Should see "CACHED" for most steps

# Modify code and rebuild
echo "# test change" >> src/churn_mlops/__init__.py
docker build -f docker/Dockerfile.api -t test:api .
# Only steps after COPY src will rebuild
```

---

## Assessment Questions

### Question 1: Multiple Choice
What's the difference between an Image and a Container?

A) Image runs, Container is stored  
B) **Image is template, Container is running instance** ✅  
C) They are the same thing  
D) Container is smaller than Image  

**Explanation**: Image = Class (template), Container = Object (instance)

---

### Question 2: True/False
**Statement**: `RUN` commands execute when you run a container.

**Answer**: False ❌  
**Explanation**: `RUN` executes at **build time** (creates layers). `CMD` executes at **runtime**.

---

### Question 3: Short Answer
Why should you copy `requirements.txt` before copying application code?

**Answer**:
- Docker caching! If `requirements.txt` unchanged → layer cached → no reinstall
- Code changes often, dependencies change rarely
- Order: COPY requirements → RUN pip install (cached!) → COPY code (changed)

---

### Question 4: Code Fix
What's wrong with this Dockerfile?

```dockerfile
FROM python:3.10-slim
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
```

**Answer**:
```dockerfile
FROM python:3.10-slim
WORKDIR /app  # Set WORKDIR first

# Copy and install dependencies first (better caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy code last (changes often)
COPY . .

CMD ["python", "app.py"]
```

---

### Question 5: Design Challenge
Your image is 2GB. How do you reduce it?

**Answer**:
1. Use smaller base image (`python:3.10-slim` instead of `python:3.10`)
2. Multi-stage build (builder + runtime, discard build tools)
3. Combine RUN commands (fewer layers)
4. Clean up in same layer (`&& rm -rf /var/lib/apt/lists/*`)
5. Use `.dockerignore` (exclude unnecessary files)
6. `pip install --no-cache-dir` (don't cache pip downloads)

---

## Key Takeaways

### ✅ What You Learned

1. **Docker Concepts**
   - Image = Template, Container = Instance
   - Dockerfile = Recipe for building images
   - Docker Engine = Platform for running containers

2. **Dockerfile Instructions**
   - `FROM`: Base image
   - `RUN`: Build-time commands
   - `CMD`: Runtime default command
   - `COPY`: Copy files
   - `WORKDIR`: Set directory

3. **Build Optimization**
   - Layer caching (order matters!)
   - Minimal base images (`slim`)
   - Combine RUN commands
   - Clean up in same layer

4. **Container Operations**
   - `docker build`: Create image
   - `docker run`: Start container
   - `docker ps`: List containers
   - `docker logs`: View output
   - `docker exec`: Run command in container

5. **Best Practices**
   - Use `.dockerignore`
   - Run as non-root user
   - Add HEALTHCHECK
   - Label images
   - Use multi-stage builds

---

## Next Steps

Continue to **[Section 13: Multi-Stage Docker Builds](section-13-multi-stage-builds.md)**

In the next section, we'll:
- Deep dive into multi-stage builds
- Separate builder and runtime stages
- Optimize image size (2GB → 300MB)
- Implement security best practices

---

## Additional Resources

- [Docker Official Docs](https://docs.docker.com/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Docker Layer Caching](https://docs.docker.com/build/cache/)
- [Python Docker Guide](https://docs.docker.com/language/python/)

---

**Progress**: 10/34 sections complete (29%) → **11/34 (32%)**
