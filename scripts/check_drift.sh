#!/usr/bin/env bash
set -euo pipefail
python -m churn_mlops.monitoring.run_drift_check
