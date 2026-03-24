#!/usr/bin/env bash
# Add arXiv/web URLs to a NotebookLM notebook as sources.
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
# Prerequisites:
#   - playwright-cli installed
#   - NotebookLM Google auth in the notebooklm skill browser profile

set -eo pipefail

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

# playwright-cli writes snapshots to $PWD/.playwright-cli/
# Use a temp dir to avoid polluting user's cwd
WORKDIR=$(mktemp -d)
cd "$WORKDIR"

cleanup() {
    playwright-cli close 2>/dev/null || true
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "Opening notebook..." >&2
playwright-cli open --browser=chrome --profile="$PROFILE" "$NOTEBOOK_URL" >/dev/null 2>&1
sleep 5

ADDED=0
TOTAL=${#URLS[@]}

for url in "${URLS[@]}"; do
    echo "[$((ADDED + 1))/$TOTAL] Adding: $url" >&2

    # Take snapshot to get current DOM refs
    playwright-cli snapshot >/dev/null 2>&1
    SNAP_FILE=$(ls -t .playwright-cli/*.yml 2>/dev/null | head -1)

    if [[ -z "$SNAP_FILE" ]]; then
        echo "  ✗ Could not get page snapshot" >&2
        continue
    fi

    # Find the search textbox ref (NotebookLM's source search box)
    SEARCH_REF=$(grep -E 'textbox.*查询.*发现|textbox.*搜索|textbox.*[Ss]earch.*source' "$SNAP_FILE" \
        | grep -oE 'ref=e[0-9]+' | head -1 | sed 's/ref=//')

    if [[ -z "$SEARCH_REF" ]]; then
        echo "  ✗ Search box not found" >&2
        continue
    fi

    # Fill URL and press Enter to submit
    playwright-cli fill "$SEARCH_REF" "$url" >/dev/null 2>&1
    sleep 1
    playwright-cli press Enter >/dev/null 2>&1

    ADDED=$((ADDED + 1))
    echo "  ✓ Submitted" >&2

    # Wait for NotebookLM to process the source
    sleep 4
done

echo "" >&2
echo "Done: $ADDED/$TOTAL sources added." >&2

# JSON summary to stdout
echo "{\"added\": $ADDED, \"total\": $TOTAL}"
