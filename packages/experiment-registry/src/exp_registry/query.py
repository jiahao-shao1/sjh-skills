"""Query operations: filter and compare experiments."""

from typing import Optional


def filter_experiments(
    experiments: list[dict],
    status: Optional[str] = None,
    type: Optional[str] = None,
    series: Optional[str] = None,
) -> list[dict]:
    """Filter experiments by status, type, and/or series."""
    result = experiments
    if status:
        result = [e for e in result if e["status"] == status]
    if type:
        result = [e for e in result if e["type"] == type]
    if series:
        result = [e for e in result if e.get("series") == series]
    return result


def compare_experiments(
    experiments: list[dict],
    dataset: str,
    eval_mode: Optional[str] = None,
) -> dict:
    """Compare benchmark results across experiments for a given dataset.

    Returns: {"exp_ids": [...], "metrics": [...], "steps": {step: {exp_id: {metric: value}}}}
    """
    rows: dict[int, dict[str, dict]] = {}
    all_metrics: set[str] = set()

    for exp in experiments:
        for bm in exp.get("benchmarks", []):
            bm_dataset = bm.get("dataset", bm.get("benchmark", bm.get("name")))
            if bm_dataset != dataset:
                continue
            if eval_mode and bm.get("eval_mode") != eval_mode:
                continue
            for step, metrics in (bm.get("steps") or {}).items():
                try:
                    step_int = int(step)
                except (ValueError, TypeError):
                    continue
                rows.setdefault(step_int, {})[exp["id"]] = metrics
                all_metrics.update(metrics.keys())

    if not rows:
        raise ValueError(f"No benchmark data found for dataset '{dataset}'")

    return {
        "exp_ids": [e["id"] for e in experiments],
        "metrics": sorted(all_metrics),
        "steps": dict(sorted(rows.items())),
    }
