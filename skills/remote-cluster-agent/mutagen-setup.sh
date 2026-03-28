#!/bin/bash
# mutagen-setup.sh — Install mutagen file sync over SSH
#
# Some SSH proxies / jump hosts have issues that break mutagen out of the box:
#   1. Connections don't close after commands finish (SCP hangs)
#   2. stderr is merged into stdout (corrupts mutagen's binary protocol)
#
# This script works around both by:
#   - Uploading the agent binary via stdin pipe (bypasses SCP)
#   - Creating a wrapper that redirects stderr to a log file
#
# Usage:
#   bash mutagen-setup.sh <ssh_host> <local_dir> <remote_dir> [session_name] [ignores...]
#
# Examples:
#   bash mutagen-setup.sh gpu-node ~/repo/my_project /home/user/my_project
#   bash mutagen-setup.sh gpu-node ~/repo/my_project /home/user/my_project my-sync output wandb data
#
# Prerequisites:
#   1. mutagen installed (brew install mutagen)
#   2. SSH access to cluster established
#   3. SSH host configured in ~/.ssh/config
set -euo pipefail

# ---- Parse arguments ----
SSH_HOST="${1:-}"
LOCAL_DIR="${2:-}"
REMOTE_DIR="${3:-}"
SESSION_NAME="${4:-}"
shift 4 2>/dev/null || true
EXTRA_IGNORES=("$@")

if [ -z "$SSH_HOST" ] || [ -z "$LOCAL_DIR" ] || [ -z "$REMOTE_DIR" ]; then
    cat <<'USAGE'
Usage: bash mutagen-setup.sh <ssh_host> <local_dir> <remote_dir> [session_name] [ignores...]

  ssh_host:      SSH host alias (from ~/.ssh/config), e.g. "gpu-node"
  local_dir:     Local project directory, e.g. "~/repo/my_project"
  remote_dir:    Remote project directory, e.g. "/home/user/my_project"
  session_name:  (Optional) Mutagen session name. Default: directory basename
  ignores:       (Optional) Extra directories/patterns to ignore

Examples:
  bash mutagen-setup.sh gpu-node ~/repo/my_project /home/user/my_project
  bash mutagen-setup.sh gpu-node ~/repo/my_project /home/user/my_project my-sync output wandb data

Note: If remote_dir is a symlink, use the resolved path (run: ssh <host> "readlink -f <path>")
USAGE
    exit 1
fi

# Expand ~ in LOCAL_DIR
LOCAL_DIR="${LOCAL_DIR/#\~/$HOME}"

# Default session name to directory basename
if [ -z "$SESSION_NAME" ]; then
    SESSION_NAME="$(basename "$LOCAL_DIR")"
fi

MUTAGEN_VERSION=$(mutagen version)
AGENT_DIR=".mutagen/agents/${MUTAGEN_VERSION}"
AGENT_PATH="${AGENT_DIR}/mutagen-agent"

echo "==> Mutagen version: ${MUTAGEN_VERSION}"
echo "    SSH host:        ${SSH_HOST}"
echo "    Local dir:       ${LOCAL_DIR}"
echo "    Remote dir:      ${REMOTE_DIR}"
echo "    Session name:    ${SESSION_NAME}"
echo ""

# ---- Helper: run command on remote with auto-kill ----
# Some SSH proxies don't close connections, so we kill SSH after the command finishes.
# The sentinel pattern (___SENTINEL_DONE___) tells us when output is complete.
remote_exec() {
    local cmd="$1"
    local timeout="${2:-10}"
    local output
    output=$(
        ssh "$SSH_HOST" "${cmd}; echo ___SENTINEL_DONE___" &
        local pid=$!
        # Read until sentinel or timeout
        local elapsed=0
        while kill -0 $pid 2>/dev/null && [ $elapsed -lt $timeout ]; do
            sleep 1
            elapsed=$((elapsed + 1))
        done
        kill $pid 2>/dev/null || true
        wait $pid 2>/dev/null || true
    )
    # Strip sentinel from output
    echo "$output" | sed '/___SENTINEL_DONE___/d'
}

# ---- Step 1: Check if agent is already installed ----
echo "==> Checking remote agent..."
REMOTE_CHECK=$(
    ssh "$SSH_HOST" "test -x ~/${AGENT_PATH} && ~/${AGENT_PATH} version 2>/dev/null; echo ___SENTINEL_DONE___" &
    CHECK_PID=$!
    sleep 8
    kill $CHECK_PID 2>/dev/null || true
    wait $CHECK_PID 2>/dev/null || true
)

if echo "$REMOTE_CHECK" | grep -q "${MUTAGEN_VERSION}"; then
    echo "    Agent ${MUTAGEN_VERSION} already installed."
else
    echo "    Agent not found or version mismatch. Installing..."

    # ---- Step 2: Extract agent binary from local bundle ----
    echo "==> Extracting agent binary..."

    # Find the bundle
    BUNDLE_PATH=""
    BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
    CANDIDATE="${BREW_PREFIX}/Cellar/mutagen/${MUTAGEN_VERSION}/libexec/mutagen-agents.tar.gz"
    if [ -f "$CANDIDATE" ]; then
        BUNDLE_PATH="$CANDIDATE"
    fi

    # Also check common locations
    for dir in "${BREW_PREFIX}/opt/mutagen/libexec" "/usr/local/Cellar/mutagen/${MUTAGEN_VERSION}/libexec"; do
        if [ -z "$BUNDLE_PATH" ] && [ -f "${dir}/mutagen-agents.tar.gz" ]; then
            BUNDLE_PATH="${dir}/mutagen-agents.tar.gz"
        fi
    done

    if [ -z "$BUNDLE_PATH" ]; then
        echo "ERROR: Cannot find mutagen-agents.tar.gz bundle."
        echo "       Expected at: ${CANDIDATE}"
        echo "       Please set MUTAGEN_AGENT_BUNDLE env var to the bundle path."
        exit 1
    fi

    echo "    Bundle: ${BUNDLE_PATH}"

    # Detect remote architecture
    echo "==> Detecting remote architecture..."
    REMOTE_ARCH=$(
        ssh "$SSH_HOST" "uname -m; echo ___SENTINEL_DONE___" &
        ARCH_PID=$!
        sleep 5
        kill $ARCH_PID 2>/dev/null || true
        wait $ARCH_PID 2>/dev/null || true
    )
    REMOTE_ARCH=$(echo "$REMOTE_ARCH" | head -1 | tr -d '[:space:]')

    case "$REMOTE_ARCH" in
        x86_64|amd64) AGENT_PLATFORM="linux_amd64" ;;
        aarch64|arm64) AGENT_PLATFORM="linux_arm64" ;;
        *) echo "ERROR: Unsupported architecture: ${REMOTE_ARCH}"; exit 1 ;;
    esac
    echo "    Platform: ${AGENT_PLATFORM}"

    # Extract
    EXTRACT_DIR=$(mktemp -d)
    tar xzf "$BUNDLE_PATH" -C "$EXTRACT_DIR"
    AGENT_BINARY="${EXTRACT_DIR}/${AGENT_PLATFORM}"

    if [ ! -f "$AGENT_BINARY" ]; then
        echo "ERROR: Agent binary not found for platform ${AGENT_PLATFORM}"
        rm -rf "$EXTRACT_DIR"
        exit 1
    fi

    LOCAL_MD5=$(md5 -q "$AGENT_BINARY" 2>/dev/null || md5sum "$AGENT_BINARY" | cut -d' ' -f1)
    echo "    Local checksum: ${LOCAL_MD5}"

    # ---- Step 3: Upload via stdin pipe ----
    echo "==> Uploading agent binary (~$(du -h "$AGENT_BINARY" | cut -f1)B)..."
    echo "    This may take 30-60s through SSH proxy..."

    cat "$AGENT_BINARY" | ssh "$SSH_HOST" "cat > /tmp/.mutagen-agent-upload" &
    UPLOAD_PID=$!

    # Wait for upload (check file size periodically)
    EXPECTED_SIZE=$(wc -c < "$AGENT_BINARY" | tr -d ' ')
    for i in $(seq 1 24); do
        sleep 5
        if ! kill -0 $UPLOAD_PID 2>/dev/null; then
            break
        fi
        # Check remote file size
        REMOTE_SIZE=$(
            ssh "$SSH_HOST" "wc -c < /tmp/.mutagen-agent-upload 2>/dev/null || echo 0; echo ___SENTINEL_DONE___" &
            SIZE_PID=$!
            sleep 3
            kill $SIZE_PID 2>/dev/null || true
            wait $SIZE_PID 2>/dev/null || true
        )
        REMOTE_SIZE=$(echo "$REMOTE_SIZE" | head -1 | tr -d '[:space:]')
        if [ "$REMOTE_SIZE" = "$EXPECTED_SIZE" ]; then
            echo "    Upload complete."
            kill $UPLOAD_PID 2>/dev/null || true
            break
        fi
        echo "    Progress: ${REMOTE_SIZE}/${EXPECTED_SIZE} bytes..."
    done
    kill $UPLOAD_PID 2>/dev/null || true
    wait $UPLOAD_PID 2>/dev/null || true

    # Verify checksum
    echo "==> Verifying upload..."
    REMOTE_MD5=$(
        ssh "$SSH_HOST" "md5sum /tmp/.mutagen-agent-upload 2>/dev/null; echo ___SENTINEL_DONE___" &
        MD5_PID=$!
        sleep 5
        kill $MD5_PID 2>/dev/null || true
        wait $MD5_PID 2>/dev/null || true
    )
    REMOTE_MD5=$(echo "$REMOTE_MD5" | head -1 | awk '{print $1}')

    if [ "$LOCAL_MD5" != "$REMOTE_MD5" ]; then
        echo "ERROR: Checksum mismatch!"
        echo "  Local:  ${LOCAL_MD5}"
        echo "  Remote: ${REMOTE_MD5}"
        echo "  Upload may have been incomplete. Try running the script again."
        rm -rf "$EXTRACT_DIR"
        exit 1
    fi
    echo "    Checksum verified: ${REMOTE_MD5}"

    # ---- Step 4: Install agent binary ----
    echo "==> Installing agent to ~/${AGENT_DIR}/..."
    ssh "$SSH_HOST" "mkdir -p ~/${AGENT_DIR} && mv /tmp/.mutagen-agent-upload ~/${AGENT_PATH} && chmod +x ~/${AGENT_PATH} && echo AGENT_INSTALLED" &
    INSTALL_PID=$!
    sleep 8
    kill $INSTALL_PID 2>/dev/null || true
    wait $INSTALL_PID 2>/dev/null || true

    rm -rf "$EXTRACT_DIR"
fi

# ---- Step 5: Create stderr wrapper ----
# Some SSH proxies merge stderr into stdout, which corrupts mutagen's binary protocol.
# The wrapper redirects agent stderr to a log file.
echo "==> Installing stderr wrapper..."

ssh "$SSH_HOST" "cd ~/${AGENT_DIR} && \
    if [ ! -f mutagen-agent-real ]; then mv mutagen-agent mutagen-agent-real; fi && \
    printf '%s\n' '#!/bin/bash' 'exec ~/${AGENT_DIR}/mutagen-agent-real \"\$@\" 2>/tmp/mutagen-agent.log' > mutagen-agent && \
    chmod +x mutagen-agent && \
    echo WRAPPER_OK" &
WRAP_PID=$!
sleep 8
kill $WRAP_PID 2>/dev/null || true
wait $WRAP_PID 2>/dev/null || true

# ---- Step 6: Create mutagen sync session ----
echo "==> Creating mutagen sync session: ${SESSION_NAME}"

# Check if session already exists
if mutagen sync list 2>/dev/null | grep -q "Name: ${SESSION_NAME}$"; then
    echo "    Session '${SESSION_NAME}' already exists. Terminating old session..."
    mutagen sync terminate "$SESSION_NAME" 2>/dev/null || true
fi

# Build ignore flags
# Note: .git is NOT ignored — in one-way-replica mode, syncing .git keeps the
# cluster-side repo in sync with local (clean git status), with no conflict risk.
IGNORE_FLAGS=(
    --ignore="__pycache__"
    --ignore="*.pyc"
    --ignore="*.pt"
    --ignore="*.pth"
    --ignore="*.bin"
    --ignore="*.safetensors"
    --ignore="*.ckpt"
    --ignore=".venv"
    --ignore=".DS_Store"
    --ignore="*.egg-info"
    --ignore="node_modules"
)

for pattern in "${EXTRA_IGNORES[@]}"; do
    IGNORE_FLAGS+=(--ignore="$pattern")
done

mutagen sync create \
    --name="$SESSION_NAME" \
    --sync-mode=one-way-replica \
    "${IGNORE_FLAGS[@]}" \
    "$LOCAL_DIR" \
    "${SSH_HOST}:${REMOTE_DIR}"

echo ""
echo "=== Setup complete ==="
echo ""
echo "Session:     ${SESSION_NAME}"
echo "Local:       ${LOCAL_DIR}"
echo "Remote:      ${SSH_HOST}:${REMOTE_DIR}"
echo ""
echo "Useful commands:"
echo "  mutagen sync list                    # Check sync status"
echo "  mutagen sync monitor ${SESSION_NAME}  # Watch sync in real-time"
echo "  mutagen sync pause ${SESSION_NAME}    # Pause syncing"
echo "  mutagen sync resume ${SESSION_NAME}   # Resume syncing"
echo "  mutagen sync terminate ${SESSION_NAME} # Remove session"
