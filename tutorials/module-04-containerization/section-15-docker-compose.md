# Section 15: Docker Compose

**Duration**: 2.5 hours  
**Level**: Intermediate  
**Prerequisites**: Sections 12-14 (Docker Fundamentals, Multi-Stage, Optimization)

---

## 🎯 Learning Objectives

By the end of this section, you will:
- ✅ Orchestrate multi-container applications
- ✅ Write production docker-compose.yml files
- ✅ Manage volumes and networks
- ✅ Define service dependencies
- ✅ Implement development workflows
- ✅ Use environment variables and secrets
- ✅ Scale services dynamically

---

## 📚 Table of Contents

1. [What is Docker Compose?](#what-is-docker-compose)
2. [docker-compose.yml Syntax](#docker-compose-yml-syntax)
3. [Services](#services)
4. [Volumes](#volumes)
5. [Networks](#networks)
6. [Environment Variables](#environment-variables)
7. [Code Walkthrough](#code-walkthrough)
8. [Common Patterns](#common-patterns)
9. [Hands-On Exercise](#hands-on-exercise)
10. [Assessment Questions](#assessment-questions)

---

## What is Docker Compose?

### Problem: Manual Container Management

```bash
# Without Docker Compose: Manual orchestration

# 1. Create network
docker network create churn-network

# 2. Start database
docker run -d \
  --name postgres \
  --network churn-network \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  postgres:15

# 3. Start API
docker run -d \
  --name churn-api \
  --network churn-network \
  -p 8000:8000 \
  -e DATABASE_URL=postgres://postgres:secret@postgres:5432/churn \
  -v $(pwd)/artifacts:/app/artifacts \
  techitfactory/churn-api:v1.0

# 4. Start monitoring
docker run -d \
  --name prometheus \
  --network churn-network \
  -p 9090:9090 \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# Painful to manage:
# - 15+ lines per service
# - Hard to reproduce
# - Manual dependency management
# - Complex cleanup
```

### Solution: Docker Compose

```yaml
# docker-compose.yml
version: "3.9"

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - pgdata:/var/lib/postgresql/data
  
  churn-api:
    image: techitfactory/churn-api:v1.0
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgres://postgres:secret@postgres:5432/churn
    volumes:
      - ./artifacts:/app/artifacts
    depends_on:
      - postgres
  
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

volumes:
  pgdata:
```

**Commands**:
```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f

# That's it! 3 commands instead of 15+
```

### Benefits

| Benefit | Description |
|---------|-------------|
| **Declarative** | Define desired state, not commands |
| **Reproducible** | Same setup on dev/staging/prod |
| **Simple** | One command to start/stop all |
| **Service Discovery** | Services find each other by name |
| **Dependency Management** | Start services in order |
| **Volume Management** | Persistent data made easy |

---

## docker-compose.yml Syntax

### Basic Structure

```yaml
version: "3.9"  # Compose file version

services:       # Define containers
  service1:
    image: ...
    ports: ...
  service2:
    build: ...

volumes:        # Define named volumes
  data:

networks:       # Define networks
  backend:
```

### Version Compatibility

| Version | Docker Engine | Features |
|---------|---------------|----------|
| `3.0` | 1.13+ | Basic |
| `3.5` | 17.12+ | Named volumes |
| `3.8` | 19.03+ | Depends_on conditions |
| `3.9` | 19.03+ | **(Recommended)** |

**Recommendation**: Use `3.9` for maximum compatibility

---

## Services

### Service Definition

```yaml
services:
  churn-api:
    # Image (from registry)
    image: techitfactory/churn-api:v1.0
    
    # Or build from Dockerfile
    build:
      context: .
      dockerfile: docker/Dockerfile.api
      args:
        BUILD_DATE: "2024-01-15"
    
    # Container name
    container_name: churn-api-container
    
    # Port mapping
    ports:
      - "8000:8000"      # host:container
      - "8001:8001"
    
    # Environment variables
    environment:
      PYTHONUNBUFFERED: 1
      DEBUG: "false"
      DATABASE_URL: postgres://postgres:secret@postgres:5432/churn
    
    # Or from .env file
    env_file:
      - .env
      - .env.production
    
    # Volumes
    volumes:
      - ./artifacts:/app/artifacts        # bind mount
      - model-data:/app/models            # named volume
    
    # Networks
    networks:
      - backend
      - frontend
    
    # Depends on (start order)
    depends_on:
      - postgres
    
    # Restart policy
    restart: unless-stopped
    
    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

### Build Configuration

```yaml
services:
  churn-api:
    build:
      context: .                    # Build context (path)
      dockerfile: docker/Dockerfile.api  # Dockerfile path
      args:                         # Build arguments
        BUILD_DATE: "2024-01-15"
        VCS_REF: abc123
      target: production            # Multi-stage target
      cache_from:                   # Cache sources
        - techitfactory/churn-api:latest
      labels:                       # Image labels
        app: churn-api
        version: v1.0
```

### Port Mapping

```yaml
services:
  api:
    ports:
      - "8000:8000"         # host:container
      - "8001"              # Random host port → 8001
      - "127.0.0.1:8002:8002"  # Bind to localhost only
```

### Restart Policies

| Policy | Behavior |
|--------|----------|
| `no` | Never restart (default) |
| `always` | Always restart (even after manual stop) |
| `on-failure` | Restart only if exits with error |
| `unless-stopped` | Restart unless manually stopped |

**Recommendation**: Use `unless-stopped` for production

---

## Volumes

### Types of Volumes

```yaml
services:
  churn-api:
    volumes:
      # 1. Named volume (managed by Docker)
      - model-data:/app/models
      
      # 2. Bind mount (host directory)
      - ./artifacts:/app/artifacts
      
      # 3. Bind mount (absolute path)
      - /var/data:/app/data
      
      # 4. Read-only mount
      - ./config:/app/config:ro
      
      # 5. Tmpfs (memory)
      tmpfs:
        - /tmp

# Define named volumes
volumes:
  model-data:
    driver: local
```

### Named Volumes

```yaml
services:
  postgres:
    image: postgres:15
    volumes:
      - pgdata:/var/lib/postgresql/data  # Named volume

volumes:
  pgdata:                   # Define volume
    driver: local           # Local storage
    driver_opts:
      type: none
      o: bind
      device: /mnt/data/postgres  # Optional: Bind to host path
```

**Benefits**:
- ✅ Managed by Docker (location abstracted)
- ✅ Persist after container removal
- ✅ Can be shared between containers
- ✅ Easy backup/restore

### Bind Mounts vs Named Volumes

| Feature | Bind Mount | Named Volume |
|---------|------------|--------------|
| **Path** | Host path (./data) | Docker-managed |
| **Portability** | ⚠️ Host-specific | ✅ Portable |
| **Performance** | ✅ Fast | ✅ Fast |
| **Sharing** | ❌ Hard | ✅ Easy |
| **Backup** | Manual | `docker volume` commands |
| **Use Case** | Development (code changes) | Production (data) |

---

## Networks

### Network Types

```yaml
services:
  api:
    networks:
      - frontend
      - backend
  
  db:
    networks:
      - backend  # Not accessible from frontend

networks:
  frontend:
    driver: bridge  # Default
  backend:
    driver: bridge
    internal: true  # No external access
```

### Service Discovery

```yaml
services:
  api:
    environment:
      # Can reference other services by name!
      DATABASE_URL: postgres://user:pass@postgres:5432/db
      #                                    ^^^^^^^^ Service name
  
  postgres:
    image: postgres:15
```

**How it works**:
- Docker creates DNS entries for each service
- Service name → Container IP
- Example: `postgres` → `172.20.0.2`

### Network Aliases

```yaml
services:
  db-primary:
    image: postgres:15
    networks:
      backend:
        aliases:
          - database
          - db
  
  api:
    environment:
      # Can use alias instead of service name
      DATABASE_URL: postgres://user:pass@database:5432/db
```

---

## Environment Variables

### Method 1: Inline

```yaml
services:
  api:
    environment:
      DEBUG: "true"
      LOG_LEVEL: info
      DATABASE_URL: postgres://user:pass@db:5432/mydb
```

### Method 2: env_file

```yaml
services:
  api:
    env_file:
      - .env
      - .env.production
```

**File: `.env`**
```bash
DEBUG=true
LOG_LEVEL=info
DATABASE_URL=postgres://user:pass@db:5432/mydb
```

### Method 3: Variable Substitution

```yaml
services:
  api:
    image: techitfactory/churn-api:${VERSION:-latest}
    environment:
      DEBUG: ${DEBUG}
      DATABASE_URL: ${DATABASE_URL}
```

**Usage**:
```bash
# Set variables
export VERSION=v1.0.0
export DEBUG=false
export DATABASE_URL=postgres://...

# Run compose
docker-compose up
```

### Secrets (Docker Swarm)

```yaml
services:
  api:
    secrets:
      - db_password
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    file: ./db_password.txt  # Development
    # external: true           # Production (managed externally)
```

---

## Code Walkthrough

### File: `docker-compose.yml` (Development)

```yaml
version: "3.9"

services:
  churn-api:
    build:
      context: .
      dockerfile: docker/Dockerfile.api
    ports:
      - "8000:8000"
    
    # For demo only: mount artifacts if you want live model swap
    volumes:
      - ./artifacts:/app/artifacts
      - ./data:/app/data
    
    environment:
      CHURN_MLOPS_CONFIG: /app/config/config.yaml
      PYTHONUNBUFFERED: 1
    
    restart: unless-stopped
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**Usage**:
```bash
# Build and start
docker-compose up -d

# View logs
docker-compose logs -f churn-api

# Check status
docker-compose ps

# Stop
docker-compose down
```

### Production docker-compose.yml

```yaml
version: "3.9"

services:
  churn-api:
    image: techitfactory/churn-api:${VERSION:-v1.0.0}
    ports:
      - "8000:8000"
    
    # Named volumes (managed by Docker)
    volumes:
      - model-data:/app/artifacts
      - predictions:/app/data/predictions
    
    environment:
      CHURN_MLOPS_CONFIG: /app/config/config.yaml
      PYTHONUNBUFFERED: 1
      LOG_LEVEL: ${LOG_LEVEL:-info}
    
    restart: unless-stopped
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
    
    networks:
      - churn-network
    
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Batch scoring (periodic)
  churn-batch:
    image: techitfactory/churn-ml:${VERSION:-v1.0.0}
    command: ["python", "-m", "churn_mlops.scoring.batch_score"]
    
    volumes:
      - model-data:/app/artifacts:ro  # Read-only
      - predictions:/app/data/predictions
    
    environment:
      CHURN_MLOPS_CONFIG: /app/config/config.yaml
      PYTHONUNBUFFERED: 1
    
    networks:
      - churn-network
    
    profiles:
      - manual  # Not started by default (manual trigger)

volumes:
  model-data:
  predictions:

networks:
  churn-network:
    driver: bridge
```

---

## Common Patterns

### Pattern 1: Development + Production

```yaml
# docker-compose.yml (base)
version: "3.9"

services:
  api:
    image: techitfactory/churn-api:latest
    ports:
      - "8000:8000"

# docker-compose.override.yml (development, auto-loaded)
version: "3.9"

services:
  api:
    build: .                # Override: build locally
    volumes:
      - ./src:/app/src      # Mount source code (hot reload)
    environment:
      DEBUG: "true"

# docker-compose.prod.yml (production)
version: "3.9"

services:
  api:
    image: techitfactory/churn-api:v1.0.0  # Override: specific version
    restart: always
    deploy:
      replicas: 3
```

**Usage**:
```bash
# Development (auto-loads override)
docker-compose up

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

### Pattern 2: Profiles (Conditional Services)

```yaml
services:
  api:
    image: churn-api
  
  # Only start with --profile=monitoring
  prometheus:
    image: prom/prometheus
    profiles:
      - monitoring
  
  grafana:
    image: grafana/grafana
    profiles:
      - monitoring
  
  # Only start with --profile=debug
  debug-tools:
    image: nicolaka/netshoot
    profiles:
      - debug
```

**Usage**:
```bash
# Start API only
docker-compose up

# Start API + monitoring
docker-compose --profile monitoring up

# Start API + monitoring + debug
docker-compose --profile monitoring --profile debug up
```

### Pattern 3: Depends On (with Healthcheck)

```yaml
services:
  postgres:
    image: postgres:15
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 5s
      timeout: 3s
      retries: 5
  
  api:
    image: churn-api
    depends_on:
      postgres:
        condition: service_healthy  # Wait for health check
```

**Service Conditions**:
- `service_started`: Wait for service to start (default)
- `service_healthy`: Wait for health check to pass
- `service_completed_successfully`: Wait for service to exit with 0

### Pattern 4: Extending Services

```yaml
# Common configuration
x-common: &common
  restart: unless-stopped
  networks:
    - backend
  logging:
    driver: json-file
    options:
      max-size: "10m"

services:
  api1:
    <<: *common  # Merge common config
    image: churn-api:v1
  
  api2:
    <<: *common
    image: churn-api:v2
```

---

## Hands-On Exercise

### Exercise 1: Basic Compose

```yaml
# docker-compose.yml
version: "3.9"

services:
  churn-api:
    build:
      context: .
      dockerfile: docker/Dockerfile.api
    ports:
      - "8000:8000"
    volumes:
      - ./artifacts:/app/artifacts
```

**Commands**:
```bash
# Start
docker-compose up -d

# Check
docker-compose ps
curl http://localhost:8000/health

# Logs
docker-compose logs -f churn-api

# Stop
docker-compose down
```

### Exercise 2: Multi-Service Setup

```yaml
version: "3.9"

services:
  # ML training service
  churn-ml:
    build:
      context: .
      dockerfile: docker/Dockerfile.ml
    volumes:
      - ./data:/app/data
      - ./artifacts:/app/artifacts
    command: ["python", "-m", "churn_mlops.training.train_baseline"]
  
  # API service
  churn-api:
    build:
      context: .
      dockerfile: docker/Dockerfile.api
    ports:
      - "8000:8000"
    volumes:
      - ./artifacts:/app/artifacts
    depends_on:
      - churn-ml
```

**Commands**:
```bash
# Build and start
docker-compose up --build

# Train model (ml service)
docker-compose run churn-ml python -m churn_mlops.training.train_baseline

# Start API (uses trained model)
docker-compose up churn-api
```

### Exercise 3: Environment Variables

```yaml
# docker-compose.yml
version: "3.9"

services:
  api:
    image: churn-api:latest
    environment:
      LOG_LEVEL: ${LOG_LEVEL:-info}
      DEBUG: ${DEBUG:-false}
    env_file:
      - .env
```

**File: `.env`**
```bash
LOG_LEVEL=debug
DEBUG=true
MODEL_VERSION=v1.0.0
```

**Commands**:
```bash
# Use .env
docker-compose up

# Override with environment
LOG_LEVEL=error docker-compose up
```

### Exercise 4: Named Volumes

```yaml
version: "3.9"

services:
  api:
    image: churn-api
    volumes:
      - model-storage:/app/artifacts

volumes:
  model-storage:
```

**Commands**:
```bash
# Start
docker-compose up -d

# List volumes
docker volume ls

# Inspect volume
docker volume inspect $(docker-compose ps -q | head -1)

# Backup volume
docker run --rm -v model-storage:/data -v $(pwd):/backup alpine tar czf /backup/models.tar.gz /data

# Restore volume
docker run --rm -v model-storage:/data -v $(pwd):/backup alpine tar xzf /backup/models.tar.gz -C /
```

### Exercise 5: Scale Services

```yaml
version: "3.9"

services:
  api:
    image: churn-api
    ports:
      - "8000-8002:8000"  # Port range

  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - api
```

**Commands**:
```bash
# Scale to 3 instances
docker-compose up -d --scale api=3

# Check instances
docker-compose ps

# Load balance with nginx
# (nginx.conf needs upstream configuration)
```

---

## Assessment Questions

### Question 1: Multiple Choice
What command starts all services defined in docker-compose.yml?

A) `docker run`  
B) `docker start`  
C) **`docker-compose up`** ✅  
D) `docker-compose start`  

---

### Question 2: True/False
**Statement**: Named volumes persist after `docker-compose down`.

**Answer**: True ✅  
**Explanation**: Named volumes are not removed by `docker-compose down` (use `docker-compose down -v` to remove).

---

### Question 3: Short Answer
How do services find each other in Docker Compose?

**Answer**:
- Docker creates DNS entries for each service
- Service name → IP address
- Example: Service `postgres` accessible at `postgres:5432`

---

### Question 4: Code Analysis
What's wrong with this docker-compose.yml?

```yaml
version: "3.9"

services:
  api:
    image: churn-api
    depends_on:
      - postgres
  
  postgres:
    image: postgres:15
```

**Answer**:
- `depends_on` only ensures start order, not readiness
- API may start before Postgres is ready → Connection error
- Fix: Add healthcheck to postgres and use `service_healthy`:
  ```yaml
  postgres:
    healthcheck:
      test: ["CMD", "pg_isready"]
  api:
    depends_on:
      postgres:
        condition: service_healthy
  ```

---

### Question 5: Design Challenge
Design docker-compose.yml for API + Postgres + Monitoring (Prometheus).

**Answer**:
```yaml
version: "3.9"

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready"]
    networks:
      - backend
  
  api:
    image: churn-api:latest
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgres://postgres:secret@postgres:5432/churn
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - backend
      - frontend
  
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - frontend

volumes:
  pgdata:

networks:
  backend:
    internal: true  # No external access
  frontend:
```

---

## Key Takeaways

### ✅ What You Learned

1. **Docker Compose Benefits**
   - Declarative configuration
   - Multi-container orchestration
   - Simple commands (up/down/logs)
   - Reproducible environments

2. **Services**
   - Define containers
   - Port mapping
   - Environment variables
   - Dependencies

3. **Volumes**
   - Named volumes (Docker-managed)
   - Bind mounts (host directories)
   - Data persistence

4. **Networks**
   - Service discovery (DNS)
   - Network isolation
   - Aliases

5. **Common Commands**
   - `docker-compose up -d`: Start
   - `docker-compose down`: Stop
   - `docker-compose logs -f`: Logs
   - `docker-compose ps`: Status
   - `docker-compose exec`: Run command

---

## Next Steps

**Module 4 Complete!** 🎉 You've finished Containerization.

Continue to **[Module 05: Kubernetes](../../module-05-kubernetes/)**

In the next module, we'll:
- Deploy to Kubernetes
- Create Deployments and Services
- Manage configuration with ConfigMaps
- Implement rolling updates

---

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Compose File Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Compose Best Practices](https://docs.docker.com/compose/production/)

---

**Progress**: 13/34 sections complete (38%) → **14/34 (41%)**

**Module 4 Summary**:
- ✅ Section 12: Docker Fundamentals (2.5 hours)
- ✅ Section 13: Multi-Stage Builds (2 hours)
- ✅ Section 14: Container Optimization (2 hours)
- ✅ Section 15: Docker Compose (2.5 hours)

**Total Module 4**: 9 hours of content

Next: **Module 5: Kubernetes** →
