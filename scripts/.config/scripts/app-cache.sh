#!/usr/bin/env bash
# app-cache.sh — shared .desktop app list builder.
# Formerly sourced by control-center.sh (deleted in the M5 center cutover;
# flex-launch resolves .desktop ids directly since the M2 launcher
# cutover) so both saw the same 90-app list. Kept intentionally: the flex
# center Launchers tab reuses the same scan semantics, and this file
# remains the bash reference for the row set. Rows are TAB-separated:
# name \t exec \t terminal.
APP_DIRS=(
    "/usr/share/applications"
    "$HOME/.local/share/applications"
)
APP_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/app-launcher.list"

rebuild_app_cache() {
    local -A seen=()
    local dir file id name exec term nodisplay hidden
    for dir in "${APP_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        for file in "$dir"/*.desktop; do
            [[ -f "$file" ]] || continue
            id=$(basename "$file")
            name=""; exec=""; term="false"; nodisplay="false"; hidden="false"
            while IFS='=' read -r key value; do
                case "$key" in
                    Name) [[ -z "$name" ]] && name="$value" ;;
                    Exec) [[ -z "$exec" ]] && exec="$value" ;;
                    Terminal) term="$value" ;;
                    NoDisplay) nodisplay="$value" ;;
                    Hidden) hidden="$value" ;;
                esac
            done < <(grep -E '^(Name|Exec|Terminal|NoDisplay|Hidden)=' "$file")
            [[ -z "$name" || -z "$exec" ]] && continue
            [[ "$nodisplay" == "true" || "$hidden" == "true" ]] && continue
            exec=$(echo "$exec" | sed -E 's/ %[A-Za-z]//g; s/^ *//; s/ *$//')
            [[ -z "$exec" ]] && continue
            seen["$id"]=$(printf '%s\t%s\t%s' "$name" "$exec" "$term")
        done
    done
    mkdir -p "$(dirname "$APP_CACHE")"
    : > "$APP_CACHE"
    for id in "${!seen[@]}"; do
        printf '%s\n' "${seen[$id]}" >> "$APP_CACHE"
    done
    sort -o "$APP_CACHE" "$APP_CACHE"
}

ensure_app_cache() {
    if [[ ! -f "$APP_CACHE" ]]; then
        rebuild_app_cache
    else
        local dir
        for dir in "${APP_DIRS[@]}"; do
            if [[ -d "$dir" ]] && [[ -n "$(find "$dir" -maxdepth 1 -name '*.desktop' -newer "$APP_CACHE" -print -quit 2>/dev/null)" ]]; then
                rebuild_app_cache
                break
            fi
        done
    fi
}

# launch_app_row "$exec" "$term" — detached launch surviving popup close.
# eval re-parses desktop-file quoting. hyprctl dispatch is unusable here:
# this Hyprland build lua-evaluates dispatch args and rejects exec syntax.
launch_app_row() {
    local app_exec="$1" app_term="$2"
    if [[ "$app_term" == "true" ]]; then
        # shellcheck disable=SC2086
        eval 'setsid -f kitty -e '"$app_exec"' </dev/null >/dev/null 2>&1'
    else
        # shellcheck disable=SC2086
        eval 'setsid -f '"$app_exec"' </dev/null >/dev/null 2>&1'
    fi
}
