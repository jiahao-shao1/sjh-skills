#!/usr/bin/env python3
"""Cluster-side persistent agent for MCP remote_bash.

Reads JSON-Lines requests from stdin, executes commands via subprocess,
writes JSON-Lines responses to stdout. Designed to run over a single
long-lived SSH connection.

Zero external dependencies - stdlib only.

Protocol:
  Request:  {"id": "...", "cmd": "...", "workdir": "...", "timeout": 120}
  Response: {"id": "...", "exit_code": 0, "output": "...", "elapsed": 0.03}
  Ping:     {"type": "ping"}
  Pong:     {"type": "pong", "uptime": 3600, "pid": 12345}
"""

import json
import os
import subprocess
import sys
import time

_START_TIME = time.monotonic()
_VERSION = "1.0.0"


def _execute(cmd, workdir=None, timeout=120):
    """Execute a shell command and return structured result."""
    start = time.monotonic()
    try:
        proc = subprocess.run(
            ["bash", "-c", cmd],
            cwd=workdir or None,
            capture_output=True,
            timeout=timeout,
        )
        elapsed = time.monotonic() - start
        output = proc.stdout.decode(errors="replace")
        if proc.stderr:
            stderr_text = proc.stderr.decode(errors="replace")
            if stderr_text.strip():
                output = output + stderr_text
        return {
            "exit_code": proc.returncode,
            "output": output,
            "elapsed": round(elapsed, 3),
        }
    except subprocess.TimeoutExpired:
        elapsed = time.monotonic() - start
        return {
            "exit_code": -1,
            "output": "Error: command timed out after {}s".format(timeout),
            "elapsed": round(elapsed, 3),
        }
    except Exception as e:
        elapsed = time.monotonic() - start
        return {
            "exit_code": -1,
            "output": "Error: {}".format(e),
            "elapsed": round(elapsed, 3),
        }


def _handle_request(req):
    """Process a single request and return response dict."""
    if req.get("type") == "ping":
        return {
            "type": "pong",
            "uptime": round(time.monotonic() - _START_TIME, 1),
            "pid": os.getpid(),
            "version": _VERSION,
        }

    req_id = req.get("id", "unknown")
    cmd = req.get("cmd")
    if not cmd:
        return {"id": req_id, "exit_code": -1, "output": "Error: missing 'cmd'", "elapsed": 0}

    workdir = req.get("workdir")
    timeout = req.get("timeout", 120)

    result = _execute(cmd, workdir, timeout)
    result["id"] = req_id
    return result


def main():
    """Main loop: read JSON-Lines from stdin, write responses to stdout."""
    ready_msg = json.dumps({"type": "ready", "version": _VERSION, "pid": os.getpid()})
    sys.stdout.write(ready_msg + "\n")
    sys.stdout.flush()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError as e:
            err = json.dumps({"id": "unknown", "exit_code": -1, "output": "JSON parse error: {}".format(e), "elapsed": 0})
            sys.stdout.write(err + "\n")
            sys.stdout.flush()
            continue

        response = _handle_request(req)
        sys.stdout.write(json.dumps(response) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
