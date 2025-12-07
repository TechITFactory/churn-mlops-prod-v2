from __future__ import annotations

import json
from pathlib import Path

from churn_mlops.common.config import load_config
from churn_mlops.monitoring.score_proxy import write_proxy


def main():
    cfg = load_config()
    preds_dir = Path(cfg["paths"]["predictions"])
    metrics_dir = Path(cfg["paths"]["metrics"])

    preds = preds_dir / "batch_predictions_latest.csv"
    metrics_dir.mkdir(parents=True, exist_ok=True)

    out = metrics_dir / "score_proxy_latest.json"
    payload = write_proxy(preds, out, threshold=0.7)
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
