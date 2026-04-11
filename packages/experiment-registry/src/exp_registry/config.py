"""Project configuration discovery and parsing."""

import os
from dataclasses import dataclass, field
from typing import Optional

import yaml


CONFIG_FILENAME = "exp.config.yaml"


@dataclass
class ExpConfig:
    """Experiment registry project configuration."""

    registry_dir: str = "experiments/"
    paths_template: dict = field(default_factory=dict)
    defaults: dict = field(default_factory=dict)
    types: dict = field(default_factory=dict)
    project_root: str = ""


def find_config(start_dir: str) -> Optional[str]:
    """Walk up from start_dir looking for exp.config.yaml. Returns path or None."""
    current = os.path.abspath(start_dir)
    while True:
        candidate = os.path.join(current, CONFIG_FILENAME)
        if os.path.isfile(candidate):
            return candidate
        parent = os.path.dirname(current)
        if parent == current:
            return None
        current = parent


def load_config(config_path: str) -> ExpConfig:
    """Load and parse an exp.config.yaml file."""
    with open(config_path, "r") as f:
        data = yaml.safe_load(f) or {}

    config = ExpConfig(
        registry_dir=data.get("registry_dir", "experiments/"),
        paths_template=data.get("paths_template", {}),
        defaults=data.get("defaults", {}),
        types=data.get("types", {}),
        project_root=os.path.dirname(os.path.abspath(config_path)),
    )
    return config


def resolve_config(start_dir: Optional[str] = None) -> ExpConfig:
    """Find and load config, or return defaults if no config file exists."""
    start = start_dir or os.getcwd()
    config_path = find_config(start)
    if config_path:
        return load_config(config_path)
    return ExpConfig(project_root=os.path.abspath(start))
