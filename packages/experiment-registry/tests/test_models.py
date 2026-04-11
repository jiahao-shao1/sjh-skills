import yaml
import pytest
from exp_registry.models import (
    load_experiment,
    save_experiment,
    load_all_experiments,
    find_experiment,
    infer_series,
    REQUIRED_FIELDS,
)


class TestInferSeries:
    def test_standard_id(self):
        assert infer_series("exp07a") == "exp07"

    def test_id_with_suffix(self):
        assert infer_series("exp07d-fake-short") == "exp07"

    def test_no_match(self):
        assert infer_series("test_run_1") == "test_run_1"


class TestLoadExperiment:
    def test_load_valid(self, tmp_path):
        data = {
            "id": "exp01", "name": "test exp", "type": "rl",
            "series": "exp01", "date": "2026-01-01", "status": "running",
        }
        f = tmp_path / "exp01.yaml"
        f.write_text(yaml.dump(data))
        exp = load_experiment(str(f))
        assert exp["id"] == "exp01"
        assert exp["stages"] == []
        assert exp["benchmarks"] == []

    def test_load_missing_field_raises(self, tmp_path):
        data = {"id": "bad", "name": "incomplete"}
        f = tmp_path / "bad.yaml"
        f.write_text(yaml.dump(data))
        with pytest.raises(ValueError, match="Missing required fields"):
            load_experiment(str(f))

    def test_load_invalid_status_raises(self, tmp_path):
        data = {
            "id": "x", "name": "x", "type": "rl",
            "series": "x", "date": "2026-01-01", "status": "invalid",
        }
        f = tmp_path / "x.yaml"
        f.write_text(yaml.dump(data))
        with pytest.raises(ValueError, match="Invalid status"):
            load_experiment(str(f))

    def test_extra_fields_preserved(self, tmp_path):
        data = {
            "id": "exp01", "name": "test", "type": "rl",
            "series": "exp01", "date": "2026-01-01", "status": "running",
            "custom_field": "custom_value",
        }
        f = tmp_path / "exp01.yaml"
        f.write_text(yaml.dump(data))
        exp = load_experiment(str(f))
        assert exp["custom_field"] == "custom_value"


class TestSaveExperiment:
    def test_round_trip(self, tmp_path):
        data = {
            "id": "rt", "name": "round trip", "type": "sft",
            "series": "rt", "date": "2026-01-01", "status": "running",
        }
        out = tmp_path / "rt.yaml"
        save_experiment(data, str(out))
        reloaded = load_experiment(str(out))
        assert reloaded["id"] == "rt"
        assert reloaded["status"] == "running"


class TestLoadAllExperiments:
    def test_loads_multiple(self, tmp_path):
        for eid in ("exp01", "exp02"):
            data = {
                "id": eid, "name": f"test {eid}", "type": "rl",
                "series": eid, "date": "2026-01-01", "status": "running",
            }
            (tmp_path / f"{eid}.yaml").write_text(yaml.dump(data))
        exps = load_all_experiments(str(tmp_path))
        assert len(exps) == 2

    def test_empty_dir(self, tmp_path):
        exps = load_all_experiments(str(tmp_path))
        assert exps == []


class TestFindExperiment:
    def test_find_by_id(self, tmp_path):
        data = {
            "id": "exp01", "name": "test", "type": "rl",
            "series": "exp01", "date": "2026-01-01", "status": "running",
        }
        (tmp_path / "exp01.yaml").write_text(yaml.dump(data))
        exp = find_experiment("exp01", str(tmp_path))
        assert exp is not None
        assert exp["id"] == "exp01"

    def test_not_found(self, tmp_path):
        exp = find_experiment("nonexistent", str(tmp_path))
        assert exp is None
