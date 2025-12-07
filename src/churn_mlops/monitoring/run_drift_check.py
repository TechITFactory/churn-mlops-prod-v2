from __future__ import annotations

import json
from pathlib import Path

from churn_mlops.common.config import load_config
from churn_mlops.monitoring.drift import compute_drift


def main():
    cfg = load_config()

    features_dir = Path(cfg["paths"]["features"])
    artifacts_metrics = Path(cfg["paths"]["metrics"])

    baseline = features_dir / "training_dataset.csv"
    current = features_dir / "user_features_daily.csv"

    # Minimal list; adjust as your features grow
    feature_cols = [
        "sessions_7d",
        "watch_minutes_7d",
        "watch_minutes_14d",
        "watch_minutes_30d",
        "quiz_attempts_7d",
        "quiz_avg_score_7d",
    ]

    report = compute_drift(
        baseline_path=baseline,
        current_path=current,
        feature_cols=feature_cols,
    )

    artifacts_metrics.mkdir(parents=True, exist_ok=True)
    out = artifacts_metrics / "data_drift_latest.json"

    payload = {
        "status": report.status,
        "overall_max_psi": report.overall_max_psi,
        "psi_by_feature": report.psi_by_feature,
        "baseline": str(baseline),
        "current": str(current),
    }

    out.write_text(json.dumps(payload, indent=2))
    print(json.dumps(payload, indent=2))

    # Non-zero exit helps CI / CronJob alert pattern
    if report.status == "FAIL":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
