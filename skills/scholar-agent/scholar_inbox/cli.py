"""Scholar Inbox CLI — command-line interface for Scholar Inbox.

Usage:
    scholar-inbox status
    scholar-inbox login [--cookie VALUE] [--browser]
    scholar-inbox digest [--limit N] [--min-score F] [--date YYYY-MM-DD] [--json]
    scholar-inbox paper PAPER_ID
    scholar-inbox rate PAPER_ID RATING
    scholar-inbox rate-batch RATING ID...
    scholar-inbox trending [--category CAT] [--days N] [--limit N]
    scholar-inbox collections
    scholar-inbox collect PAPER_ID COLLECTION
    scholar-inbox read PAPER_ID
    scholar-inbox config [set KEY VALUE]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

import scholar_inbox
from scholar_inbox.api import RATING_MAP, APIError, ScholarInboxClient, SessionExpiredError
from scholar_inbox.auth import open_browser_for_login
from scholar_inbox.config import Config


def _get_config() -> Config:
    """Build Config from env or default path."""
    config_dir_env = os.environ.get("SCHOLAR_INBOX_CONFIG_DIR")
    if config_dir_env:
        return Config(config_dir=Path(config_dir_env))
    return Config()


def _get_client(config: Config | None = None) -> ScholarInboxClient:
    """Build a client with config-backed session."""
    if config is None:
        config = _get_config()
    return ScholarInboxClient(config=config)


def _parse_rating(value: str) -> int:
    """Parse rating from string — accepts 'up'/'down'/'reset' or '1'/'-1'/'0'."""
    if value in RATING_MAP:
        return RATING_MAP[value]
    try:
        r = int(value)
        if r in (1, -1, 0):
            return r
    except ValueError:
        pass
    print(f"Error: Invalid rating '{value}'. Use up/down/reset or 1/-1/0.", file=sys.stderr)
    sys.exit(1)


def _coerce_int(value, default=0) -> int:
    """Best-effort integer coercion for inconsistent API fields."""
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _normalize_list(value) -> list:
    """Normalize nullable/list-like API fields to a list."""
    if isinstance(value, list):
        return value
    if value in (None, ""):
        return []
    return [value]


def _tokenize_text(text: str) -> set[str]:
    """Extract normalized content tokens for lightweight summary validation."""
    stopwords = {
        "the", "and", "for", "with", "from", "into", "through", "using", "via", "toward",
        "under", "over", "based", "study", "paper", "method", "methods", "approach", "approaches",
        "model", "models", "task", "tasks", "data", "results", "analysis", "learning",
        "agent", "agents", "system", "systems", "comprehensive", "recipe", "framework",
        "new", "improving", "improved", "towards", "long", "horizon", "tool", "tools",
    }
    tokens = {
        token.lower()
        for token in re.findall(r"[A-Za-z][A-Za-z0-9\-\+]{2,}", text or "")
    }
    return {token for token in tokens if token not in stopwords}


def _summary_mismatch_reason(title: str, summary: str) -> str | None:
    """Return a mismatch reason if a summary appears unrelated to the title."""
    if not summary or not summary.strip():
        return None

    title_tokens = _tokenize_text(title)
    summary_tokens = _tokenize_text(summary)
    overlap = title_tokens & summary_tokens

    suspicious_terms = {
        "imagenet", "coco", "deepvision", "occlusion", "resnet", "vit", "recognition",
        "segmentation", "detection", "top-1", "map",
    }
    suspicious_overlap = summary_tokens & suspicious_terms

    if title_tokens and len(overlap) == 0 and suspicious_overlap:
        return f"no title-token overlap; suspicious terms: {', '.join(sorted(suspicious_overlap))}"

    if title_tokens and len(title_tokens) >= 3 and len(overlap) == 0:
        return "no title-token overlap"

    return None


def _sanitize_summary(title: str, summary: str) -> tuple[str, bool, str | None]:
    """Return sanitized summary, suspect flag, and optional mismatch reason."""
    reason = _summary_mismatch_reason(title, summary)
    if reason:
        return "", True, reason
    return summary, False, None


def _notebooklm_paths() -> dict[str, Path]:
    """Return NotebookLM-related paths used by the enhanced mode."""
    skill_dir = Path.home() / ".claude" / "skills" / "notebooklm"
    data_dir = skill_dir / "data"
    browser_state_dir = data_dir / "browser_state"
    profile_default = browser_state_dir / "browser_profile"
    profile = Path(os.environ.get("NOTEBOOKLM_PROFILE", str(profile_default))).expanduser()
    return {
        "skill_dir": skill_dir,
        "data_dir": data_dir,
        "browser_state_dir": browser_state_dir,
        "profile": profile,
        "state_file": browser_state_dir / "state.json",
        "auth_info_file": data_dir / "auth_info.json",
        "library_file": data_dir / "library.json",
        "ask_question_script": skill_dir / "scripts" / "ask_question.py",
        "run_script": skill_dir / "scripts" / "run.py",
    }


def _script_candidates(name: str) -> list[Path]:
    """Return candidate paths for a bundled script."""
    return [
        Path(__file__).parent.parent / "scripts" / name,
        Path.home() / ".agents" / "skills" / "scholar-inbox" / "scripts" / name,
    ]


def _first_existing(paths: list[Path]) -> Path | None:
    """Return the first existing path from a list."""
    for path in paths:
        if path.exists():
            return path
    return None


def _run_command(cmd: list[str], timeout: int = 10) -> subprocess.CompletedProcess[str] | None:
    """Run a command and return the completed process or None if unavailable."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None


def _run_command_in_dir(
    cmd: list[str], cwd: Path, timeout: int = 10
) -> subprocess.CompletedProcess[str] | None:
    """Run a command in a specific directory."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=str(cwd))
    except (OSError, subprocess.SubprocessError):
        return None


def _run_checked_command(
    cmd: list[str],
    *,
    cwd: Path | None = None,
    timeout: int = 300,
    description: str,
) -> subprocess.CompletedProcess[str]:
    """Run a command and fail with a clear CLI error if it does not succeed."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(cwd) if cwd else None,
        )
    except (OSError, subprocess.SubprocessError) as e:
        print(f"Error: {description} failed to start: {e}", file=sys.stderr)
        sys.exit(1)

    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        print(f"Error: {description} failed.", file=sys.stderr)
        if detail:
            print(detail, file=sys.stderr)
        sys.exit(1)

    return result


def _session_status(config: Config) -> tuple[str, str]:
    """Return ('ok'|'warn'|'fail', message) for Scholar Inbox login state."""
    session = config.load_session()
    if not session:
        return "warn", "Not logged in"

    try:
        client = _get_client(config)
        data = client.check_session()
        if data and data.get("is_logged_in"):
            return "ok", f"Logged in as {data.get('name', 'unknown')}"
        return "fail", "Session present but server rejected it"
    except SessionExpiredError:
        return "fail", "Session expired"
    except APIError as e:
        return "fail", f"Session check failed: {e}"
    except Exception as e:
        return "fail", f"Session check failed: {e}"


def _profile_lock_processes(profile: Path) -> list[str]:
    """Return processes currently holding or referencing the NotebookLM profile."""
    profile_str = str(profile)

    if shutil.which("pgrep"):
        result = _run_command(["pgrep", "-fal", profile_str], timeout=5)
        if result and result.stdout:
            return [
                line.strip()
                for line in result.stdout.splitlines()
                if line.strip() and profile_str in line
            ]

    result = _run_command(["ps", "aux"], timeout=5)
    if not result or not result.stdout:
        return []

    matches = []
    for line in result.stdout.splitlines():
        if profile_str in line:
            matches.append(line.strip())
    return matches


def _check(status: str, name: str, detail: str, hint: str | None = None, critical: bool = False) -> dict:
    """Build a diagnostic check entry."""
    return {
        "status": status,
        "name": name,
        "detail": detail,
        "hint": hint,
        "critical": critical,
    }


def _extract_playwright_eval_result(output: str) -> str | None:
    """Extract the raw value from `playwright-cli eval` output."""
    for line in output.splitlines():
        line = line.strip()
        if line.startswith('"') and line.endswith('"'):
            return line[1:-1]
    return None


def _load_notebooklm_ui_patterns() -> dict[str, str]:
    """Load NotebookLM UI regex patterns from the shared shell knowledge file."""
    knowledge = _first_existing(_script_candidates("notebooklm_site_knowledge.sh"))
    if not knowledge:
        return {}

    patterns: dict[str, str] = {}
    line_re = re.compile(r"^(NOTEBOOKLM_[A-Z_]+)='(.*)'$")
    for line in knowledge.read_text().splitlines():
        match = line_re.match(line.strip())
        if match:
            patterns[match.group(1)] = match.group(2)
    return patterns


def _pick_notebooklm_probe_url(notebooklm: dict[str, Path]) -> str | None:
    """Pick an existing NotebookLM URL for read-only online probing."""
    library_file = notebooklm["library_file"]
    if not library_file.exists():
        return None

    try:
        data = json.loads(library_file.read_text())
    except (OSError, json.JSONDecodeError):
        return None

    active_id = data.get("active_notebook_id")
    notebooks = data.get("notebooks", {})

    if active_id and isinstance(notebooks, dict):
        active = notebooks.get(active_id)
        if active and active.get("url"):
            return active["url"]

    if isinstance(notebooks, dict):
        for notebook in notebooks.values():
            if notebook.get("url"):
                return notebook["url"]

    return None


def _slugify_notebook_name(name: str) -> str:
    """Create a notebook-library-friendly ID from a display name."""
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return slug or "notebook"


def _register_notebook_in_library(
    notebooklm: dict[str, Path], notebook_url: str, notebook_name: str
) -> None:
    """Best-effort register/update notebook metadata in NotebookLM library."""
    run_script = notebooklm["run_script"]
    manager_script = notebooklm["skill_dir"] / "scripts" / "notebook_manager.py"
    if not run_script.exists() or not manager_script.exists():
        return

    topics = notebook_name.lower().replace(" ", "-")
    _run_command(
        [
            "python3",
            str(run_script),
            "notebook_manager.py",
            "add",
            "--url",
            notebook_url,
            "--name",
            notebook_name,
            "--description",
            f"Created by scholar-inbox e2e for {notebook_name}",
            "--topics",
            topics,
        ],
        timeout=30,
    )


def _extract_answer_block(output: str) -> str:
    """Extract the answer portion from ask_question.py output."""
    marker = "============================================================"
    if marker not in output:
        return output.strip()

    parts = output.split(marker)
    if len(parts) < 3:
        return output.strip()

    answer = parts[2].strip()
    if answer.startswith("Question:"):
        answer = answer.split("\n", 1)[1].strip() if "\n" in answer else ""
    return answer


def _append_query_param(url: str, key: str, value: str) -> str:
    """Append or replace a query parameter in a URL."""
    parsed = urlparse(url)
    query = dict(parse_qsl(parsed.query, keep_blank_values=True))
    query[key] = value
    return urlunparse(parsed._replace(query=urlencode(query)))


def _probe_scholar_inbox_page() -> dict:
    """Open Scholar Inbox in a temp browser profile and verify the page loads."""
    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        profile = workdir / "scholar-profile"
        _run_command(["playwright-cli", "close"], timeout=5)
        result = _run_command_in_dir(
            [
                "playwright-cli",
                "open",
                "--browser=chrome",
                f"--profile={profile}",
                "https://www.scholar-inbox.com",
            ],
            cwd=workdir,
            timeout=20,
        )
        if result is None:
            return _check("warn", "Scholar Inbox page probe", "Failed to launch playwright-cli")

        try:
            for _ in range(8):
                time.sleep(2)
                eval_result = _run_command_in_dir(
                    [
                        "playwright-cli",
                        "eval",
                        '() => `${window.location.href}|${document.title}|${document.querySelectorAll("a,button,input").length}`',
                    ],
                    cwd=workdir,
                    timeout=10,
                )
                if not eval_result:
                    continue
                value = _extract_playwright_eval_result(eval_result.stdout)
                if not value:
                    continue
                parts = value.split("|")
                if len(parts) != 3:
                    continue
                current_url, title, interactive = parts
                if "scholar-inbox.com" in current_url and _coerce_int(interactive) >= 3:
                    return _check(
                        "ok",
                        "Scholar Inbox page probe",
                        f"Loaded {current_url} ({title})",
                    )
            return _check(
                "warn",
                "Scholar Inbox page probe",
                "Page did not reach a stable interactive state",
                "Check browser/network access or site availability.",
            )
        finally:
            _run_command(["playwright-cli", "close"], timeout=5)


def _probe_notebooklm_home_page(notebooklm: dict[str, Path], patterns: dict[str, str]) -> dict:
    """Open NotebookLM home with the real profile and verify homepage selectors."""
    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        _run_command(["playwright-cli", "close"], timeout=5)
        result = _run_command_in_dir(
            [
                "playwright-cli",
                "open",
                "--browser=chrome",
                f"--profile={notebooklm['profile']}",
                "https://notebooklm.google.com",
            ],
            cwd=workdir,
            timeout=20,
        )
        if result is None:
            return _check("warn", "NotebookLM home probe", "Failed to launch playwright-cli")

        try:
            for _ in range(10):
                time.sleep(2)
                eval_result = _run_command_in_dir(
                    [
                        "playwright-cli",
                        "eval",
                        '() => `${window.location.href}|${document.querySelectorAll("button").length}`',
                    ],
                    cwd=workdir,
                    timeout=10,
                )
                if not eval_result:
                    continue
                value = _extract_playwright_eval_result(eval_result.stdout)
                if not value:
                    continue
                parts = value.split("|")
                if len(parts) != 2:
                    continue
                current_url, button_count = parts
                if "accounts.google.com" in current_url:
                    return _check(
                        "fail",
                        "NotebookLM home probe",
                        "Profile opened Google login instead of NotebookLM home",
                        "NotebookLM auth is likely expired.",
                    )
                if current_url.startswith("https://notebooklm.google.com/") and _coerce_int(button_count) >= 5:
                    snapshot_result = _run_command_in_dir(
                        ["playwright-cli", "snapshot"],
                        cwd=workdir,
                        timeout=15,
                    )
                    snapshot_ok = bool(snapshot_result and ".yml" in snapshot_result.stdout)
                    detail = f"Loaded {current_url} with {_coerce_int(button_count)} buttons"
                    if patterns.get("NOTEBOOKLM_NEW_NOTEBOOK_PATTERN") and snapshot_ok:
                        snap_dir = workdir / ".playwright-cli"
                        latest = sorted(snap_dir.glob("*.yml"))
                        if latest:
                            text = latest[-1].read_text()
                            if not re.search(patterns["NOTEBOOKLM_NEW_NOTEBOOK_PATTERN"], text, re.IGNORECASE):
                                return _check(
                                    "warn",
                                    "NotebookLM home probe",
                                    detail,
                                    "Home page loaded, but the new-notebook selector was not found in snapshot.",
                                )
                    return _check("ok", "NotebookLM home probe", detail)
            return _check(
                "warn",
                "NotebookLM home probe",
                "NotebookLM home did not reach a stable interactive state",
                "Check auth, UI drift, or page load timing.",
            )
        finally:
            _run_command(["playwright-cli", "close"], timeout=5)


def _probe_notebooklm_source_dialog(notebooklm: dict[str, Path], patterns: dict[str, str]) -> dict:
    """Open an existing notebook in add-source mode and detect the routing strategy."""
    notebook_url = _pick_notebooklm_probe_url(notebooklm)
    if not notebook_url:
        return _check(
            "warn",
            "NotebookLM source dialog probe",
            "No notebook URL available in library.json",
            "Create or register at least one notebook before using --online.",
        )

    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        probe_url = _append_query_param(notebook_url, "addSource", "true")
        _run_command(["playwright-cli", "close"], timeout=5)
        result = _run_command_in_dir(
            [
                "playwright-cli",
                "open",
                "--browser=chrome",
                f"--profile={notebooklm['profile']}",
                probe_url,
            ],
            cwd=workdir,
            timeout=20,
        )
        if result is None:
            return _check("warn", "NotebookLM source dialog probe", "Failed to launch playwright-cli")

        try:
            for _ in range(10):
                time.sleep(2)
                eval_result = _run_command_in_dir(
                    [
                        "playwright-cli",
                        "eval",
                        '() => `${window.location.href}|${document.querySelectorAll("button").length}`',
                    ],
                    cwd=workdir,
                    timeout=10,
                )
                if not eval_result:
                    continue
                value = _extract_playwright_eval_result(eval_result.stdout)
                if not value:
                    continue
                parts = value.split("|")
                if len(parts) != 2:
                    continue
                current_url, button_count = parts
                if not current_url.startswith("https://notebooklm.google.com/notebook/"):
                    continue
                if _coerce_int(button_count) < 3:
                    continue

                snapshot_result = _run_command_in_dir(
                    ["playwright-cli", "snapshot"],
                    cwd=workdir,
                    timeout=15,
                )
                if not snapshot_result:
                    continue
                snap_dir = workdir / ".playwright-cli"
                latest = sorted(snap_dir.glob("*.yml"))
                if not latest:
                    continue
                text = latest[-1].read_text()

                if re.search(patterns.get("NOTEBOOKLM_URL_INPUT_PATTERN", r"$^"), text, re.IGNORECASE):
                    strategy = "url_input_ready"
                elif re.search(patterns.get("NOTEBOOKLM_WEBSITE_PATTERN", r"$^"), text, re.IGNORECASE):
                    strategy = "open_website_form"
                elif re.search(patterns.get("NOTEBOOKLM_ADD_SOURCE_PATTERN", r"$^"), text, re.IGNORECASE):
                    strategy = "open_source_dialog"
                else:
                    return _check(
                        "warn",
                        "NotebookLM source dialog probe",
                        f"Loaded {current_url}, but no known source-entry strategy matched",
                        "Update notebooklm_site_knowledge.sh for the current UI.",
                    )

                return _check(
                    "ok",
                    "NotebookLM source dialog probe",
                    f"Loaded {current_url} and detected strategy: {strategy}",
                )

            return _check(
                "warn",
                "NotebookLM source dialog probe",
                "Notebook source dialog did not reach a stable probe state",
                "Check auth, profile lock, or current UI state.",
            )
        finally:
            _run_command(["playwright-cli", "close"], timeout=5)


def _build_online_checks(notebooklm: dict[str, Path]) -> list[dict]:
    """Build read-only online diagnostics for Scholar Inbox and NotebookLM pages."""
    patterns = _load_notebooklm_ui_patterns()
    checks = [_probe_scholar_inbox_page()]

    if not notebooklm["profile"].exists():
        checks.append(
            _check(
                "warn",
                "NotebookLM online probes",
                "Skipped because NotebookLM profile is missing",
            )
        )
        return checks

    lock_processes = _profile_lock_processes(notebooklm["profile"])
    if lock_processes:
        checks.append(
            _check(
                "fail",
                "NotebookLM online probes",
                "Skipped because the NotebookLM profile is currently locked",
                f"Close those processes or run: pkill -f '{notebooklm['profile']}'",
            )
        )
        return checks

    checks.append(_probe_notebooklm_home_page(notebooklm, patterns))
    checks.append(_probe_notebooklm_source_dialog(notebooklm, patterns))
    return checks


def _build_doctor_report(online: bool = False) -> dict:
    """Build a local diagnostic report for Scholar Agent and NotebookLM integration."""
    config = _get_config()
    notebooklm = _notebooklm_paths()
    checks: list[dict] = []

    py_ver = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    checks.append(
        _check(
            "ok" if sys.version_info >= (3, 10) else "fail",
            "Python",
            f"Python {py_ver}",
            "Need Python 3.10+." if sys.version_info < (3, 10) else None,
            critical=True,
        )
    )

    checks.append(
        _check("ok", "scholar-inbox", f"scholar-inbox {scholar_inbox.__version__}", critical=True)
    )

    playwright_path = shutil.which("playwright-cli")
    if playwright_path:
        version_result = _run_command(["playwright-cli", "--version"], timeout=5)
        version = (version_result.stdout or version_result.stderr).strip() if version_result else ""
        detail = f"Found at {playwright_path}"
        if version:
            detail = f"{detail} ({version})"
        checks.append(_check("ok", "playwright-cli", detail))
    else:
        checks.append(
            _check(
                "warn",
                "playwright-cli",
                "Not found",
                "Install with: npm install -g @anthropic-ai/playwright-cli",
            )
        )

    session_state, session_detail = _session_status(config)
    checks.append(
        _check(
            session_state,
            "Scholar Inbox session",
            session_detail,
            "Run: scholar-inbox login --browser" if session_state != "ok" else None,
        )
    )

    if notebooklm["skill_dir"].exists():
        checks.append(_check("ok", "NotebookLM skill", f"Installed at {notebooklm['skill_dir']}"))
    else:
        checks.append(
            _check(
                "warn",
                "NotebookLM skill",
                "Not installed",
                "Install with: npx skills add notebooklm",
            )
        )

    if notebooklm["profile"].exists():
        checks.append(_check("ok", "NotebookLM profile", f"Profile dir: {notebooklm['profile']}"))
    else:
        checks.append(
            _check(
                "warn",
                "NotebookLM profile",
                f"Missing profile dir: {notebooklm['profile']}",
                "Run NotebookLM auth setup first.",
            )
        )

    state_file = notebooklm["state_file"]
    if state_file.exists():
        age_hours = (time.time() - state_file.stat().st_mtime) / 3600
        detail = f"state.json present ({age_hours:.1f}h old)"
        hint = "Auth may be stale; re-run NotebookLM auth if needed." if age_hours > 24 * 7 else None
        checks.append(_check("ok", "NotebookLM auth state", detail, hint))
    else:
        checks.append(
            _check(
                "warn",
                "NotebookLM auth state",
                f"Missing {state_file}",
                "Run: python ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py setup",
            )
        )

    if notebooklm["ask_question_script"].exists() and notebooklm["run_script"].exists():
        checks.append(_check("ok", "NotebookLM scripts", "ask_question.py and run.py available"))
    else:
        checks.append(
            _check(
                "warn",
                "NotebookLM scripts",
                "Missing ask_question.py or run.py",
                "Reinstall or inspect the notebooklm skill.",
            )
        )

    add_script = _first_existing(_script_candidates("add_to_notebooklm.sh"))
    create_script = _first_existing(_script_candidates("create_notebook.sh"))
    rename_script = _first_existing(_script_candidates("rename_notebook.sh"))
    site_knowledge = _first_existing(_script_candidates("notebooklm_site_knowledge.sh"))

    checks.append(
        _check(
            "ok" if add_script else "warn",
            "add_to_notebooklm.sh",
            str(add_script) if add_script else "Script not found",
            None if add_script else "Install/update the scholar-agent skill files.",
        )
    )
    checks.append(
        _check(
            "ok" if create_script else "warn",
            "create_notebook.sh",
            str(create_script) if create_script else "Script not found",
            None if create_script else "Install/update the scholar-agent skill files.",
        )
    )
    checks.append(
        _check(
            "ok" if rename_script else "warn",
            "rename_notebook.sh",
            str(rename_script) if rename_script else "Script not found",
            None if rename_script else "Install/update the scholar-agent skill files.",
        )
    )
    checks.append(
        _check(
            "ok" if site_knowledge else "warn",
            "NotebookLM site knowledge",
            str(site_knowledge) if site_knowledge else "Knowledge file not found",
            None if site_knowledge else "The UI regex knowledge file should live beside the scripts.",
        )
    )

    lock_processes = _profile_lock_processes(notebooklm["profile"]) if notebooklm["profile"].exists() else []
    if lock_processes:
        checks.append(
            _check(
                "fail",
                "NotebookLM profile lock",
                f"{len(lock_processes)} process(es) still reference the browser profile",
                f"Close those processes or run: pkill -f '{notebooklm['profile']}'",
            )
        )
    else:
        checks.append(_check("ok", "NotebookLM profile lock", "No active process currently references the profile"))

    if online:
        checks.extend(_build_online_checks(notebooklm))

    critical_failures = sum(1 for c in checks if c["critical"] and c["status"] == "fail")
    warnings = sum(1 for c in checks if c["status"] == "warn")
    failures = sum(1 for c in checks if c["status"] == "fail")
    enhanced_ready = (
        playwright_path is not None
        and notebooklm["skill_dir"].exists()
        and notebooklm["profile"].exists()
        and state_file.exists()
        and not lock_processes
        and add_script is not None
        and create_script is not None
        and rename_script is not None
        and site_knowledge is not None
    )

    return {
        "summary": {
            "critical_failures": critical_failures,
            "failures": failures,
            "warnings": warnings,
            "basic_ready": session_state == "ok",
            "enhanced_ready": enhanced_ready,
            "online_probe": online,
        },
        "checks": checks,
    }


def _print_doctor_report(report: dict) -> None:
    """Pretty-print a doctor report."""
    icons = {"ok": "\u2713", "warn": "\u26a0", "fail": "\u2717"}

    print("Scholar Agent Doctor\n")
    for check in report["checks"]:
        icon = icons.get(check["status"], "-")
        print(f"  {icon} {check['name']}: {check['detail']}")
        if check.get("hint"):
            print(f"    Hint: {check['hint']}")

    summary = report["summary"]
    print()
    mode = "Enhanced" if summary["enhanced_ready"] else "Basic" if summary["basic_ready"] else "Degraded"
    print(f"Mode: {mode}")
    print(
        f"Summary: {summary['failures']} failure(s), {summary['warnings']} warning(s), "
        f"{summary['critical_failures']} critical failure(s)"
    )


# --------------------------------------------------------------------------
# Command handlers
# --------------------------------------------------------------------------


def cmd_status(args):
    """Check login status."""
    config = _get_config()
    session = config.load_session()
    if not session:
        print("Not logged in. Run 'scholar-inbox login' first.")
        return

    try:
        client = _get_client(config)
        data = client.check_session()
        if data and data.get("is_logged_in"):
            print(f"Logged in as: {data.get('name', 'unknown')} (user_id: {data.get('user_id', '?')})")
        else:
            print("Session expired. Run 'scholar-inbox login' to refresh.")
    except SessionExpiredError:
        print("Session expired. Run 'scholar-inbox login' to refresh.")
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def cmd_login(args):
    """Extract or set session cookie."""
    config = _get_config()

    # Manual cookie provided
    if args.cookie:
        config.save_session(args.cookie)
        try:
            client = _get_client(config)
            data = client.check_session()
            if data and data.get("is_logged_in"):
                print(f"Logged in as: {data.get('name', 'unknown')}")
            else:
                print("Warning: Cookie saved but login check failed.", file=sys.stderr)
        except (APIError, Exception) as e:
            print(f"Warning: Cookie saved but verification failed: {e}", file=sys.stderr)
        return

    # Browser login (default) or explicit --browser
    cookie = open_browser_for_login()
    if cookie:
        config.save_session(cookie)
        try:
            client = _get_client(config)
            data = client.check_session()
            if data and data.get("is_logged_in"):
                print(f"Logged in as: {data.get('name', 'unknown')}")
                return
        except Exception:
            pass
        print("Cookie saved but verification failed. Try: scholar-inbox status", file=sys.stderr)
    else:
        print("Login failed. Try: scholar-inbox login --cookie YOUR_COOKIE", file=sys.stderr)
        sys.exit(1)


def cmd_digest(args):
    """Fetch paper digest."""
    client = _get_client()
    try:
        data = client.get_digest(date=args.date)
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not data:
        print("Error: Failed to fetch digest.", file=sys.stderr)
        sys.exit(1)

    papers = data.get("digest_df", [])
    total = _coerce_int(data.get("total_papers", len(papers)), len(papers))
    date_str = data.get("current_digest_date", "unknown")

    # Filter by min score
    if args.min_score is not None:
        papers = [p for p in papers if p.get("ranking_score", 0) >= args.min_score]

    # Limit output
    papers = papers[:args.limit]

    # JSON output
    if args.json:
        output = {
            "date": date_str,
            "total_papers": total,
            "showing": len(papers),
            "papers": [],
        }
        for p in papers:
            raw_contribution = (p.get("summaries") or {}).get("contributions_question", "")
            contribution, suspect_summary, mismatch_reason = _sanitize_summary(
                p.get("title", ""),
                raw_contribution,
            )
            output["papers"].append(
                {
                    "paper_id": p["paper_id"],
                    "title": p["title"],
                    "authors": p.get("shortened_authors", ""),
                    "ranking_score": round(p.get("ranking_score", 0), 3),
                    "rating": p.get("rating"),
                    "arxiv_id": p.get("arxiv_id"),
                    "keywords": p.get("keywords_metadata", {}).get("keywords", ""),
                    "category": p.get("category", ""),
                    "affiliations": _normalize_list(p.get("affiliations")),
                    "publication_date": p.get("publication_date", ""),
                    "abstract": (
                        p.get("abstract", "")[:200] + "..."
                        if len(p.get("abstract", "")) > 200
                        else p.get("abstract", "")
                    ),
                    "contribution": contribution,
                    "suspect_summary": suspect_summary,
                    "summary_mismatch_reason": mismatch_reason,
                }
            )
        print(json.dumps(output, ensure_ascii=False, indent=2))
        return

    # Human-readable output
    print(f"# Scholar Inbox Digest -- {date_str}")
    print(f"# Total: {total} papers, showing top {len(papers)}\n")

    for i, p in enumerate(papers, 1):
        score = p.get("ranking_score", 0)
        rating = p.get("rating")
        rating_str = " [up]" if rating == 1 else " [down]" if rating == -1 else ""
        keywords = p.get("keywords_metadata", {}).get("keywords", "")
        affiliations = ", ".join(_normalize_list(p.get("affiliations"))[:3])
        arxiv_id = p.get("arxiv_id", "")

        print(f"{i}. [{p['paper_id']}] {score:.3f}{rating_str} -- {p['title']}")
        print(f"   {p.get('shortened_authors', '')}")
        if affiliations:
            print(f"   Affiliations: {affiliations}")
        if keywords:
            print(f"   Keywords: {keywords}")
        if arxiv_id:
            print(f"   https://arxiv.org/abs/{arxiv_id}")

        summaries = p.get("summaries") or {}
        contrib, suspect_summary, _ = _sanitize_summary(
            p.get("title", ""),
            summaries.get("contributions_question", ""),
        )
        if contrib:
            first_line = contrib.strip().split("\n")[0].strip("- *")
            if first_line:
                print(f"   > {first_line[:120]}")
        elif suspect_summary:
            print("   > [summary hidden: suspected mismatch with paper title]")
        print()


def cmd_paper(args):
    """Show paper details."""
    client = _get_client()
    try:
        data = client.get_paper(args.paper_id)
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not data:
        print(f"Paper {args.paper_id} not found.", file=sys.stderr)
        print(
            "The upstream Scholar Inbox endpoint did not return an exact paper match. "
            "This can happen when their API falls back to a digest page.",
            file=sys.stderr,
        )
        sys.exit(1)

    paper = data
    print(f"# {paper.get('title', 'Unknown')}")
    print(f"Authors: {paper.get('shortened_authors', '')}")
    print(f"Affiliations: {', '.join(_normalize_list(paper.get('affiliations')))}")
    print(f"Published: {paper.get('publication_date', '')} | {paper.get('display_venue', '')}")
    print(f"Ranking Score: {paper.get('ranking_score', 0):.3f}")
    if paper.get("arxiv_id"):
        print(f"ArXiv: https://arxiv.org/abs/{paper['arxiv_id']}")
    if paper.get("github_url"):
        print(f"GitHub: {paper['github_url']}")
    print(f"Keywords: {paper.get('keywords_metadata', {}).get('keywords', '')}")
    print()

    print("## Abstract")
    print(paper.get("abstract", "N/A"))
    print()

    summaries = paper.get("summaries") or {}
    suppressed_labels: list[str] = []
    for key, label in [
        ("problem_definition_question", "Problem"),
        ("method_explanation_question", "Method"),
        ("contributions_question", "Contributions"),
        ("evaluation_question", "Evaluation"),
    ]:
        content, suspect_summary, _ = _sanitize_summary(
            paper.get("title", ""),
            summaries.get(key, ""),
        )
        if content:
            print(f"## {label}")
            print(content)
            print()
        elif suspect_summary:
            suppressed_labels.append(label)

    if suppressed_labels:
        print("## Summary Quality")
        print(
            "Suppressed suspect summary sections from Scholar Inbox: "
            + ", ".join(suppressed_labels)
        )
        print()


def cmd_rate(args):
    """Rate a paper."""
    rating = _parse_rating(args.rating)
    client = _get_client()
    try:
        client.rate(args.paper_id, rating)
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    labels = {1: "upvoted", -1: "downvoted", 0: "reset"}
    print(f"Paper {args.paper_id}: {labels[rating]}")


def cmd_rate_batch(args):
    """Batch rate multiple papers."""
    rating = _parse_rating(args.rating)
    client = _get_client()
    try:
        client.rate_batch(args.paper_ids, rating)
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    labels = {1: "upvoted", -1: "downvoted", 0: "reset"}
    print(f"{len(args.paper_ids)} papers: {labels[rating]}")


def cmd_trending(args):
    """Show trending papers."""
    client = _get_client()
    try:
        data = client.get_trending(
            category=args.category,
            days=args.days,
        )
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not data:
        print("Error: Failed to fetch trending.", file=sys.stderr)
        sys.exit(1)

    papers = (data.get("trending_df") or data.get("digest_df") or [])[:args.limit]
    print(f"# Trending Papers (last {args.days} days, category: {args.category})\n")

    for i, p in enumerate(papers, 1):
        print(f"{i}. [{p.get('paper_id', '')}] {p.get('title', 'Unknown')}")
        print(f"   {p.get('shortened_authors', '')}")
        if p.get("arxiv_id"):
            print(f"   https://arxiv.org/abs/{p['arxiv_id']}")
        print()


def cmd_collections(args):
    """List user collections."""
    client = _get_client()
    try:
        collections = client.get_collections()
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not collections:
        print("No collections found.")
        return

    print("# Collections\n")
    for c in collections:
        cid = c.get("collection_id", c.get("id", "?"))
        name = c.get("collection_name", c.get("name", "Unnamed"))
        count = c.get("paper_count")
        suffix = f" ({count} papers)" if count is not None else ""
        print(f"  [{cid}] {name}{suffix}")


def cmd_collect(args):
    """Add a paper to a collection."""
    client = _get_client()

    # Resolve collection: try as integer ID first, then as name
    collection_id = None
    try:
        collection_id = int(args.collection)
    except ValueError:
        # Look up by name
        try:
            collections = client.get_collections()
        except SessionExpiredError:
            print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
            sys.exit(1)
        except APIError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)

        name_lower = args.collection.lower()
        for c in collections:
            cname = c.get("collection_name", c.get("name", ""))
            if cname.lower() == name_lower:
                collection_id = c.get("collection_id", c.get("id"))
                break

        if collection_id is None:
            print(f"Error: Collection '{args.collection}' not found.", file=sys.stderr)
            print("Available collections:", file=sys.stderr)
            for c in collections:
                cid = c.get("collection_id", c.get("id", "?"))
                cname = c.get("collection_name", c.get("name", "Unnamed"))
                print(f"  [{cid}] {cname}", file=sys.stderr)
            sys.exit(1)

    try:
        result = client.add_to_collection(collection_id, args.paper_id)
        print(f"Paper {args.paper_id} added to collection {collection_id}")
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def cmd_read(args):
    """Mark a paper as read."""
    client = _get_client()
    try:
        client.mark_as_read(args.paper_id)
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Paper {args.paper_id}: marked as read")


def cmd_setup(args):
    """Interactive setup — check all prerequisites and guide user through configuration."""
    import shutil

    ok = "\u2713"
    fail = "\u2717"
    warn = "\u26a0"
    all_good = True

    print("Scholar Agent Setup\n")

    # 1. Python version
    py_ver = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    if sys.version_info >= (3, 10):
        print(f"  {ok} Python {py_ver}")
    else:
        print(f"  {fail} Python {py_ver} (need 3.10+)")
        all_good = False

    # 2. scholar-inbox importable
    try:
        import scholar_inbox as _si

        print(f"  {ok} scholar-inbox {_si.__version__}")
    except ImportError:
        print(f"  {fail} scholar-inbox not importable")
        all_good = False

    # 3. playwright-cli (required for login and NotebookLM)
    has_playwright = shutil.which("playwright-cli") is not None
    if has_playwright:
        print(f"  {ok} playwright-cli found")
    else:
        print(f"  {fail} playwright-cli not found")
        print(f"    Install: npm install -g @anthropic-ai/playwright-cli")
        print(f"    Then:    playwright-cli install chromium")
        all_good = False

    # 4. Login status
    config = _get_config()
    session = config.load_session()
    logged_in = False
    if session:
        try:
            client = _get_client(config)
            data = client.check_session()
            if data and data.get("is_logged_in"):
                name = data.get("name", "unknown")
                print(f"  {ok} Logged in as: {name}")
                logged_in = True
            else:
                print(f"  {fail} Session expired")
        except Exception:
            print(f"  {fail} Session invalid")
    else:
        print(f"  {fail} Not logged in")

    if not logged_in:
        all_good = False
        if has_playwright:
            print(f"\n  Attempting login via browser...\n")
            cookie = open_browser_for_login()
            if cookie:
                config.save_session(cookie)
                try:
                    client = _get_client(config)
                    data = client.check_session()
                    if data and data.get("is_logged_in"):
                        print(f"  {ok} Login successful: {data.get('name', 'unknown')}")
                        logged_in = True
                        all_good = True
                except Exception:
                    pass

            if not logged_in:
                print(f"  {fail} Browser login failed. Try manually:")
                print(f"    1. Open https://www.scholar-inbox.com in your browser")
                print(f"    2. Log in with Google")
                print(f"    3. Open DevTools (F12) → Application → Cookies")
                print(f"    4. Copy the 'session' cookie value")
                print(f"    5. Run: scholar-inbox login --cookie YOUR_COOKIE")
        else:
            print(f"\n  Cannot auto-login without playwright-cli.")
            print(f"  Install playwright-cli first, then re-run: scholar-inbox setup")
            print(f"  Or manually: scholar-inbox login --cookie YOUR_COOKIE")
            print(f"    (see above for how to get the cookie)")

    # 5. NotebookLM skill (optional)
    notebooklm_profile = Path.home() / ".claude" / "skills" / "notebooklm"
    if notebooklm_profile.exists():
        print(f"  {ok} NotebookLM skill installed")
    else:
        print(f"  {warn} NotebookLM skill not found (optional — enables deep reading mode)")

    # 6. Add-to-NotebookLM script
    script_candidates = [
        Path(__file__).parent.parent / "scripts" / "add_to_notebooklm.sh",
        Path.home() / ".agents" / "skills" / "scholar-inbox" / "scripts" / "add_to_notebooklm.sh",
    ]
    script_found = any(s.exists() for s in script_candidates)
    if has_playwright and notebooklm_profile.exists() and script_found:
        print(f"  {ok} NotebookLM batch-add script ready")
    elif not has_playwright or not notebooklm_profile.exists():
        pass  # Already warned above
    elif not script_found:
        print(f"  {warn} add_to_notebooklm.sh not found")

    # Summary
    print()
    if all_good:
        mode = "Enhanced (CLI + NotebookLM)" if (has_playwright and notebooklm_profile.exists()) else "Basic (CLI only)"
        print(f"  {ok} Setup complete! Mode: {mode}")
        print(f"\n  Try: scholar-inbox digest --limit 5")
    else:
        print(f"  {fail} Setup incomplete — fix the issues above and re-run: scholar-inbox setup")


def cmd_doctor(args):
    """Run local diagnostics for Scholar Agent and NotebookLM integration."""
    report = _build_doctor_report(online=args.online)

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        _print_doctor_report(report)

    if args.strict and report["summary"]["critical_failures"] > 0:
        sys.exit(1)


def cmd_e2e(args):
    """Run the Scholar Inbox -> NotebookLM -> Q&A flow in one command."""
    notebooklm = _notebooklm_paths()
    create_script = _first_existing(_script_candidates("create_notebook.sh"))
    rename_script = _first_existing(_script_candidates("rename_notebook.sh"))
    add_script = _first_existing(_script_candidates("add_to_notebooklm.sh"))

    if not create_script or not rename_script or not add_script:
        print("Error: NotebookLM scripts are incomplete. Run 'scholar-inbox doctor'.", file=sys.stderr)
        sys.exit(1)

    if not notebooklm["run_script"].exists() or not notebooklm["ask_question_script"].exists():
        print("Error: NotebookLM ask scripts are missing. Run 'scholar-inbox doctor'.", file=sys.stderr)
        sys.exit(1)

    client = _get_client()
    papers = []
    urls = []

    for paper_id in args.paper_ids:
        try:
            paper = client.get_paper(paper_id)
        except SessionExpiredError:
            print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
            sys.exit(1)
        except APIError as e:
            print(f"Error: Failed to fetch paper {paper_id}: {e}", file=sys.stderr)
            sys.exit(1)

        if not paper:
            print(f"Error: Paper {paper_id} not found in Scholar Inbox.", file=sys.stderr)
            sys.exit(1)

        arxiv_id = paper.get("arxiv_id")
        if not arxiv_id:
            print(f"Error: Paper {paper_id} has no arXiv ID and cannot be sent to NotebookLM.", file=sys.stderr)
            sys.exit(1)

        papers.append(
            {
                "paper_id": paper_id,
                "title": paper.get("title", ""),
                "arxiv_id": arxiv_id,
                "url": f"https://arxiv.org/abs/{arxiv_id}",
            }
        )
        urls.append(f"https://arxiv.org/abs/{arxiv_id}")

    create_result = _run_checked_command(
        ["bash", str(create_script)],
        timeout=180,
        description="create notebook",
    )
    notebook_url = create_result.stdout.strip().splitlines()[-1].strip()
    time.sleep(3)

    _run_checked_command(
        ["bash", str(rename_script), notebook_url, args.notebook_name],
        timeout=180,
        description="rename notebook",
    )
    time.sleep(2)

    _register_notebook_in_library(notebooklm, notebook_url, args.notebook_name)

    add_cmd = ["bash", str(add_script), notebook_url, *urls]
    _run_checked_command(
        add_cmd,
        timeout=240,
        description="add papers to notebook",
    )
    time.sleep(3)

    ask_result = _run_checked_command(
        [
            "python3",
            str(notebooklm["run_script"]),
            "ask_question.py",
            "--notebook-url",
            notebook_url,
            "--question",
            args.question,
        ],
        timeout=300,
        description="ask NotebookLM",
    )
    answer = _extract_answer_block(ask_result.stdout)

    output = {
        "notebook_name": args.notebook_name,
        "notebook_url": notebook_url,
        "paper_count": len(papers),
        "papers": papers,
        "question": args.question,
        "answer": answer,
    }

    if args.json:
        print(json.dumps(output, ensure_ascii=False, indent=2))
        return

    print(f"Notebook: {args.notebook_name}")
    print(notebook_url)
    print()
    print("Papers:")
    for paper in papers:
        print(f"- [{paper['paper_id']}] {paper['arxiv_id']} — {paper['title']}")
    print()
    print("Answer:")
    print(answer)


def cmd_config(args):
    """Show or set configuration values."""
    config = _get_config()

    if args.action == "set":
        if not args.key or args.value is None:
            print("Usage: scholar-inbox config set KEY VALUE", file=sys.stderr)
            sys.exit(1)
        config.set(args.key, args.value)
        print(f"Set {args.key} = {args.value}")
    else:
        # Show all config
        data = config.all()
        if not data:
            print("No configuration set.")
            return
        for k, v in data.items():
            print(f"{k} = {v}")


# --------------------------------------------------------------------------
# Argument parser
# --------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    """Build the CLI argument parser."""
    parser = argparse.ArgumentParser(
        prog="scholar-inbox",
        description="Scholar Inbox CLI -- manage your daily paper digest from the terminal.",
    )
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {scholar_inbox.__version__}"
    )

    subparsers = parser.add_subparsers(dest="command")

    # setup
    subparsers.add_parser("setup", help="Interactive setup — check prerequisites and configure")

    # doctor
    doctor_p = subparsers.add_parser("doctor", help="Diagnose local Scholar Agent / NotebookLM setup")
    doctor_p.add_argument("--json", action="store_true", help="Output machine-readable JSON")
    doctor_p.add_argument(
        "--online",
        action="store_true",
        help="Run read-only online probes against Scholar Inbox and NotebookLM pages",
    )
    doctor_p.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero on critical failures",
    )

    # e2e
    e2e_p = subparsers.add_parser(
        "e2e",
        help="Create a NotebookLM notebook, add papers, and ask a question in one run",
    )
    e2e_p.add_argument("--notebook-name", required=True, help="NotebookLM notebook name")
    e2e_p.add_argument("--question", required=True, help="Question to ask NotebookLM")
    e2e_p.add_argument("--json", action="store_true", help="Output machine-readable JSON")
    e2e_p.add_argument("paper_ids", type=int, nargs="+", help="Scholar Inbox paper IDs with arXiv IDs")

    # status
    subparsers.add_parser("status", help="Check login status")

    # login
    login_p = subparsers.add_parser("login", help="Extract/set session cookie")
    login_p.add_argument("--cookie", help="Manually provide session cookie value")
    login_p.add_argument(
        "--browser", action="store_true", help="Open browser for interactive OAuth login"
    )

    # digest
    digest_p = subparsers.add_parser("digest", help="Fetch paper digest")
    digest_p.add_argument("--limit", type=int, default=10, help="Max papers to show (default: 10)")
    digest_p.add_argument("--min-score", type=float, help="Minimum ranking score filter")
    digest_p.add_argument("--date", help="Specific date (YYYY-MM-DD)")
    digest_p.add_argument("--json", action="store_true", help="Output as JSON")

    # paper
    paper_p = subparsers.add_parser("paper", help="Show paper details")
    paper_p.add_argument("paper_id", type=int, help="Paper ID")

    # rate
    rate_p = subparsers.add_parser("rate", help="Rate a paper (up/down/reset or 1/-1/0)")
    rate_p.add_argument("paper_id", type=int, help="Paper ID")
    rate_p.add_argument("rating", help="Rating: up/down/reset or 1/-1/0")

    # rate-batch
    batch_p = subparsers.add_parser("rate-batch", help="Batch rate papers")
    batch_p.add_argument("rating", help="Rating: up/down/reset or 1/-1/0")
    batch_p.add_argument("paper_ids", type=int, nargs="+", help="Paper IDs")

    # trending
    trending_p = subparsers.add_parser("trending", help="Show trending papers")
    trending_p.add_argument("--category", default="ALL", help="Category filter (default: ALL)")
    trending_p.add_argument("--days", type=int, default=7, help="Time range in days (default: 7)")
    trending_p.add_argument("--limit", type=int, default=10, help="Max papers (default: 10)")

    # collections
    subparsers.add_parser("collections", help="List collections")

    # collect
    collect_p = subparsers.add_parser("collect", help="Add paper to collection")
    collect_p.add_argument("paper_id", type=int, help="Paper ID")
    collect_p.add_argument("collection", help="Collection name or ID")

    # read
    read_p = subparsers.add_parser("read", help="Mark paper as read")
    read_p.add_argument("paper_id", type=int, help="Paper ID")

    # config
    config_p = subparsers.add_parser("config", help="Show or set configuration")
    config_p.add_argument("action", nargs="?", choices=["set"], help="Action (set)")
    config_p.add_argument("key", nargs="?", help="Config key")
    config_p.add_argument("value", nargs="?", help="Config value")

    return parser


def main(argv: list[str] | None = None):
    """CLI entry point."""
    parser = build_parser()
    args = parser.parse_args(argv)

    if not args.command:
        parser.print_help()
        sys.exit(0)

    commands = {
        "setup": cmd_setup,
        "doctor": cmd_doctor,
        "e2e": cmd_e2e,
        "status": cmd_status,
        "login": cmd_login,
        "digest": cmd_digest,
        "paper": cmd_paper,
        "rate": cmd_rate,
        "rate-batch": cmd_rate_batch,
        "trending": cmd_trending,
        "collections": cmd_collections,
        "collect": cmd_collect,
        "read": cmd_read,
        "config": cmd_config,
    }

    handler = commands.get(args.command)
    if handler:
        handler(args)
    else:
        parser.print_help()
        sys.exit(1)
