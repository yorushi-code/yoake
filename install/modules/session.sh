#!/usr/bin/env bash
# What makes a fresh install usable without manual steps, beyond upstream's
# deploy: the equaliser's PipeWire config, the terminal's colours and prompt,
# and the user directories. Runs on install and reinstall; an update leaves
# the user's files alone. Anything replaced is backed up next to itself.

# Explicit return: install.sh runs under set -e, and a bare `[ -f ] && cp`
# would end the install whenever there is nothing to back up.
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp -a "$file" "$file.bak.$(date +%Y%m%d_%H%M%S)"
    fi
    return 0
}

# Adds a marked block to a shell rc file unless the rc already runs starship.
hook_starship() {
    local rc="$1" line="$2"
    [ -f "$rc" ] || return 0
    grep -q 'starship init' "$rc" && return 0
    printf '\n# Added by the yoake installer: terminal prompt.\n%s\n' "$line" >> "$rc"
}

setup_session_extras() {
    local project_root="$1"
    local install_state="$2"
    local is_reinstall="$3"
    local deployed="$HOME/.local/share/yoake"

    if [[ "$install_state" == "current" && "$is_reinstall" != "true" ]]; then
        return 0
    fi

    echo -e "\n\e[36m[ INFO ]\e[0m Setting up the equaliser, terminal and user directories..."

    command -v xdg-user-dirs-update &>/dev/null && xdg-user-dirs-update 2>/dev/null || true

    # Equaliser: a PipeWire filter-chain that WirePlumber puts in front of
    # whichever output is chosen. Picked up at the next login.
    if [ -f "$deployed/src/quickshell/media/equalizer.sh" ]; then
        YOAKE_DIR="$deployed/src" bash "$deployed/src/quickshell/media/equalizer.sh" install 2>/dev/null || true
    fi

    # kitty: upstream's kitty.conf includes colors.conf, which only matugen
    # writes. The yoake night palette takes its place.
    local kitty_dir="$HOME/.config/kitty"
    if [ -f "$project_root/config/kitty/yoake-night.conf" ]; then
        mkdir -p "$kitty_dir"
        backup_file "$kitty_dir/colors.conf"
        cp "$project_root/config/kitty/yoake-night.conf" "$kitty_dir/colors.conf"
    fi

    # starship: the prompt's config, and a hook in every shell rc present
    # (fish reads conf.d, so its hook is a file of its own).
    if [ -f "$project_root/config/starship/starship.toml" ]; then
        backup_file "$HOME/.config/starship.toml"
        cp "$project_root/config/starship/starship.toml" "$HOME/.config/starship.toml"
    fi
    if command -v starship &>/dev/null || [ -x "$HOME/.local/bin/starship" ]; then
        if [ -d "$HOME/.config/fish" ] || command -v fish &>/dev/null; then
            if ! grep -qs 'starship init' "$HOME/.config/fish/config.fish"; then
                mkdir -p "$HOME/.config/fish/conf.d"
                cat > "$HOME/.config/fish/conf.d/yoake-starship.fish" <<'EOF'
# Added by the yoake installer: terminal prompt.
if status is-interactive; and type -q starship
    starship init fish | source
end
EOF
            fi
        fi
        hook_starship "$HOME/.bashrc" 'command -v starship >/dev/null && eval "$(starship init bash)"'
        hook_starship "$HOME/.zshrc" 'command -v starship >/dev/null && eval "$(starship init zsh)"'
    fi
}
