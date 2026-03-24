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

TOTAL=${#URLS[@]}
# Join all URLs with spaces
URL_STRING="${URLS[*]}"

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

# Click "添加来源" button
rm -rf .playwright-cli/
playwright-cli snapshot >/dev/null 2>&1
SNAP_FILE=$(ls -t .playwright-cli/*.yml 2>/dev/null | head -1)

if [[ -z "$SNAP_FILE" ]]; then
    echo "Error: Could not get page snapshot" >&2
    exit 1
fi

ADD_BTN=$(grep -E 'button.*添加来源|button.*Add source' "$SNAP_FILE" \
    | grep -oE 'ref=e[0-9]+' | head -1 | sed 's/ref=//')

if [[ -z "$ADD_BTN" ]]; then
    echo "Error: Could not find '添加来源' button" >&2
    exit 1
fi

echo "Opening source dialog..." >&2
playwright-cli click "$ADD_BTN" >/dev/null 2>&1
sleep 2

# Click "网站" button in the dialog
rm -rf .playwright-cli/
playwright-cli snapshot >/dev/null 2>&1
SNAP_FILE=$(ls -t .playwright-cli/*.yml 2>/dev/null | head -1)

WEBSITE_BTN=$(grep -E 'button.*(网站|Website)' "$SNAP_FILE" \
    | grep -oE 'ref=e[0-9]+' | head -1 | sed 's/ref=//')

if [[ -z "$WEBSITE_BTN" ]]; then
    echo "Error: Could not find '网站' button in dialog" >&2
    exit 1
fi

playwright-cli click "$WEBSITE_BTN" >/dev/null 2>&1
sleep 1

# Find URL input and fill all URLs at once (space-separated)
rm -rf .playwright-cli/
playwright-cli snapshot >/dev/null 2>&1
SNAP_FILE=$(ls -t .playwright-cli/*.yml 2>/dev/null | head -1)

URL_INPUT=$(grep -E 'textbox.*(输入网址|Enter URL|粘贴|paste)' "$SNAP_FILE" \
    | grep -oE 'ref=e[0-9]+' | head -1 | sed 's/ref=//')

if [[ -z "$URL_INPUT" ]]; then
    echo "Error: Could not find URL input field" >&2
    exit 1
fi

echo "Adding $TOTAL URLs..." >&2
playwright-cli fill "$URL_INPUT" "$URL_STRING" >/dev/null 2>&1
sleep 1

# Click "插入" / "Insert" button
rm -rf .playwright-cli/
playwright-cli snapshot >/dev/null 2>&1
SNAP_FILE=$(ls -t .playwright-cli/*.yml 2>/dev/null | head -1)

INSERT_BTN=$(grep -E 'button.*(插入|Insert)' "$SNAP_FILE" \
    | grep -v 'disabled' \
    | grep -oE 'ref=e[0-9]+' | head -1 | sed 's/ref=//')

if [[ -z "$INSERT_BTN" ]]; then
    echo "Error: '插入' button not found or still disabled" >&2
    exit 1
fi

playwright-cli click "$INSERT_BTN" >/dev/null 2>&1
echo "  ✓ Submitted $TOTAL sources" >&2

# Wait for processing
sleep 5

echo "" >&2
echo "Done: $TOTAL sources added." >&2

# JSON summary to stdout
echo "{\"added\": $TOTAL, \"total\": $TOTAL}"
