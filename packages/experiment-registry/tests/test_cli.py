import json
import yaml
import pytest
from typer.testing import CliRunner
from exp_registry.cli import app

runner = CliRunner()


def _make_registry(tmp_path):
    """Create a test registry with config."""
    reg = tmp_path / "experiments"
    reg.mkdir()
    for eid, etype, status in [("exp01", "rl", "completed"), ("exp02", "sft", "running")]:
        data = {
            "id": eid, "name": f"test {eid}", "type": etype,
            "series": eid[:5], "date": "2026-01-01", "status": status,
        }
        (reg / f"{eid}.yaml").write_text(yaml.dump(data))
    cfg = {"registry_dir": "experiments/"}
    (tmp_path / "exp.config.yaml").write_text(yaml.dump(cfg))
    return tmp_path


class TestInit:
    def test_init_creates_config_and_dir(self, tmp_path, monkeypatch):
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["init"])
        assert result.exit_code == 0
        assert (tmp_path / "exp.config.yaml").exists()
        assert (tmp_path / "experiments").is_dir()

    def test_init_no_overwrite(self, tmp_path, monkeypatch):
        monkeypatch.chdir(tmp_path)
        (tmp_path / "exp.config.yaml").write_text("registry_dir: custom/\n")
        result = runner.invoke(app, ["init"])
        assert result.exit_code == 0
        assert "custom/" in (tmp_path / "exp.config.yaml").read_text()


class TestList:
    def test_list_all(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["list"])
        assert result.exit_code == 0
        assert "exp01" in result.stdout
        assert "exp02" in result.stdout

    def test_list_filter_status(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["list", "--status", "completed"])
        assert result.exit_code == 0
        assert "exp01" in result.stdout
        assert "exp02" not in result.stdout

    def test_list_json(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["list", "--json"])
        assert result.exit_code == 0
        data = json.loads(result.stdout)
        assert len(data) == 2


class TestRegister:
    def test_register_new(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["register", "exp03", "--type", "rl", "--model", "Qwen3-VL-8B"])
        assert result.exit_code == 0
        assert (tmp_path / "experiments" / "exp03.yaml").exists()
        exp = yaml.safe_load((tmp_path / "experiments" / "exp03.yaml").read_text())
        assert exp["id"] == "exp03"
        assert exp["series"] == "exp03"

    def test_register_uses_paths_template(self, tmp_path, monkeypatch):
        reg = tmp_path / "experiments"
        reg.mkdir()
        cfg = {
            "registry_dir": "experiments/",
            "paths_template": {"local": "out/{id}/", "remote": "/data/{id}/"},
        }
        (tmp_path / "exp.config.yaml").write_text(yaml.dump(cfg))
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["register", "exp05", "--type", "sft", "--model", "LLaMA-3"])
        assert result.exit_code == 0
        exp = yaml.safe_load((tmp_path / "experiments" / "exp05.yaml").read_text())
        assert exp["paths"]["local"] == "out/exp05/"
        assert exp["paths"]["remote"] == "/data/exp05/"

    def test_register_duplicate_fails(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["register", "exp01", "--type", "rl", "--model", "X"])
        assert result.exit_code != 0


class TestShow:
    def test_show_existing(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["show", "exp01"])
        assert result.exit_code == 0
        assert "exp01" in result.stdout

    def test_show_not_found(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["show", "nonexistent"])
        assert result.exit_code != 0


class TestUpdate:
    def test_update_status(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["update", "exp02", "--status", "completed"])
        assert result.exit_code == 0
        exp = yaml.safe_load((tmp_path / "experiments" / "exp02.yaml").read_text())
        assert exp["status"] == "completed"

    def test_update_finding(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["update", "exp01", "--finding", "works great"])
        assert result.exit_code == 0
        exp = yaml.safe_load((tmp_path / "experiments" / "exp01.yaml").read_text())
        assert "works great" in exp["findings"]


class TestValidate:
    def test_validate_clean_registry(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        result = runner.invoke(app, ["validate"])
        assert result.exit_code == 0
        assert "OK" in result.stdout or "all experiments valid" in result.stdout

    def test_validate_detects_missing_eval_mode(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        bad = yaml.safe_load((tmp_path / "experiments" / "exp01.yaml").read_text())
        bad["benchmarks"] = [{"dataset": "mmlu", "steps": {0: {"acc": 0.5}}}]
        (tmp_path / "experiments" / "exp01.yaml").write_text(yaml.dump(bad))
        result = runner.invoke(app, ["validate"])
        assert result.exit_code == 0
        assert "missing eval_mode" in result.stdout

    def test_validate_detects_filename_mismatch(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        bad = yaml.safe_load((tmp_path / "experiments" / "exp01.yaml").read_text())
        bad["id"] = "wrong_id"
        (tmp_path / "experiments" / "exp01.yaml").write_text(yaml.dump(bad))
        result = runner.invoke(app, ["validate"])
        assert "!= id" in result.stdout

    def test_validate_strict_exits_nonzero(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        bad = yaml.safe_load((tmp_path / "experiments" / "exp01.yaml").read_text())
        bad["status"] = "weird_status"
        (tmp_path / "experiments" / "exp01.yaml").write_text(yaml.dump(bad))
        result = runner.invoke(app, ["validate", "--strict"])
        assert result.exit_code == 1

    def test_validate_json_output(self, tmp_path, monkeypatch):
        _make_registry(tmp_path)
        monkeypatch.chdir(tmp_path)
        bad = yaml.safe_load((tmp_path / "experiments" / "exp01.yaml").read_text())
        bad["benchmarks"] = [{"dataset": "mmlu"}]
        (tmp_path / "experiments" / "exp01.yaml").write_text(yaml.dump(bad))
        result = runner.invoke(app, ["validate", "--json"])
        assert result.exit_code == 0
        report = json.loads(result.stdout)
        assert any(e["id"] == "exp01" for e in report)
