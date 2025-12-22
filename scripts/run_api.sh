#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root (works even if run from another directory)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Activate venv if present
if [ -f "${REPO_ROOT}/.venv/bin/activate" ]; then
  # shellcheck disable=SC1090
  source "${REPO_ROOT}/.venv/bin/activate"
fi

# Auto-pick config unless user already set it
if [ "${CHURN_MLOPS_CONFIG:-}" = "" ]; then
  if [ -f "/app/config/config.yaml" ]; then
    export CHURN_MLOPS_CONFIG="/app/config/config.yaml"
    echo "Using container config: ${CHURN_MLOPS_CONFIG}"
  elif [ -f "${REPO_ROOT}/configs/config.yaml" ]; then
    export CHURN_MLOPS_CONFIG="${REPO_ROOT}/configs/config.yaml"
    echo "Using local config: ${CHURN_MLOPS_CONFIG}"
  else
    # fallback: repo default
    export CHURN_MLOPS_CONFIG="${REPO_ROOT}/config/config.yaml"
    echo "Using default config: ${CHURN_MLOPS_CONFIG}"
  fi
else
  echo "Using CHURN_MLOPS_CONFIG=${CHURN_MLOPS_CONFIG}"
fi

# Ensure editable install (useful for local dev)
pip install -e "${REPO_ROOT}" >/dev/null

# Run API
exec uvicorn churn_mlops.api.app:app --host 0.0.0.0 --port 8000
