#!/usr/bin/env bash
# Shared NotebookLM browser flow helpers.
#
# This file separates "how to detect the current UI state" from individual
# scripts. Callers should source `notebooklm_site_knowledge.sh` first.

notebooklm_log() {
    echo "$*" >&2
}

notebooklm_take_snapshot() {
    rm -rf .playwright-cli/
    playwright-cli snapshot >"$WORKDIR/snapshot.stdout" 2>"$WORKDIR/snapshot.stderr" || return 1
    LAST_SNAPSHOT=$(ls -t .playwright-cli/*.yml 2>/dev/null | head -1 || true)
    [[ -n "${LAST_SNAPSHOT:-}" && -s "$LAST_SNAPSHOT" ]]
}

notebooklm_find_ref_in_snapshot() {
    local pattern="${1:?pattern required}"
    if [[ -z "${LAST_SNAPSHOT:-}" || ! -f "$LAST_SNAPSHOT" ]]; then
        return 1
    fi

    grep -Ei "$pattern" "$LAST_SNAPSHOT" \
        | grep -oE 'ref=e[0-9]+' \
        | head -1 \
        | sed 's/ref=//'
}

notebooklm_wait_for_ref() {
    local description="${1:?description required}"
    local pattern="${2:?pattern required}"
    local attempt ref

    for attempt in $(seq 1 12); do
        sleep 1
        if notebooklm_take_snapshot; then
            ref=$(notebooklm_find_ref_in_snapshot "$pattern" || true)
            if [[ -n "$ref" ]]; then
                echo "$ref"
                return 0
            fi
        fi
    done

    notebooklm_log "Error: Could not find $description"
    if [[ -n "${LAST_SNAPSHOT:-}" ]]; then
        notebooklm_log "Last snapshot: $LAST_SNAPSHOT"
    fi
    return 1
}

notebooklm_click_ref() {
    local ref="${1:?ref required}"
    playwright-cli click "$ref" >"$WORKDIR/click.stdout" 2>"$WORKDIR/click.stderr"
}

notebooklm_wait_for_notebook_ready() {
    local attempt result current_url button_count

    for attempt in $(seq 1 20); do
        sleep 2
        result=$(playwright-cli eval '() => `${window.location.href}|${document.readyState}|${document.querySelectorAll("button").length}`' 2>&1 || true)
        current_url=$(echo "$result" | grep -oE 'https://[^| ]+' | head -1 || true)
        button_count=$(echo "$result" | grep -oE '[0-9]+' | tail -1 || true)

        if [[ "$current_url" == *"accounts.google.com"* ]]; then
            notebooklm_log "Error: NotebookLM requires Google login in profile $PROFILE"
            return 1
        fi

        if [[ "$current_url" == https://notebooklm.google.com/notebook/* ]] && [[ "${button_count:-0}" -ge 3 ]]; then
            return 0
        fi
    done

    notebooklm_log "Error: Notebook page did not become ready"
    if [[ -s "${OPEN_LOG:-}" ]]; then
        notebooklm_log "open log: $OPEN_LOG"
    fi
    return 1
}

notebooklm_detect_source_entry_strategy() {
    local url_input website_btn add_btn

    url_input=$(notebooklm_find_ref_in_snapshot "$NOTEBOOKLM_URL_INPUT_PATTERN" || true)
    if [[ -n "$url_input" ]]; then
        echo "url_input_ready"
        return 0
    fi

    website_btn=$(notebooklm_find_ref_in_snapshot "$NOTEBOOKLM_WEBSITE_PATTERN" || true)
    if [[ -n "$website_btn" ]]; then
        echo "open_website_form"
        return 0
    fi

    add_btn=$(notebooklm_find_ref_in_snapshot "$NOTEBOOKLM_ADD_SOURCE_PATTERN" || true)
    if [[ -n "$add_btn" ]]; then
        echo "open_source_dialog"
        return 0
    fi

    echo "unknown"
    return 1
}

notebooklm_apply_source_entry_strategy() {
    local strategy="${1:?strategy required}"
    local ref=""

    case "$strategy" in
        url_input_ready)
            return 0
            ;;
        open_website_form)
            ref=$(notebooklm_find_ref_in_snapshot "$NOTEBOOKLM_WEBSITE_PATTERN" || true)
            if [[ -n "$ref" ]]; then
                notebooklm_log "Strategy: open_website_form"
                notebooklm_click_ref "$ref" || true
                return 0
            fi
            ;;
        open_source_dialog)
            ref=$(notebooklm_find_ref_in_snapshot "$NOTEBOOKLM_ADD_SOURCE_PATTERN" || true)
            if [[ -n "$ref" ]]; then
                notebooklm_log "Strategy: open_source_dialog"
                notebooklm_click_ref "$ref" || true
                return 0
            fi
            ;;
    esac

    return 1
}

notebooklm_ensure_source_entry_ready() {
    local attempt strategy

    for attempt in $(seq 1 12); do
        if notebooklm_take_snapshot; then
            strategy=$(notebooklm_detect_source_entry_strategy || true)
            case "$strategy" in
                url_input_ready)
                    notebooklm_log "Strategy: url_input_ready"
                    return 0
                    ;;
                open_website_form|open_source_dialog)
                    notebooklm_apply_source_entry_strategy "$strategy"
                    sleep 1
                    continue
                    ;;
            esac
        fi
        sleep 1
    done

    notebooklm_log "Error: Could not reach NotebookLM source entry UI"
    if [[ -n "${LAST_SNAPSHOT:-}" ]]; then
        notebooklm_log "Last snapshot: $LAST_SNAPSHOT"
    fi
    return 1
}
