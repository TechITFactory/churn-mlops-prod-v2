from __future__ import annotations

import logging
import sys
from typing import Any, Dict, Optional

DEFAULT_LOGGER_NAME = "churn-mlops"


def get_logger(name: Optional[str] = None) -> logging.Logger:
    """
    Return a named logger. If no name provided, return default app logger.
    """
    return logging.getLogger(name or DEFAULT_LOGGER_NAME)


def setup_logging(
    cfg: Optional[Dict[str, Any]] = None,
    name: Optional[str] = None,
) -> logging.Logger:
    """
    Setup app-wide logging and return a logger.

    Expected config shape (optional):
      cfg["app"]["log_level"] = "INFO" | "DEBUG" | ...

    This function returns a logger so caller code can do:
      logger = setup_logging(cfg)
      logger.info("...")
    """
    level_str = "INFO"
    if cfg:
        level_str = (
            cfg.get("app", {}).get("log_level")
            or cfg.get("app", {}).get("loglevel")
            or "INFO"
        )

    level = getattr(logging, str(level_str).upper(), logging.INFO)

    root = logging.getLogger()

    # Remove existing handlers to prevent duplicate logs in tests/notebooks
    if root.handlers:
        for h in list(root.handlers):
            root.removeHandler(h)

    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    handler.setFormatter(formatter)

    root.addHandler(handler)
    root.setLevel(level)

    return get_logger(name)
