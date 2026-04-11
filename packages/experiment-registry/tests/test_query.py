import pytest
from exp_registry.query import filter_experiments, compare_experiments


def _make_exps():
    return [
        {"id": "exp01", "type": "rl", "status": "completed", "series": "exp01",
         "benchmarks": [{"dataset": "mmlu", "eval_mode": "cot", "samples": 100, "steps": {50: {"acc": 0.72}}}]},
        {"id": "exp02", "type": "sft", "status": "running", "series": "exp02",
         "benchmarks": [{"dataset": "mmlu", "eval_mode": "cot", "samples": 100, "steps": {50: {"acc": 0.68}}}]},
        {"id": "exp03", "type": "rl", "status": "completed", "series": "exp01",
         "benchmarks": [{"dataset": "vstar", "eval_mode": "agent", "samples": 50, "steps": {30: {"score": 0.45}}}]},
    ]


class TestFilterExperiments:
    def test_filter_by_status(self):
        exps = filter_experiments(_make_exps(), status="completed")
        assert len(exps) == 2
        assert all(e["status"] == "completed" for e in exps)

    def test_filter_by_type(self):
        exps = filter_experiments(_make_exps(), type="sft")
        assert len(exps) == 1
        assert exps[0]["id"] == "exp02"

    def test_filter_by_series(self):
        exps = filter_experiments(_make_exps(), series="exp01")
        assert len(exps) == 2

    def test_no_filter_returns_all(self):
        exps = filter_experiments(_make_exps())
        assert len(exps) == 3


class TestCompareExperiments:
    def test_compare_same_dataset(self):
        exps = _make_exps()[:2]  # exp01 and exp02 both have mmlu
        table = compare_experiments(exps, dataset="mmlu")
        assert len(table["steps"]) == 1  # step 50
        assert table["steps"][50]["exp01"]["acc"] == 0.72
        assert table["steps"][50]["exp02"]["acc"] == 0.68

    def test_compare_no_data_raises(self):
        exps = _make_exps()[:2]
        with pytest.raises(ValueError, match="No benchmark data"):
            compare_experiments(exps, dataset="nonexistent")

    def test_compare_with_eval_mode_filter(self):
        exps = _make_exps()
        table = compare_experiments([exps[0], exps[2]], dataset="mmlu", eval_mode="cot")
        # exp03 has vstar not mmlu, so only exp01 has data
        assert 50 in table["steps"]
        assert "exp01" in table["steps"][50]
