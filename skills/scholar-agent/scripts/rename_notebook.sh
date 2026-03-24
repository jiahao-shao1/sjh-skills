#!/usr/bin/env bash
# Rename a NotebookLM notebook by editing the title field in-page.
#
# Usage:
#   rename_notebook.sh <notebook_url> <new_name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/notebooklm_site_knowledge.sh"
source "$SCRIPT_DIR/notebooklm_flow.sh"

NOTEBOOK_URL="${1:?Usage: rename_notebook.sh <notebook_url> <new_name>}"
NEW_NAME="${2:?Usage: rename_notebook.sh <notebook_url> <new_name>}"

PROFILE="${NOTEBOOKLM_PROFILE:-$HOME/.claude/skills/notebooklm/data/browser_state/browser_profile}"
if [[ ! -d "$PROFILE" ]]; then
    echo "Error: NotebookLM browser profile not found at $PROFILE" >&2
    exit 1
fi

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

rename_eval() {
    local escaped_name
    escaped_name=$(printf '%s' "$NEW_NAME" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
    playwright-cli eval "$(cat <<EOF
() => {
  const el = document.querySelector('editable-project-title input');
  if (!el) return 'missing';
  el.focus();
  el.value = ${escaped_name};
  el.dispatchEvent(new Event('input', { bubbles: true }));
  el.dispatchEvent(new Event('change', { bubbles: true }));
  el.blur();
  return document.querySelector('editable-project-title input')?.value || '';
}
EOF
)"
}

notebooklm_log "Opening notebook..."
playwright-cli open --browser=chrome --profile="$PROFILE" "$NOTEBOOK_URL" >"$OPEN_LOG" 2>&1
notebooklm_wait_for_notebook_ready

for _ in $(seq 1 10); do
    result=$(rename_eval 2>&1 || true)
    value=$(printf '%s\n' "$result" | awk -F'"' '/^".*"$/ {print $2; exit}')
    if [[ "$value" == "$NEW_NAME" ]]; then
        sleep 1
        title_check=$(playwright-cli eval '() => document.querySelector("editable-project-title input")?.value || ""' 2>&1 || true)
        title_value=$(printf '%s\n' "$title_check" | awk -F'"' '/^".*"$/ {print $2; exit}')
        if [[ "$title_value" == "$NEW_NAME" ]]; then
            notebooklm_log "  ✓ Notebook renamed to $NEW_NAME"
            echo "$NOTEBOOK_URL"
            exit 0
        fi
    fi
    sleep 1
done

notebooklm_log "Error: Failed to rename notebook to $NEW_NAME"
exit 1
