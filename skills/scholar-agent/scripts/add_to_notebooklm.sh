#!/usr/bin/env bash
# Add arXiv/web URLs to a NotebookLM notebook as sources (batch mode).
#
# Usage:
#   add_to_notebooklm.sh <notebook_url> <url1> [url2] ...
#
# Example:
#   add_to_notebooklm.sh \
#     "https://notebooklm.google.com/notebook/d861e423..." \
#     "https://arxiv.org/abs/2603.19685" \
#     "https://arxiv.org/abs/2603.20003"
#
# All URLs are submitted at once via NotebookLM's "添加来源 → 网站" dialog
# (space-separated). Much faster than adding one at a time.
#
# Prerequisites:
#   - playwright-cli installed
#   - NotebookLM Google auth in the notebooklm skill browser profile

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/notebooklm_site_knowledge.sh"
source "$SCRIPT_DIR/notebooklm_flow.sh"

NOTEBOOK_URL="${1:?Usage: add_to_notebooklm.sh <notebook_url> <url1> [url2] ...}"
shift
URLS=("$@")

if [[ ${#URLS[@]} -eq 0 ]]; then
    echo "Error: No URLs provided." >&2
    exit 1
fi

PROFILE="${NOTEBOOKLM_PROFILE:-$HOME/.claude/skills/notebooklm/data/browser_state/browser_profile}"
if [[ ! -d "$PROFILE" ]]; then
    echo "Error: NotebookLM browser profile not found at $PROFILE" >&2
    exit 1
fi

TOTAL=${#URLS[@]}
URL_STRING="${URLS[*]}"

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

OPEN_LOG="$WORKDIR/open.log"
LAST_SNAPSHOT=""

cleanup() {
    playwright-cli close 2>/dev/null || true
    sleep 1
    rm -rf "$WORKDIR"
}
trap cleanup EXIT
log() {
    notebooklm_log "$*"
}

log "Opening notebook..."
playwright-cli open --browser=chrome --profile="$PROFILE" "$NOTEBOOK_URL" >"$OPEN_LOG" 2>&1
notebooklm_wait_for_notebook_ready

notebooklm_ensure_source_entry_ready

URL_INPUT=$(notebooklm_wait_for_ref "URL input field" "$NOTEBOOKLM_URL_INPUT_PATTERN")

if [[ -z "$URL_INPUT" ]]; then
    log "Error: Could not find URL input field"
    if [[ -n "${LAST_SNAPSHOT:-}" ]]; then
        log "Last snapshot: $LAST_SNAPSHOT"
    fi
    exit 1
fi

log "Adding $TOTAL URLs..."
playwright-cli fill "$URL_INPUT" "$URL_STRING" >"$WORKDIR/fill.stdout" 2>"$WORKDIR/fill.stderr"
sleep 1

INSERT_BTN=""
for _ in $(seq 1 10); do
    if notebooklm_take_snapshot; then
        INSERT_BTN=$(notebooklm_find_ref_in_snapshot "$NOTEBOOKLM_INSERT_PATTERN" || true)
        if [[ -n "$INSERT_BTN" ]] && notebooklm_click_ref "$INSERT_BTN"; then
            break
        fi
    fi
    INSERT_BTN=""
    sleep 1
done

if [[ -z "$INSERT_BTN" ]]; then
    log "Error: Could not click '插入 / Insert' button"
    if [[ -n "${LAST_SNAPSHOT:-}" ]]; then
        log "Last snapshot: $LAST_SNAPSHOT"
    fi
    exit 1
fi

log "  ✓ Submitted $TOTAL sources"

# Give NotebookLM a moment to enqueue source processing before releasing the profile.
sleep 5

log ""
log "Done: $TOTAL sources added."

# JSON summary to stdout
echo "{\"added\": $TOTAL, \"total\": $TOTAL}"
