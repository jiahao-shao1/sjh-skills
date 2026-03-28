"""Remote Cluster MCP Server - Proxy command operations to remote cluster via SSH.

Two execution modes:
1. **Agent mode** (fast): Persistent SSH connection to a cluster-side agent.
   Commands sent as JSON-Lines, results returned immediately. ~0.1s per command.
2. **Sentinel mode** (fallback): Per-command SSH with sentinel pattern detection.
   Used when agent is unavailable. ~1.5s per command.

The server tries agent mode first and falls back to sentinel mode automatically.

Configuration via environment variables:
  NODES='{"train": "ssh -p 2222 gpu-node", "eval": "ssh gpu-eval"}'
  REMOTE_PROJECT_DIR='/home/user/project'
  REMOTE_AGENT_PATH='~/.mcp-agent/agent.py'

Legacy single-node mode (backward compatible):
  SSH_CMD='ssh -p 2222 gpu-node'
"""

import atexit
import json
import os
import re
import select
import subprocess
import sys
import threading
import time
import uuid
from typing import Annotated

from pydantic import Field
from mcp.server.fastmcp import FastMCP

# --- Node configuration ---
# Multi-node: JSON dict of {name: ssh_cmd}
_NODES_JSON = os.environ.get("NODES", "")
# Legacy single-node
_SSH_CMD = os.environ.get("SSH_CMD", "")

REMOTE_PROJECT_DIR = os.environ.get("REMOTE_PROJECT_DIR", "")

# Path to agent.py on shared storage (accessible from all nodes)
REMOTE_AGENT_PATH = os.environ.get("REMOTE_AGENT_PATH", "~/.mcp-agent/agent.py")

# Parse node configuration
NODES: dict[str, str] = {}
if _NODES_JSON:
    NODES = json.loads(_NODES_JSON)
elif _SSH_CMD:
    # Legacy: single node named "default"
    NODES = {"default": _SSH_CMD}

# Determine the default node (first one, or "default")
DEFAULT_NODE = next(iter(NODES), "default") if NODES else "default"

mcp = FastMCP("remote-cluster")

# Sentinel pattern for detecting command completion (fallback mode)
_SENTINEL_RE = re.compile(rb"___MCP_EXIT_(\d+)___\r?\n?$")
_SENTINEL_STR_RE = re.compile(r"___MCP_EXIT_(\d+)___\r?\n?$")

SSH_MAX_RETRIES = int(os.environ.get("SSH_MAX_RETRIES", "3"))
SSH_RETRY_DELAY = float(os.environ.get("SSH_RETRY_DELAY", "2"))


# ---------------------------------------------------------------------------
# Agent mode: persistent SSH connection with JSON-Lines protocol
# ---------------------------------------------------------------------------


class AgentConnection:
    """Manages a persistent SSH connection to the cluster-side agent."""

    def __init__(self, ssh_cmd: str, agent_path: str):
        self._ssh_cmd = ssh_cmd
        self._agent_path = agent_path
        self._proc: subprocess.Popen | None = None
        self._lock = threading.Lock()
        self._connected = False
        self._read_buf = b""

    @property
    def connected(self) -> bool:
        return self._connected and self._proc is not None and self._proc.poll() is None

    def connect(self) -> bool:
        """Establish SSH connection to the remote agent. Returns True on success."""
        with self._lock:
            self._disconnect_unlocked()
            self._read_buf = b""
            try:
                ssh_args = self._ssh_cmd.split() + [
                    "-o", "ServerAliveInterval=30",
                    "-o", "ServerAliveCountMax=3",
                    f"python3 {self._agent_path}",
                ]
                self._proc = subprocess.Popen(
                    ssh_args,
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                )
                ready_line = self._read_line(timeout=10)
                if ready_line and ready_line.get("type") == "ready":
                    self._connected = True
                    print(
                        f"Agent connected (v{ready_line.get('version', '?')}, "
                        f"pid={ready_line.get('pid', '?')})",
                        file=sys.stderr,
                    )
                    return True
                else:
                    print(f"Agent handshake failed: {ready_line}", file=sys.stderr)
                    self._disconnect_unlocked()
                    return False
            except Exception as e:
                print(f"Agent connection failed: {e}", file=sys.stderr)
                self._disconnect_unlocked()
                return False

    def disconnect(self) -> None:
        with self._lock:
            self._disconnect_unlocked()

    def _disconnect_unlocked(self) -> None:
        self._connected = False
        if self._proc is not None:
            try:
                self._proc.kill()
                self._proc.wait(timeout=2)
            except Exception:
                pass
            self._proc = None

    def execute(self, command: str, workdir: str = "", timeout: int = 120) -> str | None:
        """Send a command to the agent. Returns output string, or None if agent unavailable."""
        with self._lock:
            if not self.connected:
                return None
            try:
                req = {
                    "id": uuid.uuid4().hex[:8],
                    "cmd": command,
                    "timeout": timeout,
                }
                if workdir:
                    req["workdir"] = workdir
                self._write_line(req)
                resp = self._read_line(timeout=timeout + 5)
                if resp is None:
                    print("Agent read timeout, disconnecting", file=sys.stderr)
                    self._disconnect_unlocked()
                    return None
                exit_code = resp.get("exit_code", -1)
                output = resp.get("output", "")
                if exit_code != 0:
                    return f"Error (exit code {exit_code}):\n{output}".strip()
                return output
            except Exception as e:
                print(f"Agent execute error: {e}", file=sys.stderr)
                self._disconnect_unlocked()
                return None

    def ping(self) -> dict | None:
        """Send a ping to the agent. Returns pong dict or None."""
        with self._lock:
            if not self.connected:
                return None
            try:
                self._write_line({"type": "ping"})
                return self._read_line(timeout=5)
            except Exception:
                self._disconnect_unlocked()
                return None

    def _write_line(self, data: dict) -> None:
        assert self._proc and self._proc.stdin
        line = json.dumps(data) + "\n"
        self._proc.stdin.write(line.encode())
        self._proc.stdin.flush()

    def _read_line(self, timeout: float = 10) -> dict | None:
        assert self._proc and self._proc.stdout
        start = time.time()
        if b"\n" in self._read_buf:
            line, self._read_buf = self._read_buf.split(b"\n", 1)
            return json.loads(line.decode())
        while time.time() - start < timeout:
            remaining = timeout - (time.time() - start)
            if remaining <= 0:
                break
            ready, _, _ = select.select([self._proc.stdout], [], [], min(remaining, 0.5))
            if ready:
                chunk = os.read(self._proc.stdout.fileno(), 65536)
                if not chunk:
                    return None
                self._read_buf += chunk
                if b"\n" in self._read_buf:
                    line, self._read_buf = self._read_buf.split(b"\n", 1)
                    return json.loads(line.decode())
        return None


# ---------------------------------------------------------------------------
# Connection pool: one AgentConnection per node
# ---------------------------------------------------------------------------

_agents: dict[str, AgentConnection] = {}
_agents_lock = threading.Lock()


def _get_agent(node: str) -> AgentConnection | None:
    """Get or create an AgentConnection for the given node."""
    ssh_cmd = NODES.get(node)
    if not ssh_cmd:
        return None
    with _agents_lock:
        if node not in _agents:
            _agents[node] = AgentConnection(ssh_cmd, REMOTE_AGENT_PATH)
        return _agents[node]


def _cleanup_agents() -> None:
    for agent in _agents.values():
        agent.disconnect()


atexit.register(_cleanup_agents)


def _resolve_node(node: str) -> str:
    """Resolve node name, returning the node or raising error if unknown."""
    if node and node in NODES:
        return node
    if not node:
        return DEFAULT_NODE
    matches = [n for n in NODES if n.startswith(node)]
    if len(matches) == 1:
        return matches[0]
    available = ", ".join(NODES.keys()) if NODES else "(none configured)"
    raise ValueError(f"Unknown node '{node}'. Available: {available}")


# ---------------------------------------------------------------------------
# Sentinel mode (fallback): per-command SSH with sentinel detection
# ---------------------------------------------------------------------------


def _ssh_exec_once(ssh_cmd: str, command: str, input_data: bytes | None = None, timeout: int = 120) -> tuple[str, bool]:
    """Single attempt to execute a command via SSH sentinel mode."""
    wrapped_cmd = f'{command} 2>&1; echo "___MCP_EXIT_${{?}}___"'

    ssh_args = ssh_cmd.split() + ["-tt", wrapped_cmd]
    proc = subprocess.Popen(
        ssh_args,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )

    if input_data is not None and proc.stdin:
        proc.stdin.write(input_data)
        proc.stdin.close()

    output = b""
    start_time = time.time()

    try:
        while time.time() - start_time < timeout:
            ready, _, _ = select.select([proc.stdout], [], [], 0.5)
            if ready:
                chunk = os.read(proc.stdout.fileno(), 65536)
                if not chunk:
                    break
                output += chunk
                if _SENTINEL_RE.search(output):
                    break
    except Exception:
        pass
    finally:
        proc.kill()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.terminate()

    decoded = output.decode(errors="replace")
    decoded = decoded.replace("\r\n", "\n")
    match = _SENTINEL_STR_RE.search(decoded)

    if match:
        exit_code = int(match.group(1))
        clean_output = decoded[: match.start()]
        if exit_code != 0:
            return f"Error (exit code {exit_code}):\n{clean_output}".strip(), True
        return clean_output, True
    else:
        return decoded, False


def _ssh_exec_sentinel(ssh_cmd: str, command: str, input_data: bytes | None = None, timeout: int = 120) -> str:
    """Execute via sentinel mode with retries."""
    last_output = ""
    for attempt in range(SSH_MAX_RETRIES):
        result, success = _ssh_exec_once(ssh_cmd, command, input_data, timeout)
        if success:
            return result
        last_output = result
        if attempt < SSH_MAX_RETRIES - 1:
            print(f"SSH sentinel attempt {attempt + 1} failed, retrying in {SSH_RETRY_DELAY}s...", file=sys.stderr)
            time.sleep(SSH_RETRY_DELAY)

    return f"Error: SSH failed after {SSH_MAX_RETRIES} attempts. Partial output:\n{last_output}".strip()


# ---------------------------------------------------------------------------
# Unified execution: agent mode with sentinel fallback
# ---------------------------------------------------------------------------


def ssh_exec(node: str, command: str, input_data: bytes | None = None, timeout: int = 120) -> str:
    """Execute a command on a specific cluster node.

    Tries agent mode first (fast), falls back to sentinel mode (reliable).
    """
    ssh_cmd = NODES.get(node, "")
    if not ssh_cmd:
        return f"Error: unknown node '{node}'"

    # Agent mode (doesn't support input_data)
    if input_data is None:
        agent = _get_agent(node)
        if agent is not None:
            if not agent.connected:
                agent.connect()
            if agent.connected:
                result = agent.execute(command, timeout=timeout)
                if result is not None:
                    return result
                print(f"Agent on {node} failed, attempting reconnect...", file=sys.stderr)
                if agent.connect():
                    result = agent.execute(command, timeout=timeout)
                    if result is not None:
                        return result

    # Fallback to sentinel mode
    return _ssh_exec_sentinel(ssh_cmd, command, input_data, timeout)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _remote_bash(command: str, node: str = "", workdir: str = "", timeout: int = 120) -> str:
    resolved = _resolve_node(node)
    if workdir:
        full_cmd = f"cd '{workdir}' && {command}"
    elif REMOTE_PROJECT_DIR:
        full_cmd = f"cd '{REMOTE_PROJECT_DIR}' && {command}"
    else:
        full_cmd = command
    return ssh_exec(resolved, full_cmd, timeout=timeout)


# ---------------------------------------------------------------------------
# MCP Tools
# ---------------------------------------------------------------------------

# Build dynamic node description
_node_list = ", ".join(f'"{n}"' for n in NODES) if NODES else "(none)"
_node_desc = f"Target node name. Available: {_node_list}. Default: \"{DEFAULT_NODE}\"."


@mcp.tool()
def remote_bash(
    command: Annotated[
        str, Field(description="Shell command to execute on the remote cluster")
    ],
    node: Annotated[
        str,
        Field(description=_node_desc),
    ] = "",
    workdir: Annotated[
        str,
        Field(
            description="Working directory (absolute path). Defaults to REMOTE_PROJECT_DIR."
        ),
    ] = "",
    timeout: Annotated[
        int,
        Field(
            description="Timeout in seconds. Default 120. Use longer for training (e.g., 3600)."
        ),
    ] = 120,
) -> str:
    """Execute a shell command on the remote cluster. Use longer timeout for training/experiments."""
    try:
        return _remote_bash(command, node, workdir, timeout)
    except ValueError as e:
        return str(e)


if __name__ == "__main__":
    mcp.run(transport="stdio")
