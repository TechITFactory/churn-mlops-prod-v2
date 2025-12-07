FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
  && rm -rf /var/lib/apt/lists/*

COPY requirements ./requirements
COPY pyproject.toml README.md ./

RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements/base.txt \
 && pip install --no-cache-dir -r requirements/dev.txt \
 && pip install --no-cache-dir -r requirements/serving.txt || true

COPY src ./src
COPY config ./config

# ✅ scripts must exist in ML image
COPY scripts ./scripts
RUN chmod +x ./scripts/*.sh

RUN pip install --no-cache-dir .

ENV CHURN_MLOPS_CONFIG=/app/config/config.yaml

CMD ["bash"]
