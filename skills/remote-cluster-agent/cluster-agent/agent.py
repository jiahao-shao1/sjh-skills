#!/usr/bin/env python3
"""Cluster-side persistent agent — v2.1.0.

Reads JSON-Lines requests from stdin, executes commands via subprocess,
writes JSON-Lines responses to stdout. Designed to run over a single
long-lived SSH connection.

v2.1 adds: file transfer (write_file / read_file) via agent channel.
v2   adds: concurrent execution, streaming output, command cancellation.

Zero external dependencies - stdlib only.

Protocol v2.1:
  Execute:    {"id": "...", "cmd": "...", "workdir": "...", "timeout": 120, "stream": true}
  Cancel:     {"type": "cancel", "id": "..."}
  Batch:      {"type": "batch", "id": "...", "commands": [...]}
  Ping:       {"type": "ping"}
  WriteFile:  {"type": "write_file", "id": "...", "path": "/dst", "data": "<base64>", "mode": "0644"}
  ReadFile:   {"type": "read_file", "id": "...", "path": "/src"}

  Ready:     {"type": "ready", "version": "2.1.0", "pid": 12345}
  Stream:    {"id": "...", "type": "stream", "data": "line\\n"}
  Result:    {"id": "...", "type": "result", "exit_code": 0, "output": "...", "elapsed": 5.2}
  FileData:  {"id": "...", "type": "file_data", "data": "<base64>", "size": 1234}
  Cancelled: {"id": "...", "type": "cancelled", "elapsed": 2.1}
  Batch:     {"type": "batch_result", "id": "...", "results": [...], "total_elapsed": 3.5}
  Pong:      {"type": "pong", "uptime": 120.5, "pid": 12345, "version": "2.1.0"}
"""

import base64
import concurrent.futures
import json
import os
import signal
import subprocess
import sys
import threading
import time

_START_TIME = time.monotonic()
_VERSION = "2.1.0"
_MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB

# Thread-safe stdout writing
_write_lock = threading.Lock()

# Track running subprocesses for cancellation: id -> Popen
_active = {}
_active_lock = threading.Lock()


def _kill_proc_group(proc):
    """Kill a process and its entire process group."""
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except OSError:
        try:
            proc.kill()
        except OSError:
            pass


def _respond(msg):
    """Thread-safe JSON-Lines response writer."""
    line = json.dumps(msg, ensure_ascii=False) + "\n"
    with _write_lock:
        sys.stdout.write(line)
        sys.stdout.flush()


def _execute_streaming(req_id, cmd, workdir, timeout):
    """Execute command with line-by-line streaming output."""
    start = time.monotonic()
    deadline = start + timeout
    output_lines = []

    try:
        proc = subprocess.Popen(
            ["bash", "-c", cmd],
            cwd=workdir or None,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        with _active_lock:
            _active[req_id] = proc

        try:
            for raw_line in iter(proc.stdout.readline, b""):
                # Check if we've been cancelled (proc.returncode set by cancel)
                if proc.poll() is not None and req_id not in _active:
                    break

                text = raw_line.decode(errors="replace")
                output_lines.append(text)
                _respond({"id": req_id, "type": "stream", "data": text})

                # Check timeout
                if time.monotonic() > deadline:
                    _kill_proc_group(proc)
                    proc.wait()
                    elapsed = round(time.monotonic() - start, 3)
                    with _active_lock:
                        _active.pop(req_id, None)
                    _respond({
                        "id": req_id,
                        "type": "result",
                        "exit_code": -1,
                        "output": "Error: command timed out after {}s".format(timeout),
                        "elapsed": elapsed,
                    })
                    return

            proc.wait(timeout=max(0.1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            _kill_proc_group(proc)
            proc.wait()
            elapsed = round(time.monotonic() - start, 3)
            with _active_lock:
                _active.pop(req_id, None)
            _respond({
                "id": req_id,
                "type": "result",
                "exit_code": -1,
                "output": "Error: command timed out after {}s".format(timeout),
                "elapsed": elapsed,
            })
            return

        with _active_lock:
            removed = _active.pop(req_id, None)

        # If cancelled, the cancel handler sends the response
        if removed is None:
            return

        elapsed = round(time.monotonic() - start, 3)
        _respond({
            "id": req_id,
            "type": "result",
            "exit_code": proc.returncode,
            "output": "".join(output_lines),
            "elapsed": elapsed,
        })

    except Exception as e:
        elapsed = round(time.monotonic() - start, 3)
        with _active_lock:
            _active.pop(req_id, None)
        _respond({
            "id": req_id,
            "type": "result",
            "exit_code": -1,
            "output": "Error: {}".format(e),
            "elapsed": elapsed,
        })


def _execute_simple(req_id, cmd, workdir, timeout):
    """Execute command without streaming (v1-compatible behavior)."""
    start = time.monotonic()
    try:
        proc = subprocess.Popen(
            ["bash", "-c", cmd],
            cwd=workdir or None,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        with _active_lock:
            _active[req_id] = proc

        try:
            stdout_data, _ = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            _kill_proc_group(proc)
            proc.wait()
            elapsed = round(time.monotonic() - start, 3)
            with _active_lock:
                _active.pop(req_id, None)
            _respond({
                "id": req_id,
                "type": "result",
                "exit_code": -1,
                "output": "Error: command timed out after {}s".format(timeout),
                "elapsed": elapsed,
            })
            return

        with _active_lock:
            removed = _active.pop(req_id, None)

        # If cancelled, the cancel handler sends the response
        if removed is None:
            return

        elapsed = round(time.monotonic() - start, 3)
        output = stdout_data.decode(errors="replace")
        _respond({
            "id": req_id,
            "type": "result",
            "exit_code": proc.returncode,
            "output": output,
            "elapsed": elapsed,
        })

    except Exception as e:
        elapsed = round(time.monotonic() - start, 3)
        with _active_lock:
            _active.pop(req_id, None)
        _respond({
            "id": req_id,
            "type": "result",
            "exit_code": -1,
            "output": "Error: {}".format(e),
            "elapsed": elapsed,
        })


def _handle_cancel(req_id):
    """Cancel a running command. Runs inline (not in thread pool)."""
    start = time.monotonic()
    with _active_lock:
        proc = _active.pop(req_id, None)

    if proc is None:
        # Not found or already finished
        _respond({
            "id": req_id,
            "type": "cancelled",
            "elapsed": 0,
        })
        return

    # Send SIGTERM to entire process group
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except OSError:
        pass

    # Wait up to 5s for graceful shutdown
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        # Force kill entire process group
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            pass
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass

    elapsed = round(time.monotonic() - start, 3)
    _respond({
        "id": req_id,
        "type": "cancelled",
        "elapsed": elapsed,
    })


def _handle_batch(req):
    """Process a batch request: execute multiple commands in parallel."""
    req_id = req.get("id", "unknown")
    commands = req.get("commands", [])
    if not commands:
        _respond({"type": "batch_result", "id": req_id, "results": [], "total_elapsed": 0})
        return

    start = time.monotonic()
    max_workers = min(len(commands), 8)

    def run_one(c):
        s = time.monotonic()
        try:
            proc = subprocess.run(
                ["bash", "-c", c.get("cmd", "")],
                cwd=c.get("workdir") or None,
                capture_output=True,
                timeout=c.get("timeout", 120),
            )
            elapsed = round(time.monotonic() - s, 3)
            output = proc.stdout.decode(errors="replace")
            if proc.stderr:
                stderr_text = proc.stderr.decode(errors="replace")
                if stderr_text.strip():
                    output = output + stderr_text
            return {"exit_code": proc.returncode, "output": output, "elapsed": elapsed}
        except subprocess.TimeoutExpired:
            elapsed = round(time.monotonic() - s, 3)
            return {"exit_code": -1, "output": "Error: command timed out after {}s".format(c.get("timeout", 120)), "elapsed": elapsed}
        except Exception as e:
            elapsed = round(time.monotonic() - s, 3)
            return {"exit_code": -1, "output": "Error: {}".format(e), "elapsed": elapsed}

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = [pool.submit(run_one, c) for c in commands]
        results = [f.result() for f in futures]

    total_elapsed = round(time.monotonic() - start, 3)
    _respond({"type": "batch_result", "id": req_id, "results": results, "total_elapsed": total_elapsed})


def _handle_write_file(req):
    """Write base64-encoded data to a file on disk."""
    req_id = req.get("id", "unknown")
    path = req.get("path", "")
    data_b64 = req.get("data", "")
    mode = req.get("mode", "0644")
    start = time.monotonic()

    if not path:
        _respond({"id": req_id, "type": "result", "exit_code": 1,
                  "output": "Error: missing 'path'", "elapsed": 0})
        return

    try:
        raw = base64.b64decode(data_b64)
    except Exception as e:
        elapsed = round(time.monotonic() - start, 3)
        _respond({"id": req_id, "type": "result", "exit_code": 1,
                  "output": "Error: base64 decode: {}".format(e), "elapsed": elapsed})
        return

    if len(raw) > _MAX_FILE_SIZE:
        elapsed = round(time.monotonic() - start, 3)
        _respond({"id": req_id, "type": "result", "exit_code": 1,
                  "output": "Error: file too large ({} bytes, max {})".format(len(raw), _MAX_FILE_SIZE),
                  "elapsed": elapsed})
        return

    try:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "wb") as f:
            f.write(raw)
        os.chmod(path, int(mode, 8))
        elapsed = round(time.monotonic() - start, 3)
        _respond({"id": req_id, "type": "result", "exit_code": 0,
                  "output": "wrote {} bytes to {}".format(len(raw), path), "elapsed": elapsed})
    except Exception as e:
        elapsed = round(time.monotonic() - start, 3)
        _respond({"id": req_id, "type": "result", "exit_code": 1,
                  "output": "Error: {}".format(e), "elapsed": elapsed})


def _handle_read_file(req):
    """Read a file from disk and return as base64."""
    req_id = req.get("id", "unknown")
    path = req.get("path", "")
    start = time.monotonic()

    if not path:
        _respond({"id": req_id, "type": "result", "exit_code": 1,
                  "output": "Error: missing 'path'", "elapsed": 0})
        return

    try:
        size = os.path.getsize(path)
        if size > _MAX_FILE_SIZE:
            elapsed = round(time.monotonic() - start, 3)
            _respond({"id": req_id, "type": "result", "exit_code": 1,
                      "output": "Error: file too large ({} bytes, max {})".format(size, _MAX_FILE_SIZE),
                      "elapsed": elapsed})
            return
        with open(path, "rb") as f:
            raw = f.read()
        elapsed = round(time.monotonic() - start, 3)
        _respond({"id": req_id, "type": "file_data",
                  "data": base64.b64encode(raw).decode("ascii"),
                  "size": len(raw), "elapsed": elapsed})
    except Exception as e:
        elapsed = round(time.monotonic() - start, 3)
        _respond({"id": req_id, "type": "result", "exit_code": 1,
                  "output": "Error: {}".format(e), "elapsed": elapsed})


def main():
    """Main loop: read JSON-Lines from stdin, dispatch to thread pool."""
    _respond({"type": "ready", "version": _VERSION, "pid": os.getpid()})

    pool = concurrent.futures.ThreadPoolExecutor(max_workers=16)

    try:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                req = json.loads(line)
            except json.JSONDecodeError as e:
                _respond({
                    "id": "unknown",
                    "type": "result",
                    "exit_code": -1,
                    "output": "JSON parse error: {}".format(e),
                    "elapsed": 0,
                })
                continue

            req_type = req.get("type")

            # Ping: respond inline, fast
            if req_type == "ping":
                _respond({
                    "type": "pong",
                    "uptime": round(time.monotonic() - _START_TIME, 1),
                    "pid": os.getpid(),
                    "version": _VERSION,
                })
                continue

            # Cancel: runs inline (fast, no thread pool needed)
            if req_type == "cancel":
                cancel_id = req.get("id", "unknown")
                _handle_cancel(cancel_id)
                continue

            # Batch: dispatch to thread pool
            if req_type == "batch":
                pool.submit(_handle_batch, req)
                continue

            # File transfer
            if req_type == "write_file":
                pool.submit(_handle_write_file, req)
                continue
            if req_type == "read_file":
                pool.submit(_handle_read_file, req)
                continue

            # Execute command
            req_id = req.get("id", "unknown")
            cmd = req.get("cmd")
            if not cmd:
                _respond({
                    "id": req_id,
                    "type": "result",
                    "exit_code": -1,
                    "output": "Error: missing 'cmd'",
                    "elapsed": 0,
                })
                continue

            workdir = req.get("workdir")
            timeout = req.get("timeout", 120)
            stream = req.get("stream", False)

            if stream:
                pool.submit(_execute_streaming, req_id, cmd, workdir, timeout)
            else:
                pool.submit(_execute_simple, req_id, cmd, workdir, timeout)

    except KeyboardInterrupt:
        pass
    finally:
        pool.shutdown(wait=False)


if __name__ == "__main__":
    main()
