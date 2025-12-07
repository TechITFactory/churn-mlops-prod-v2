#!/usr/bin/env sh
set -e

CFG="${CHURN_MLOPS_CONFIG:-/app/config/config.yaml}"

echo "✅ Using config: $CFG"

# Ensure the predictions dir exists on the shared volume
mkdir -p data/predictions

echo "🚀 Running batch scoring..."
./scripts/batch_score.sh

# Create/refresh the "latest" alias expected by score_proxy
LATEST_FILE="$(ls -1t data/predictions/churn_predictions_*.csv 2>/dev/null | head -n 1 || true)"

if [ -z "$LATEST_FILE" ]; then
  echo "❌ No churn_predictions_*.csv found after batch scoring."
  exit 1
fi

cp "$LATEST_FILE" data/predictions/batch_predictions_latest.csv
echo "✅ Latest alias updated -> data/predictions/batch_predictions_latest.csv"

echo "📈 Writing proxy metrics..."
./scripts/score_proxy.sh

echo "✅ Batch + latest alias + proxy completed"
