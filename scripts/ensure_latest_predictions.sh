#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PRED_DIR="data/predictions"
LATEST_ALIAS="${PRED_DIR}/batch_predictions_latest.csv"

mkdir -p "${PRED_DIR}"

# Find newest churn_predictions_*.csv
LATEST_FILE="$(ls -1t ${PRED_DIR}/churn_predictions_*.csv 2>/dev/null | head -n 1 || true)"

if [[ -z "${LATEST_FILE}" ]]; then
  echo "❌ No churn_predictions_*.csv found in ${PRED_DIR}"
  echo "➡️  Run: ./scripts/batch_score.sh"
  exit 1
fi

# Copy to stable alias path expected by score proxy
cp -f "${LATEST_FILE}" "${LATEST_ALIAS}"

echo "✅ Latest alias updated:"
echo "   ${LATEST_ALIAS} -> $(basename "${LATEST_FILE}")"
