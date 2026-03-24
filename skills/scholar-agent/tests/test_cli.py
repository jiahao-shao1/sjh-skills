"""CLI smoke tests."""
import subprocess
import sys


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
