#!/usr/bin/env bash

STATE_DIR="$HOME/.local/state/yoake"
VERSION_FILE="$STATE_DIR/version"
DEFAULT_FALLBACK_VERSION="2.0.0"

get_telemetry_id() {
    if [ -f "$VERSION_FILE" ]; then
        local id
        id=$(awk -F= '/^TELEMETRY_ID=/{gsub(/"/, "", $2); print $2}' "$VERSION_FILE")
        if [ -n "$id" ]; then
            echo "$id"
            return
        fi
    fi

    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || head -c 16 /dev/urandom | od -An -t x | tr -d ' '
    fi
}

get_installed_commit() {
    if [ -f "$VERSION_FILE" ]; then
        awk -F= '/^YOAKE_COMMIT=/{gsub(/"/, "", $2); print $2}' "$VERSION_FILE"
    fi
}

get_target_version() {
    local repo_root="$1"
    local repo_slug="${2:-"${REPO_SLUG:-"ilyamiro/serpantinum"}"}"
    local target_ver=""

    if [ -f "$repo_root/version.txt" ]; then
        target_ver=$(cat "$repo_root/version.txt" 2>/dev/null | xargs)
    fi

    if [[ -z "$target_ver" || "$target_ver" == "null" ]]; then
        if command -v curl &>/dev/null; then
            target_ver=$(curl -s "https://raw.githubusercontent.com/${repo_slug}/HEAD/version.txt" 2>/dev/null | xargs)
        fi
    fi

    if [[ -z "$target_ver" || "$target_ver" == "null" ]]; then
        target_ver="$DEFAULT_FALLBACK_VERSION"
    fi

    echo "$target_ver"
}

get_target_commit() {
    local repo_root="$1"
    local repo_slug="${2:-"${REPO_SLUG:-"ilyamiro/serpantinum"}"}"
    local target_commit=""

    if [ -d "$repo_root/.git" ] && command -v git &>/dev/null; then
        target_commit=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || true)
    fi

    if [[ -z "$target_commit" || "$target_commit" == "null" ]]; then
        if command -v curl &>/dev/null && command -v jq &>/dev/null; then
            target_commit=$(curl -s "https://api.github.com/repos/${repo_slug}/commits/HEAD" 2>/dev/null | jq -r '.sha[:7] // empty')
        fi
    fi

    if [[ -z "$target_commit" || "$target_commit" == "null" ]]; then
        target_commit="unknown"
    fi

    echo "$target_commit"
}

write_version_state() {
    local version="${1:-"$DEFAULT_FALLBACK_VERSION"}"
    local commit="${2:-"unknown"}"
    local tel_id="$3"
    local tel_enabled="${4:-true}"
    local compositors="$5"

    if [[ -z "$commit" || "$commit" == "null" ]]; then
        commit="unknown"
    fi

    if [[ -z "$tel_id" ]]; then
        tel_id=$(get_telemetry_id)
    fi

    mkdir -p "$STATE_DIR"
    local tmp_file="${VERSION_FILE}.tmp.$$"
    cat <<EOF > "$tmp_file"
YOAKE_VERSION="$version"
YOAKE_COMMIT="$commit"
TELEMETRY_ID="$tel_id"
ENABLE_TELEMETRY="$tel_enabled"
SELECTED_COMPOSITORS="$compositors"
EOF
    mv -f "$tmp_file" "$VERSION_FILE"
}
