from __future__ import annotations

import time
from typing import Callable

from prometheus_client import Counter, Histogram

REQUEST_COUNT = Counter(
    "churn_api_requests_total",
    "Total HTTP requests",
    ["method", "path", "status"],
)

REQUEST_LATENCY = Histogram(
    "churn_api_request_latency_seconds",
    "Request latency in seconds",
    ["method", "path"],
)

PREDICTION_COUNT = Counter(
    "churn_api_predictions_total",
    "Total predictions served",
)


def metrics_middleware(app_name: str = "churn-mlops") -> Callable:
    async def middleware(request, call_next):
        start = time.perf_counter()
        response = None
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        finally:
            elapsed = time.perf_counter() - start
            path = request.url.path
            method = request.method
            REQUEST_LATENCY.labels(method=method, path=path).observe(elapsed)
            REQUEST_COUNT.labels(method=method, path=path, status=str(status_code)).inc()

    return middleware
