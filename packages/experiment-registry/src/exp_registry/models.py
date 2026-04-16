"""Experiment data model: load, save, validate YAML experiment files."""

import os
import re
from typing import Optional

import yaml


REQUIRED_FIELDS = {"id", "name", "type", "series", "date", "status"}
KNOWN_STATUSES = {"running", "completed", "failed", "abandoned", "data_ready"}


def infer_series(exp_id: str) -> str:
    """Infer series from experiment ID: exp07a -> exp07, exp07d-fake-short -> exp07."""
    m = re.match(r"(exp\d+)", exp_id)
    return m.group(1) if m else exp_id


def load_experiment(path: str) -> dict:
    """Load a single experiment YAML file and validate required fields."""
    with open(path, "r") as f:
        data = yaml.safe_load(f)

    if data is None:
        raise ValueError(f"Empty YAML file: {path}")

    missing = REQUIRED_FIELDS - set(data.keys())
    if missing:
        raise ValueError(f"Missing required fields: {missing} in {path}")

    if data["status"] not in KNOWN_STATUSES:
        raise ValueError(f"Invalid status '{data['status']}', must be one of {KNOWN_STATUSES}")

    # Defaults for optional structured fields
    data.setdefault("stages", [])
    data.setdefault("benchmarks", [])
    data.setdefault("findings", "")
    data.setdefault("paths", {})

    return data


def save_experiment(data: dict, path: str) -> None:
    """Save an experiment dict to a YAML file."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w") as f:
        yaml.dump(data, f, allow_unicode=True, default_flow_style=False, sort_keys=False)


def load_all_experiments(registry_dir: str) -> list[dict]:
    """Load all experiment YAML files from the registry directory."""
    experiments = []
    if not os.path.isdir(registry_dir):
        return experiments
    for fname in sorted(os.listdir(registry_dir)):
        if fname.endswith(".yaml") or fname.endswith(".yml"):
            exp = load_experiment(os.path.join(registry_dir, fname))
            experiments.append(exp)
    return experiments


def find_experiment(exp_id: str, registry_dir: str) -> Optional[dict]:
    """Find and load a single experiment by ID."""
    for ext in (".yaml", ".yml"):
        path = os.path.join(registry_dir, exp_id + ext)
        if os.path.exists(path):
            return load_experiment(path)
    # Fallback: scan all files
    for exp in load_all_experiments(registry_dir):
        if exp["id"] == exp_id:
            return exp
    return None
