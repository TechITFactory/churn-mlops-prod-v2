from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd


@dataclass
class ScoreProxy:
    mean: float
    p50: float
    p90: float
    p99: float
    high_risk_rate: float  # pct scores >= threshold


def summarize_scores(predictions_path: Path, threshold: float = 0.7) -> ScoreProxy:
    df = pd.read_csv(predictions_path)
    if "churn_risk" not in df.columns:
        raise ValueError("predictions file missing churn_risk column")

    s = df["churn_risk"].dropna().to_numpy(dtype=float)
    if len(s) == 0:
        return ScoreProxy(0, 0, 0, 0, 0)

    return ScoreProxy(
        mean=float(np.mean(s)),
        p50=float(np.quantile(s, 0.50)),
        p90=float(np.quantile(s, 0.90)),
        p99=float(np.quantile(s, 0.99)),
        high_risk_rate=float(np.mean(s >= threshold)),
    )


def write_proxy(predictions_path: Path, out_path: Path, threshold: float = 0.7):
    proxy = summarize_scores(predictions_path, threshold=threshold)
    payload = {
        "predictions": str(predictions_path),
        "threshold": threshold,
        "mean": proxy.mean,
        "p50": proxy.p50,
        "p90": proxy.p90,
        "p99": proxy.p99,
        "high_risk_rate": proxy.high_risk_rate,
    }
    out_path.write_text(json.dumps(payload, indent=2))
    return payload
