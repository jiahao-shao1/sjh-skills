#!/usr/bin/env bash
# Create a new NotebookLM notebook and return its URL.
#
# Usage:
#   create_notebook.sh
#
# Output (stdout): notebook URL
# Example: https://notebooklm.google.com/notebook/0836657a-626c-4970-a71f-...
#
# Prerequisites:
#   - playwright-cli installed
#   - NotebookLM Google auth in the notebooklm skill browser profile

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/notebooklm_site_knowledge.sh"

PROFILE="${NOTEBOOKLM_PROFILE:-$HOME/.claude/skills/notebooklm/data/browser_state/browser_profile}"
if [[ ! -d "$PROFILE" ]]; then
    echo "Error: NotebookLM browser profile not found at $PROFILE" >&2
    exit 1
fi

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

OPEN_LOG="$WORKDIR/open.log"

cleanup() {
    playwright-cli close 2>/dev/null || true
    sleep 1
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

log() {
    echo "$*" >&2
}

wait_for_home_ready() {
    local attempt result current_url button_count

    for attempt in $(seq 1 20); do
        sleep 2
        result=$(playwright-cli eval '() => `${window.location.href}|${document.readyState}|${document.querySelectorAll("button").length}`' 2>&1 || true)
        current_url=$(echo "$result" | grep -oE 'https://[^| ]+' | head -1 || true)
        button_count=$(echo "$result" | grep -oE '[0-9]+' | tail -1 || true)

        if [[ "$current_url" == *"accounts.google.com"* ]]; then
            log "Error: NotebookLM requires Google login in profile $PROFILE"
            return 1
        fi

        if [[ "$current_url" == "https://notebooklm.google.com/"* ]] && [[ "${button_count:-0}" -ge 5 ]]; then
            return 0
        fi
    done

    log "Error: NotebookLM home page did not become ready"
    if [[ -s "$OPEN_LOG" ]]; then
        log "open log: $OPEN_LOG"
    fi
    return 1
}

log "Opening NotebookLM..."
playwright-cli open --browser=chrome --profile="$PROFILE" "https://notebooklm.google.com" >"$OPEN_LOG" 2>&1
wait_for_home_ready

rm -rf .playwright-cli/
playwright-cli snapshot >"$WORKDIR/snapshot.stdout" 2>"$WORKDIR/snapshot.stderr"
SNAP_FILE=$(ls -t .playwright-cli/*.yml 2>/dev/null | head -1)

if [[ -z "$SNAP_FILE" ]] || [[ $(wc -c < "$SNAP_FILE") -lt 5000 ]]; then
    log "Error: Page did not load properly"
    exit 1
fi

# Find the "新建笔记本" / "New notebook" button
BTN_REF=$(grep -E "$NOTEBOOKLM_NEW_NOTEBOOK_PATTERN" "$SNAP_FILE" \
    | grep -oE 'ref=e[0-9]+' | head -1 | sed 's/ref=//')

if [[ -z "$BTN_REF" ]]; then
    log "Error: Could not find 'New notebook' button"
    exit 1
fi

log "Creating notebook..."
playwright-cli click "$BTN_REF" >"$WORKDIR/click.stdout" 2>"$WORKDIR/click.stderr"

# Wait for redirect to new notebook URL
for i in $(seq 1 15); do
    sleep 2
    RESULT=$(playwright-cli eval '() => window.location.href' 2>&1)
    CURRENT_URL=$(echo "$RESULT" | grep -oE 'https://notebooklm\.google\.com/notebook/[a-f0-9-]+' | head -1)

    if [[ -n "$CURRENT_URL" ]]; then
        log "  ✓ Notebook created!"
        echo "$CURRENT_URL"
        exit 0
    fi
done

log "Error: Timed out waiting for notebook creation"
exit 1
