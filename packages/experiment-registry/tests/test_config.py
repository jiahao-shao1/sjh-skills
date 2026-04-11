import os
import yaml
import pytest
from exp_registry.config import find_config, load_config, ExpConfig


class TestFindConfig:
    """Config file discovery by walking up directories."""

    def test_finds_config_in_current_dir(self, tmp_path):
        """find_config returns path when exp.config.yaml exists in start dir."""
        cfg_path = tmp_path / "exp.config.yaml"
        cfg_path.write_text(yaml.dump({"registry_dir": "experiments/"}))
        result = find_config(str(tmp_path))
        assert result == str(cfg_path)

    def test_finds_config_in_parent_dir(self, tmp_path):
        """find_config walks up to find exp.config.yaml in ancestor."""
        cfg_path = tmp_path / "exp.config.yaml"
        cfg_path.write_text(yaml.dump({"registry_dir": "experiments/"}))
        child = tmp_path / "sub" / "deep"
        child.mkdir(parents=True)
        result = find_config(str(child))
        assert result == str(cfg_path)

    def test_returns_none_when_no_config(self, tmp_path):
        """find_config returns None when no config found up to root."""
        result = find_config(str(tmp_path))
        assert result is None


class TestLoadConfig:
    """Config parsing and defaults."""

    def test_load_full_config(self, tmp_path):
        """load_config parses all fields from YAML."""
        cfg_data = {
            "registry_dir": "docs/registry/",
            "paths_template": {
                "local": "outputs/{id}/",
                "cluster": "/data/outputs/{id}/",
            },
            "defaults": {"type": "rl", "model": "Qwen3-VL-8B"},
            "types": {"rl": {"fields": ["model", "config", "reward"]}},
        }
        cfg_path = tmp_path / "exp.config.yaml"
        cfg_path.write_text(yaml.dump(cfg_data))
        config = load_config(str(cfg_path))
        assert config.registry_dir == "docs/registry/"
        assert config.paths_template["local"] == "outputs/{id}/"
        assert config.defaults["type"] == "rl"
        assert config.types["rl"]["fields"] == ["model", "config", "reward"]

    def test_load_minimal_config(self, tmp_path):
        """load_config uses defaults for missing fields."""
        cfg_path = tmp_path / "exp.config.yaml"
        cfg_path.write_text(yaml.dump({"registry_dir": "exps/"}))
        config = load_config(str(cfg_path))
        assert config.registry_dir == "exps/"
        assert config.paths_template == {}
        assert config.defaults == {}
        assert config.types == {}

    def test_default_config_when_no_file(self):
        """ExpConfig defaults when no file is found."""
        config = ExpConfig()
        assert config.registry_dir == "experiments/"
        assert config.paths_template == {}
