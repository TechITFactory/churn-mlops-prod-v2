#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root (works even if run from another directory)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Activate venv if present
if [ -f "${REPO_ROOT}/.venv/bin/activate" ]; then
  # shellcheck disable=SC1090
  source "${REPO_ROOT}/.venv/bin/activate"
fi

PYTHON_BIN="${PYTHON_BIN:-python3}"
if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

LOCAL_REGISTRY="${REPO_ROOT}/artifacts/registry"
LOCAL_MODELS="${REPO_ROOT}/artifacts/models"
LOCAL_PRED="${REPO_ROOT}/data/predictions"

CONTAINER_REGISTRY="/app/artifacts/registry"
CONTAINER_MODELS="/app/artifacts/models"
CONTAINER_PRED="/app/data/predictions"

dir_nonempty() {
  local d="$1"
  [ -d "$d" ] && [ "$(ls -A "$d" 2>/dev/null | wc -l)" -gt 0 ]
}

# If user explicitly set CHURN_MLOPS_CONFIG and it exists, trust it
if [ "${CHURN_MLOPS_CONFIG:-}" != "" ] && [ -f "${CHURN_MLOPS_CONFIG}" ]; then
  echo "Using CHURN_MLOPS_CONFIG=${CHURN_MLOPS_CONFIG}"
  "${PYTHON_BIN}" -m churn_mlops.inference.batch_score
  exit 0
fi

TMP_CFG=""
cleanup() { [ -n "${TMP_CFG}" ] && rm -f "${TMP_CFG}"; }
trap cleanup EXIT

# Prefer container if it has any model artifacts and we can write predictions
if dir_nonempty "${CONTAINER_MODELS}" || dir_nonempty "${CONTAINER_REGISTRY}"; then
  mkdir -p "${CONTAINER_PRED}" 2>/dev/null || true

  if [ -f "/app/config/config.yaml" ]; then
    export CHURN_MLOPS_CONFIG="/app/config/config.yaml"
    echo "Detected container artifacts. Using ${CHURN_MLOPS_CONFIG}"
  else
    TMP_CFG="$(mktemp)"
    cat > "${TMP_CFG}" <<YAML
paths:
  raw: /app/data/raw
  processed: /app/data/processed
  features: /app/data/features
  predictions: /app/data/predictions
  artifacts: /app/artifacts
  models: /app/artifacts/models
  metrics: /app/artifacts/metrics
  registry: /app/artifacts/registry
YAML
    export CHURN_MLOPS_CONFIG="${TMP_CFG}"
    echo "Detected container artifacts. Using generated config ${CHURN_MLOPS_CONFIG}"
  fi

# Otherwise use local
else
  mkdir -p "${LOCAL_PRED}" 2>/dev/null || true

  if [ -f "${REPO_ROOT}/configs/config.yaml" ]; then
    export CHURN_MLOPS_CONFIG="${REPO_ROOT}/configs/config.yaml"
    echo "Using ${CHURN_MLOPS_CONFIG}"
  else
    TMP_CFG="$(mktemp)"
    cat > "${TMP_CFG}" <<YAML
paths:
  raw: ${REPO_ROOT}/data/raw
  processed: ${REPO_ROOT}/data/processed
  features: ${REPO_ROOT}/data/features
  predictions: ${REPO_ROOT}/data/predictions
  artifacts: ${REPO_ROOT}/artifacts
  models: ${REPO_ROOT}/artifacts/models
  metrics: ${REPO_ROOT}/artifacts/metrics
  registry: ${REPO_ROOT}/artifacts/registry
YAML
    export CHURN_MLOPS_CONFIG="${TMP_CFG}"
    echo "Using generated config ${CHURN_MLOPS_CONFIG}"
  fi
fi

"${PYTHON_BIN}" -m churn_mlops.inference.batch_score
