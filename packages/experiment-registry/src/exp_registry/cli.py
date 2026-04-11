"""Experiment Registry CLI — typer application."""

import json
import os
from datetime import date as date_type
from typing import Optional

import typer
import yaml
from rich.console import Console
from rich.table import Table

from exp_registry.config import resolve_config
from exp_registry.models import (
    find_experiment,
    infer_series,
    load_all_experiments,
    save_experiment,
)
from exp_registry.query import compare_experiments, filter_experiments

app = typer.Typer(help="Structured YAML experiment registry for ML research.")
console = Console()


def _get_registry_dir() -> str:
    """Resolve registry directory from config."""
    config = resolve_config()
    return os.path.join(config.project_root, config.registry_dir)


@app.command()
def init():
    """Initialize experiment registry in current directory."""
    config_path = os.path.join(os.getcwd(), "exp.config.yaml")
    registry_dir = os.path.join(os.getcwd(), "experiments")

    if os.path.exists(config_path):
        console.print(f"Config already exists: {config_path}")
    else:
        default_config = {
            "registry_dir": "experiments/",
            "paths_template": {"local": "outputs/{id}/"},
            "defaults": {},
            "types": {},
        }
        with open(config_path, "w") as f:
            yaml.dump(default_config, f, allow_unicode=True, default_flow_style=False, sort_keys=False)
        console.print(f"Created: {config_path}")

    os.makedirs(registry_dir, exist_ok=True)
    console.print("Ready! Run [bold]exp register <id> --type <type> --model <model>[/bold] to start.")


@app.command("list")
def list_cmd(
    status: Optional[str] = typer.Option(None, help="Filter by status"),
    type: Optional[str] = typer.Option(None, help="Filter by type"),
    series: Optional[str] = typer.Option(None, help="Filter by series"),
    json_output: bool = typer.Option(False, "--json", help="JSON output"),
):
    """List experiments with optional filters."""
    registry_dir = _get_registry_dir()
    experiments = load_all_experiments(registry_dir)
    experiments = filter_experiments(experiments, status=status, type=type, series=series)

    if json_output:
        typer.echo(json.dumps(experiments, ensure_ascii=False, indent=2, default=str))
        return

    if not experiments:
        console.print("No experiments found.")
        return

    table = Table()
    table.add_column("ID", style="cyan")
    table.add_column("Type")
    table.add_column("Status")
    table.add_column("Series")
    table.add_column("Date")
    table.add_column("Name")

    for e in experiments:
        status_style = "green" if e["status"] == "completed" else "yellow" if e["status"] == "running" else "red"
        table.add_row(
            e["id"], e["type"],
            f"[{status_style}]{e['status']}[/{status_style}]",
            e.get("series", ""), str(e.get("date", "")), e["name"],
        )
    console.print(table)


@app.command()
def show(
    exp_id: str = typer.Argument(..., help="Experiment ID"),
    json_output: bool = typer.Option(False, "--json", help="JSON output"),
):
    """Show experiment details."""
    registry_dir = _get_registry_dir()
    exp = find_experiment(exp_id, registry_dir)
    if exp is None:
        console.print(f"[red]Error:[/red] experiment '{exp_id}' not found.", err=True)
        raise typer.Exit(1)

    if json_output:
        typer.echo(json.dumps(exp, ensure_ascii=False, indent=2, default=str))
        return

    console.print(f"[bold]=== {exp['id']}: {exp['name']} ===[/bold]")
    console.print(f"Type:   {exp['type']}")
    console.print(f"Series: {exp.get('series', '')}")
    console.print(f"Date:   {exp.get('date', '')}")
    console.print(f"Status: {exp['status']}")

    if exp.get("stages"):
        console.print("\n[bold]Stages:[/bold]")
        for s in exp["stages"]:
            console.print(f"  - {s.get('name', '?')}: model={s.get('base_model', 'N/A')}")

    if exp.get("paths"):
        console.print("\n[bold]Paths:[/bold]")
        for k, v in exp["paths"].items():
            console.print(f"  {k}: {v}")

    if exp.get("benchmarks"):
        console.print("\n[bold]Benchmarks:[/bold]")
        for bm in exp["benchmarks"]:
            dataset = bm.get("dataset", bm.get("name", "?"))
            console.print(f"  [{dataset}] mode={bm.get('eval_mode', '?')}, samples={bm.get('samples', '?')}")
            for step, metrics in sorted(
                (bm.get("steps") or {}).items(),
                key=lambda x: (0, int(x[0])) if str(x[0]).isdigit() else (1, str(x[0])),
            ):
                metrics_str = ", ".join(f"{k}={v}" for k, v in metrics.items())
                console.print(f"    step {step}: {metrics_str}")

    if exp.get("findings"):
        console.print(f"\n[bold]Findings:[/bold]\n  {exp['findings'].strip()}")


@app.command()
def register(
    exp_id: str = typer.Argument(..., help="Experiment ID"),
    type: str = typer.Option(..., "--type", "-t", help="Experiment type"),
    model: str = typer.Option(..., "--model", "-m", help="Model name"),
    config: Optional[str] = typer.Option(None, help="Config file path"),
    script: Optional[str] = typer.Option(None, help="Launch script path"),
    reward: Optional[str] = typer.Option(None, help="Reward function name"),
    name: Optional[str] = typer.Option(None, help="Human-readable name"),
):
    """Register a new experiment."""
    exp_config = resolve_config()
    registry_dir = os.path.join(exp_config.project_root, exp_config.registry_dir)
    os.makedirs(registry_dir, exist_ok=True)

    out_path = os.path.join(registry_dir, f"{exp_id}.yaml")
    if os.path.exists(out_path):
        console.print(f"[red]Error:[/red] experiment '{exp_id}' already exists.", err=True)
        raise typer.Exit(1)

    paths = {}
    for key, template in exp_config.paths_template.items():
        paths[key] = template.replace("{id}", exp_id)

    stage = {"name": type, "base_model": model}
    if config:
        stage["config"] = config
    if script:
        stage["script"] = script
    if reward:
        stage["reward"] = reward

    data = {
        "id": exp_id,
        "name": name or exp_id,
        "type": type,
        "series": infer_series(exp_id),
        "date": str(date_type.today()),
        "status": "running",
        "stages": [stage],
        "paths": paths,
        "benchmarks": [],
        "findings": "",
    }

    save_experiment(data, out_path)
    console.print(f"Registered: [cyan]{out_path}[/cyan]")


@app.command("add-benchmark")
def add_benchmark(
    exp_id: str = typer.Argument(..., help="Experiment ID"),
    dataset: str = typer.Option(..., help="Dataset name"),
    eval_mode: str = typer.Option(..., "--eval-mode", help="Evaluation mode"),
    samples: int = typer.Option(..., help="Number of samples"),
    step: int = typer.Option(..., help="Training step"),
    extra: Optional[list[str]] = typer.Option(None, help="Metrics as key=value"),
):
    """Add benchmark results to an experiment."""
    exp_config = resolve_config()
    registry_dir = os.path.join(exp_config.project_root, exp_config.registry_dir)

    exp = find_experiment(exp_id, registry_dir)
    if exp is None:
        console.print(f"[red]Error:[/red] experiment '{exp_id}' not found.", err=True)
        raise typer.Exit(1)

    metrics = {}
    for item in (extra or []):
        if "=" not in item:
            continue
        k, v = item.split("=", 1)
        try:
            metrics[k] = int(v)
        except ValueError:
            try:
                metrics[k] = float(v)
            except ValueError:
                metrics[k] = v

    existing_bm = None
    for bm in exp.get("benchmarks", []):
        if bm.get("dataset") == dataset and bm.get("eval_mode") == eval_mode:
            existing_bm = bm
            break

    if existing_bm:
        existing_bm.setdefault("steps", {})[step] = metrics
    else:
        exp.setdefault("benchmarks", []).append({
            "dataset": dataset,
            "eval_mode": eval_mode,
            "samples": samples,
            "steps": {step: metrics},
        })

    out_path = os.path.join(registry_dir, f"{exp_id}.yaml")
    save_experiment(exp, out_path)
    console.print(f"Added benchmark step {step} to {exp_id} ({dataset}/{eval_mode})")


@app.command()
def compare(
    exp_ids: list[str] = typer.Argument(..., help="Experiment IDs to compare"),
    dataset: str = typer.Option(..., help="Dataset to compare on"),
    eval_mode: Optional[str] = typer.Option(None, "--eval-mode", help="Filter by eval mode"),
    json_output: bool = typer.Option(False, "--json", help="JSON output"),
):
    """Compare benchmark results across experiments."""
    exp_config = resolve_config()
    registry_dir = os.path.join(exp_config.project_root, exp_config.registry_dir)

    experiments = []
    for eid in exp_ids:
        exp = find_experiment(eid, registry_dir)
        if exp is None:
            console.print(f"[red]Error:[/red] experiment '{eid}' not found.", err=True)
            raise typer.Exit(1)
        experiments.append(exp)

    try:
        table_data = compare_experiments(experiments, dataset=dataset, eval_mode=eval_mode)
    except ValueError as e:
        console.print(f"[red]Error:[/red] {e}", err=True)
        raise typer.Exit(1)

    if json_output:
        typer.echo(json.dumps(table_data, ensure_ascii=False, indent=2, default=str))
        return

    sorted_metrics = table_data["metrics"]
    header_parts = ["Step"]
    for m in sorted_metrics:
        for eid in table_data["exp_ids"]:
            header_parts.append(f"{m} ({eid})")
    typer.echo("| " + " | ".join(header_parts) + " |")
    typer.echo("| " + " | ".join(["---"] * len(header_parts)) + " |")
    for step_num, exp_data in table_data["steps"].items():
        row_parts = [str(step_num)]
        for m in sorted_metrics:
            for eid in table_data["exp_ids"]:
                val = exp_data.get(eid, {}).get(m, "—")
                if isinstance(val, float):
                    val = f"{val:.2f}"
                row_parts.append(str(val))
        typer.echo("| " + " | ".join(row_parts) + " |")


@app.command()
def update(
    exp_id: str = typer.Argument(..., help="Experiment ID"),
    status: Optional[str] = typer.Option(None, help="New status"),
    finding: Optional[str] = typer.Option(None, help="Add a finding"),
):
    """Update experiment status or findings."""
    exp_config = resolve_config()
    registry_dir = os.path.join(exp_config.project_root, exp_config.registry_dir)

    exp = find_experiment(exp_id, registry_dir)
    if exp is None:
        console.print(f"[red]Error:[/red] experiment '{exp_id}' not found.", err=True)
        raise typer.Exit(1)

    if status:
        exp["status"] = status
    if finding:
        existing = exp.get("findings", "").strip()
        exp["findings"] = (existing + "\n" + finding) if existing else finding

    out_path = os.path.join(registry_dir, f"{exp_id}.yaml")
    save_experiment(exp, out_path)
    console.print(f"Updated: [cyan]{out_path}[/cyan]")


if __name__ == "__main__":
    app()
