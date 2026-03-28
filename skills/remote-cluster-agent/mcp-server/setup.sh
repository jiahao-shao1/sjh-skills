#!/bin/bash
# Remote Cluster MCP server setup
#
# Single MCP server managing all cluster nodes via the `node` parameter.
#
# Usage:
#   bash setup.sh [--client claude|codex] <nodes_json> <remote_project_dir> [agent_path]
#   bash setup.sh [--client claude|codex] <name> "<ssh_cmd>" <remote_project_dir> [agent_path]
#
# Examples:
#   bash setup.sh '{"train":"ssh -p 2222 gpu-node","eval":"ssh gpu-eval"}' /home/user/project
#   bash setup.sh '{"train":"ssh -p 2222 gpu-node"}' /data/project ~/.mcp-agent/agent.py
#   bash setup.sh --client codex '{"train":"ssh -p 2222 gpu-node"}' /home/user/project
#
# Legacy single-node mode (backward compatible):
#   bash setup.sh train "ssh -p 2222 gpu-node" /home/user/project
#
# Prerequisites:
#   1. uv (https://docs.astral.sh/uv/) or pip
#   2. SSH access to cluster established
#   3. Claude Code or Codex CLI installed
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CALLER_DIR="$(pwd)"

# ---- Parse --client flag ----
CLIENT=""
if [ "${1:-}" = "--client" ]; then
    CLIENT="${2:-}"
    shift 2
fi

if [ -n "$CLIENT" ] && [ "$CLIENT" != "claude" ] && [ "$CLIENT" != "codex" ]; then
    echo "Error: --client must be 'claude' or 'codex'"
    exit 1
fi

# ---- Auto-detect client if not specified ----
if [ -z "$CLIENT" ]; then
    HAS_CLAUDE=0
    HAS_CODEX=0
    if command -v claude >/dev/null 2>&1; then
        HAS_CLAUDE=1
    fi
    if command -v codex >/dev/null 2>&1; then
        HAS_CODEX=1
    fi

    if [ "$HAS_CLAUDE" -eq 1 ] && [ "$HAS_CODEX" -eq 0 ]; then
        CLIENT="claude"
    elif [ "$HAS_CLAUDE" -eq 0 ] && [ "$HAS_CODEX" -eq 1 ]; then
        CLIENT="codex"
    elif [ "$HAS_CLAUDE" -eq 1 ] && [ "$HAS_CODEX" -eq 1 ]; then
        CLIENT="claude"
        echo "==> Both Claude Code and Codex detected; defaulting to Claude Code."
        echo "    Use --client codex to register with Codex instead."
    else
        echo "Error: neither 'claude' nor 'codex' found in PATH."
        exit 1
    fi
fi

# ---- Detect mode: multi-node (JSON) or legacy single-node ----
# Validate JSON is a dict with string keys/values (not just any valid JSON)
if echo "$1" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert isinstance(d, dict) and d, 'must be non-empty dict'
assert all(isinstance(k, str) and isinstance(v, str) for k, v in d.items()), 'keys and values must be strings'
" 2>/dev/null; then
    # Multi-node mode
    NODES_JSON="$1"
    REMOTE_DIR="${2:-}"
    AGENT_PATH="${3:-~/.mcp-agent/agent.py}"

    if [ -z "$NODES_JSON" ] || [ -z "$REMOTE_DIR" ]; then
        echo "Usage: bash setup.sh [--client claude|codex] <nodes_json> <remote_project_dir> [agent_path]"
        echo ""
        echo "  nodes_json:         JSON dict of {name: ssh_cmd}"
        echo "  remote_project_dir: Project path on cluster"
        echo "  agent_path:         Agent script path (default: ~/.mcp-agent/agent.py)"
        echo ""
        echo "Examples:"
        echo "  bash setup.sh '{\"train\":\"ssh -p 2222 gpu-node\"}' /home/user/project"
        echo "  bash setup.sh --client codex '{\"train\":\"ssh gpu-node\"}' /data/project"
        exit 1
    fi
else
    # Legacy single-node mode
    NAME="${1:-}"
    SSH_CMD="${2:-}"
    REMOTE_DIR="${3:-}"
    AGENT_PATH="${4:-~/.mcp-agent/agent.py}"

    if [ -z "$NAME" ] || [ -z "$SSH_CMD" ] || [ -z "$REMOTE_DIR" ]; then
        echo "Usage: bash setup.sh [--client claude|codex] <name> <ssh_cmd> <remote_project_dir> [agent_path]"
        echo ""
        echo "  name:               Node name (e.g., train, eval)"
        echo "  ssh_cmd:            SSH command (e.g., \"ssh -p 2222 gpu-node\")"
        echo "  remote_project_dir: Project path on cluster"
        echo ""
        echo "Or multi-node mode:"
        echo "  bash setup.sh '{\"train\":\"ssh -p 2222 gpu-node\"}' /home/user/project"
        exit 1
    fi

    # Build JSON safely via python to avoid injection from special characters
    NODES_JSON="$(python3 -c "import json,sys; print(json.dumps({sys.argv[1]: sys.argv[2]}))" "$NAME" "$SSH_CMD")"
    echo "Legacy mode: converting to multi-node format: $NODES_JSON"
fi

# ---- 1. Create venv + install dependencies ----
# venv lives in ~/.config/remote-cluster-agent/ (outside skill dir, safe from sync)
CONFIG_DIR="$HOME/.config/remote-cluster-agent"
VENV_DIR="$CONFIG_DIR/.venv"
echo "==> Setting up venv at $VENV_DIR..."
mkdir -p "$CONFIG_DIR"

# Detect old in-skill .venv and suggest cleanup
if [ -d "$SCRIPT_DIR/.venv" ]; then
    echo "    Note: Found old .venv at $SCRIPT_DIR/.venv"
    echo "    You can safely remove it: rm -rf $SCRIPT_DIR/.venv"
fi

# Track installed version to detect when deps need refresh
CURRENT_VERSION=$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "unknown")
INSTALLED_VERSION=$(cat "$VENV_DIR/.installed-version" 2>/dev/null || echo "")

if [ ! -d "$VENV_DIR" ] || [ "$CURRENT_VERSION" != "$INSTALLED_VERSION" ]; then
    cd "$SCRIPT_DIR"
    if [ ! -d "$VENV_DIR" ]; then
        uv venv "$VENV_DIR" --quiet 2>/dev/null || python3 -m venv "$VENV_DIR"
    fi
    uv pip install --quiet --python "$VENV_DIR/bin/python" -e . 2>/dev/null || "$VENV_DIR/bin/pip" install -q -e .
    echo "$CURRENT_VERSION" > "$VENV_DIR/.installed-version"
fi
PYTHON_PATH="$VENV_DIR/bin/python"
echo "    Python: $PYTHON_PATH"

# Return to caller's directory so mcp add registers to the correct project
cd "$CALLER_DIR"

# ---- 2. Clean up old per-node MCP servers ----
echo "==> Cleaning up old MCP servers..."
if [ "$CLIENT" = "claude" ]; then
    # Remove old per-node cluster-<name> servers (exact pattern match)
    for old_name in $(claude mcp list 2>/dev/null | grep -oE 'cluster-[a-z0-9_-]+:' | tr -d ':'); do
        echo "    Removing: $old_name"
        claude mcp remove "$old_name" -s local 2>/dev/null || true
    done
    # Also remove unified "cluster" if re-running setup
    claude mcp remove "cluster" -s local 2>/dev/null || true
elif [ "$CLIENT" = "codex" ]; then
    # Remove old per-node cluster-<name> servers if they exist
    for old_name in $(codex mcp list 2>/dev/null | grep -oE 'cluster-[a-z0-9_-]+' || true); do
        echo "    Removing: $old_name"
        codex mcp remove "$old_name" 2>/dev/null || true
    done
    codex mcp remove "cluster" 2>/dev/null || true
fi

# ---- 3. Register unified MCP server ----
echo "==> Registering MCP server: cluster (client: $CLIENT)"
if [ "$CLIENT" = "claude" ]; then
    claude mcp add "cluster" -s local \
        -e NODES="$NODES_JSON" \
        -e REMOTE_PROJECT_DIR="$REMOTE_DIR" \
        -e REMOTE_AGENT_PATH="$AGENT_PATH" \
        -- "$PYTHON_PATH" "$SCRIPT_DIR/mcp_remote_server.py"
else
    codex mcp add "cluster" \
        --env NODES="$NODES_JSON" \
        --env REMOTE_PROJECT_DIR="$REMOTE_DIR" \
        --env REMOTE_AGENT_PATH="$AGENT_PATH" \
        -- "$PYTHON_PATH" "$SCRIPT_DIR/mcp_remote_server.py"
fi

echo ""
echo "=== Setup complete ==="
echo "Client:      $CLIENT"
echo "MCP server:  cluster"
echo "Nodes:       $NODES_JSON"
echo "Remote dir:  $REMOTE_DIR"
echo "Agent path:  $AGENT_PATH"
echo ""
echo "Usage: mcp__cluster__remote_bash(node=\"<name>\", command=\"...\")"
echo ""
echo "Next step: Restart your agent to load the new MCP server."
echo "Agent deployment and configuration verification will run automatically after restart."
