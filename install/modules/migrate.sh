#!/usr/bin/env bash

get_compositor_config_dir_name() {
    local comp="$1"
    case "$comp" in
        hyprland) echo "hypr" ;;
        niri) echo "niri" ;;
        sway) echo "sway" ;;
        *) echo "$comp" ;;
    esac
}

backup_compositor_directory() {
    local comp="$1"
    local dir_name
    dir_name=$(get_compositor_config_dir_name "$comp")

    local COMP_DIR="$HOME/.config/$dir_name"
    local BACKUP_BASE="$HOME/.config/${dir_name}_backup"
    local BACKUP_DIR="$BACKUP_BASE/backup_$(date +%Y%m%d_%H%M%S)"

    if [ -d "$COMP_DIR" ] && [ "$(ls -A "$COMP_DIR" 2>/dev/null)" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$COMP_DIR/." "$BACKUP_DIR/" 2>/dev/null || true
    fi
}

backup_compositors() {
    local compositors=("$@")
    for comp in "${compositors[@]}"; do
        backup_compositor_directory "$comp"
    done
}

migrate_legacy() {
    local compositors=("$@")
    pkill -f "settings_watcher.sh" 2>/dev/null || true
    pkill -f "hypr/scripts/quickshell" 2>/dev/null || true

    if [ "$PKG_FAMILY" = "arch" ] && pacman -Qq quickshell-git &>/dev/null; then
        yay -R --noconfirm quickshell-git 2>/dev/null || sudo pacman -Rdd --noconfirm quickshell-git 2>/dev/null || true
    fi

    backup_compositors "${compositors[@]}"

    if [ -f "$HOME/.local/state/imperative-dots-version" ]; then
        mkdir -p "$HOME/.config/hypr_backup"
        mv "$HOME/.local/state/imperative-dots-version" "$HOME/.config/hypr_backup/imperative-dots-version.bak" 2>/dev/null || true
    fi
}

# yoake -> kizashi (10.10.2026). Настройки, кэш и состояние переезжают под
# новое имя один раз; если kizashi уже есть, старое не трогаем -- там может
# быть свежее. Эквалайзер и starship установщик создаёт под новым именем, и
# со старыми файлами рядом фильтр и приглашение срабатывали бы дважды.
migrate_yoake_to_kizashi() {
    local base
    for base in "$HOME/.config" "${XDG_CACHE_HOME:-$HOME/.cache}" "${XDG_STATE_HOME:-$HOME/.local/state}" "${XDG_DATA_HOME:-$HOME/.local/share}"; do
        if [ -d "$base/yoake" ] && [ ! -e "$base/kizashi" ]; then
            mv "$base/yoake" "$base/kizashi"
        fi
    done

    local eq_dir="${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/pipewire.conf.d"
    if [ -f "$eq_dir/99-yoake-eq.conf" ]; then
        if [ -e "$eq_dir/99-kizashi-eq.conf" ]; then
            rm -f "$eq_dir/99-yoake-eq.conf"
        else
            sed 's/yoake/kizashi/g' "$eq_dir/99-yoake-eq.conf" > "$eq_dir/99-kizashi-eq.conf" &&
                rm -f "$eq_dir/99-yoake-eq.conf"
        fi
    fi

    rm -f "$HOME/.config/fish/conf.d/yoake-starship.fish"
}
