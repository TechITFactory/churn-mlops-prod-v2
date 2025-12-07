#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

./scripts/ensure_latest_predictions.sh

# Run proxy scoring module
python -m churn_mlops.monitoring.run_score_proxy
