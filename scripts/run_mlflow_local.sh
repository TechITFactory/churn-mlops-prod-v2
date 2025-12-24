#!/usr/bin/env bash
set -euo pipefail

# Start local MLflow via Docker Compose.
# Why: this repo has a top-level `mlflow/` directory which can shadow the PyPI `mlflow` package.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

docker compose up -d mlflow

echo "MLflow UI: http://localhost:5001"
