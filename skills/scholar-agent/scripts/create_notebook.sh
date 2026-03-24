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

set -eo pipefail

PROFILE="${NOTEBOOKLM_PROFILE:-$HOME/.claude/skills/notebooklm/data/browser_state/browser_profile}"
if [[ ! -d "$PROFILE" ]]; then
    echo "Error: NotebookLM browser profile not found at $PROFILE" >&2
    exit 1
fi

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

cleanup() {
    playwright-cli close 2>/dev/null || true
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "Opening NotebookLM..." >&2
playwright-cli open --browser=chrome --profile="$PROFILE" "https://notebooklm.google.com" >/dev/null 2>&1

# Wait for SPA to render (poll button count via eval)
for attempt in $(seq 1 15); do
    sleep 2
    BTN_COUNT=$(playwright-cli eval '() => document.querySelectorAll("button").length' 2>&1 \
        | grep -oE '[0-9]+' | tail -1)
    if [[ "${BTN_COUNT:-0}" -gt 5 ]]; then
        break
    fi
done

# Take snapshot after page is loaded
rm -rf .playwright-cli/
playwright-cli snapshot >/dev/null 2>&1
SNAP_FILE=$(ls -t .playwright-cli/*.yml 2>/dev/null | head -1)

if [[ -z "$SNAP_FILE" ]] || [[ $(wc -c < "$SNAP_FILE") -lt 5000 ]]; then
    echo "Error: Page did not load properly" >&2
    exit 1
fi

# Find the "新建笔记本" / "New notebook" button
BTN_REF=$(grep -E 'button.*(新建笔记本|新建|New notebook|Create new)' "$SNAP_FILE" \
    | grep -oE 'ref=e[0-9]+' | head -1 | sed 's/ref=//')

if [[ -z "$BTN_REF" ]]; then
    echo "Error: Could not find 'New notebook' button" >&2
    exit 1
fi

echo "Creating notebook..." >&2
playwright-cli click "$BTN_REF" >/dev/null 2>&1

# Wait for redirect to new notebook URL
for i in $(seq 1 15); do
    sleep 2
    RESULT=$(playwright-cli eval '() => window.location.href' 2>&1)
    CURRENT_URL=$(echo "$RESULT" | grep -oE 'https://notebooklm\.google\.com/notebook/[a-f0-9-]+' | head -1)

    if [[ -n "$CURRENT_URL" ]]; then
        echo "  ✓ Notebook created!" >&2
        echo "$CURRENT_URL"
        exit 0
    fi
done

echo "Error: Timed out waiting for notebook creation" >&2
exit 1
