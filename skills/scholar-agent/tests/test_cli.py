"""CLI smoke tests."""
import subprocess
import sys

from scholar_inbox.cli import _sanitize_summary


def test_cli_help():
    """CLI prints help without errors."""
    result = subprocess.run(
        [sys.executable, "-m", "scholar_inbox", "--help"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0
    assert "Scholar Inbox" in result.stdout


def test_cli_version():
    """CLI prints version."""
    result = subprocess.run(
        [sys.executable, "-m", "scholar_inbox", "--version"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0
    assert "0.1.0" in result.stdout


def test_cli_doctor_json():
    """Doctor outputs JSON diagnostics without failing by default."""
    result = subprocess.run(
        [sys.executable, "-m", "scholar_inbox", "doctor", "--json"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0
    assert '"summary"' in result.stdout
    assert '"checks"' in result.stdout


def test_sanitize_summary_flags_obvious_mismatch():
    """Clearly unrelated benchmark-heavy summaries should be suppressed."""
    title = "FactorSmith: Agentic Simulation Generation via MDP Decomposition"
    summary = (
        "- Introduces context-aware attention in DeepVision.\n"
        "- Achieves state-of-the-art on ImageNet and COCO under occlusion."
    )
    sanitized, suspect, reason = _sanitize_summary(title, summary)
    assert sanitized == ""
    assert suspect is True
    assert reason is not None


def test_sanitize_summary_keeps_related_summary():
    """On-topic summaries should remain visible."""
    title = "Demystifying Reinforcement Learning for Long-Horizon Tool-Using Agents"
    summary = (
        "- Introduces a reinforcement learning pipeline for long-horizon planning.\n"
        "- Studies tool-using agents with curriculum learning and RL."
    )
    sanitized, suspect, reason = _sanitize_summary(title, summary)
    assert sanitized == summary
    assert suspect is False
    assert reason is None
