#!/usr/bin/env bash

EXTRA_CONFIGS=(
    "kitty"
    "cava"
    "fastfetch"
)

get_wallpaper_dir() {
    local user_pics=""
    if [ -f "$HOME/.config/user-dirs.dirs" ]; then
        user_pics=$(grep '^XDG_PICTURES_DIR' "$HOME/.config/user-dirs.dirs" 2>/dev/null | cut -d= -f2 | tr -d '"' | sed "s|\$HOME|$HOME|g")
    fi
    if [[ -z "$user_pics" || "$user_pics" == "$HOME" ]]; then
        if command -v xdg-user-dir &>/dev/null; then
            user_pics="$(xdg-user-dir PICTURES 2>/dev/null || true)"
        fi
    fi
    if [[ -z "$user_pics" || "$user_pics" == "$HOME" ]]; then
        user_pics="$HOME/Pictures"
    fi
    user_pics="${user_pics%/}"
    echo "$user_pics/Wallpapers"
}

install_wallpapers() {
    local full_pack="${1:-true}"
    local wallpaper_dir
    wallpaper_dir=$(get_wallpaper_dir)
    local wallpaper_repo="https://github.com/ilyamiro/shell-wallpapers.git"
    local clone_dir="${XDG_CACHE_HOME:-"$HOME/.cache"}/serpantinum-wallpapers"

    mkdir -p "$wallpaper_dir"

    if [ "$full_pack" = true ]; then
        if [ -d "$clone_dir/.git" ]; then
            git -C "$clone_dir" fetch --depth 1 origin 2>/dev/null || git -C "$clone_dir" fetch origin 2>/dev/null || true
            git -C "$clone_dir" reset --hard origin/HEAD 2>/dev/null || git -C "$clone_dir" reset --hard origin/main 2>/dev/null || git -C "$clone_dir" reset --hard origin/master 2>/dev/null || true
        else
            rm -rf "$clone_dir"
            git clone --depth 1 "$wallpaper_repo" "$clone_dir" 2>/dev/null || true
        fi
        if [ -d "$clone_dir/images" ]; then
            cp -r "$clone_dir/images/"* "$wallpaper_dir/" 2>/dev/null || true
        elif [ -d "$clone_dir" ]; then
            cp -r "$clone_dir/"* "$wallpaper_dir/" 2>/dev/null || true
            rm -f "$wallpaper_dir/README.md" "$wallpaper_dir/LICENSE" 2>/dev/null || true
            rm -rf "$wallpaper_dir/.git" 2>/dev/null || true
        fi
    else
        if [ -z "$(ls -A "$wallpaper_dir" 2>/dev/null | grep -iE '\.(jpg|jpeg|png|gif|webp)$')" ]; then
            if [ -d "$clone_dir/.git" ]; then
                git -C "$clone_dir" fetch --depth 1 origin 2>/dev/null || git -C "$clone_dir" fetch origin 2>/dev/null || true
                git -C "$clone_dir" reset --hard origin/HEAD 2>/dev/null || git -C "$clone_dir" reset --hard origin/main 2>/dev/null || git -C "$clone_dir" reset --hard origin/master 2>/dev/null || true
            else
                rm -rf "$clone_dir"
                mkdir -p "$clone_dir"
                (
                    cd "$clone_dir" || exit 0
                    git init -q
                    git remote add origin "$wallpaper_repo"
                    git fetch --depth 1 --filter=blob:none origin HEAD -q 2>/dev/null || true
                )
            fi
            (
                cd "$clone_dir" || exit 0
                local random_pics
                random_pics=$(git ls-tree -r HEAD --name-only 2>/dev/null | grep -iE '\.(jpg|jpeg|png|gif|webp)$' | shuf -n 3)
                if [ -z "$random_pics" ]; then
                    random_pics=$(git ls-tree -r FETCH_HEAD --name-only 2>/dev/null | grep -iE '\.(jpg|jpeg|png|gif|webp)$' | shuf -n 3)
                fi
                if [ -n "$random_pics" ]; then
                    for pic in $random_pics; do
                        local filename
                        filename=$(basename "$pic")
                        git show HEAD:"$pic" > "$wallpaper_dir/$filename" 2>/dev/null || git show FETCH_HEAD:"$pic" > "$wallpaper_dir/$filename" 2>/dev/null || true
                    done
                fi
            )
        fi
    fi
}

setup_sddm() {
    local project_root="$1"
    if [ "$OPT_SDDM" != true ]; then
        return 0
    fi

    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deploy.configuring_sddm")"

    if [ "$REPLACE_DM" = true ]; then
        local dms=("gdm" "gdm3" "lightdm" "lxdm" "lxdm-gtk3" "ly")
        for dm in "${dms[@]}"; do
            if systemctl is-enabled "$dm.service" &>/dev/null || systemctl is-active "$dm.service" &>/dev/null; then
                echo "  $(t "installer.deploy.disabling_dm" "dm=$dm")"
                sudo systemctl disable "$dm.service" 2>/dev/null || true
                sudo pacman -Rns --noconfirm "$dm" >/dev/null 2>&1 || true
            fi
        done
    fi

    sudo rm -rf /usr/share/sddm/themes/matugen-minimal
    sudo rm -rf /usr/share/sddm/themes/material-you
    sudo rm -f /etc/sddm.conf.d/*matugen*.conf
    sudo rm -f /etc/sddm.conf.d/*material-you*.conf
    sudo rm -f /etc/sddm.conf

    local sddm_theme_src="$project_root/config/sddm/themes/material-you"
    local sddm_theme_dest="/usr/share/sddm/themes/material-you"

    if [ -d "$sddm_theme_src" ]; then
        sudo mkdir -p "$sddm_theme_dest"
        sudo cp -r "$sddm_theme_src/." "$sddm_theme_dest/"
        sudo chmod -R 755 "$sddm_theme_dest"
        if [ -d "$sddm_theme_src/font" ]; then
            sudo mkdir -p /usr/share/fonts/TTF
            sudo cp -r "$sddm_theme_src/font/"*.ttf /usr/share/fonts/TTF/ 2>/dev/null || true
            fc-cache -f /usr/share/fonts >/dev/null 2>&1 || true
        fi
    fi

    sudo mkdir -p /etc/sddm.conf.d

    if [ "$SDDM_WAYLAND" = true ]; then
        cat <<EOF | sudo tee /etc/sddm.conf.d/10-material-you.conf > /dev/null
[Theme]
Current=material-you
ThemeDir=/usr/share/sddm/themes

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EOF
    else
        cat <<EOF | sudo tee /etc/sddm.conf.d/10-material-you.conf > /dev/null
[Theme]
Current=material-you
ThemeDir=/usr/share/sddm/themes
EOF
    fi

    sudo systemctl enable sddm.service -f 2>/dev/null || true
    echo -e "  \e[32m$(t "installer.deploy.sddm_success")\e[0m"
}

deploy_package() {
    local REPO_ROOT="$1"
    local OLD_COMMIT="$2"
    local NEW_COMMIT="$3"
    local IS_REINSTALL="$4"
    local INSTALL_STATE="$5"
    shift 5
    local COMPOSITORS=("$@")

    local TARGET_BASE="$HOME/.local/share/yoake"
    local BIN_DIR="$HOME/.local/bin"

    local is_update=false
    if [[ "$INSTALL_STATE" == "current" && "$IS_REINSTALL" != "true" ]]; then
        is_update=true
    fi

    local do_full_deploy=true

    if [ "$IS_REINSTALL" != "true" ] && [ -n "$OLD_COMMIT" ] && [ "$OLD_COMMIT" != "unknown" ] && [ -d "$REPO_ROOT/.git" ]; then
        if git -C "$REPO_ROOT" cat-file -e "$OLD_COMMIT" 2>/dev/null; then
            do_full_deploy=false
        fi
    fi

    if [ "$do_full_deploy" = true ]; then
        rm -rf "$TARGET_BASE"
        mkdir -p "$TARGET_BASE/bin" "$TARGET_BASE/src" "$BIN_DIR"

        if [ -d "$REPO_ROOT/bin" ] && [ "$(ls -A "$REPO_ROOT/bin" 2>/dev/null)" ]; then
            cp -r "$REPO_ROOT/bin/." "$TARGET_BASE/bin/"
            chmod +x "$TARGET_BASE/bin/"* 2>/dev/null || true
        fi

        if [ -d "$REPO_ROOT/src" ] && [ "$(ls -A "$REPO_ROOT/src" 2>/dev/null)" ]; then
            cp -r "$REPO_ROOT/src/." "$TARGET_BASE/src/"
            find "$TARGET_BASE/src/scripts" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
        fi

        for cfg in "${EXTRA_CONFIGS[@]}"; do
            local src_cfg="$REPO_ROOT/config/$cfg"
            local dest_cfg="$HOME/.config/$cfg"
            if [ -d "$src_cfg" ]; then
                mkdir -p "$dest_cfg"
                cp -r "$src_cfg/." "$dest_cfg/"
            elif [ -f "$src_cfg" ]; then
                mkdir -p "$(dirname "$dest_cfg")"
                cp "$src_cfg" "$dest_cfg"
            fi
        done

        if [ "$is_update" != "true" ]; then
            for comp in "${COMPOSITORS[@]}"; do
                local target_config_name
                case "$comp" in
                    hyprland) target_config_name="hypr" ;;
                    niri) target_config_name="niri" ;;
                    sway) target_config_name="sway" ;;
                    *) target_config_name="$comp" ;;
                esac

                local TARGET_CONFIG_DIR="$HOME/.config/$target_config_name"
                local BACKUP_BASE="$HOME/.config/${target_config_name}_backup"
                local BACKUP_DIR="$BACKUP_BASE/backup_$(date +%Y%m%d_%H%M%S)"

                local SRC_COMP_DIR=""
                if [ -d "$REPO_ROOT/compositors/$comp" ] && [ "$(ls -A "$REPO_ROOT/compositors/$comp" 2>/dev/null)" ]; then
                    SRC_COMP_DIR="$REPO_ROOT/compositors/$comp"
                elif [ -d "$REPO_ROOT/compositor/$comp" ] && [ "$(ls -A "$REPO_ROOT/compositor/$comp" 2>/dev/null)" ]; then
                    SRC_COMP_DIR="$REPO_ROOT/compositor/$comp"
                fi

                if [ -n "$SRC_COMP_DIR" ]; then
                    if [ -d "$TARGET_CONFIG_DIR" ] && [ "$(ls -A "$TARGET_CONFIG_DIR" 2>/dev/null)" ]; then
                        mkdir -p "$BACKUP_DIR"
                        cp -a "$TARGET_CONFIG_DIR/." "$BACKUP_DIR/" 2>/dev/null || true
                    fi

                    mkdir -p "$TARGET_CONFIG_DIR"
                    cp -r "$SRC_COMP_DIR/." "$TARGET_CONFIG_DIR/"

                    find "$TARGET_CONFIG_DIR" -type f -o -type l | while IFS= read -r dest_file; do
                        local rel_path="${dest_file#$TARGET_CONFIG_DIR/}"
                        if [ ! -e "$SRC_COMP_DIR/$rel_path" ] && [ ! -L "$SRC_COMP_DIR/$rel_path" ]; then
                            rm -f "$dest_file"
                        fi
                    done

                    find "$TARGET_CONFIG_DIR" -depth -type d -empty ! -path "$TARGET_CONFIG_DIR" -delete 2>/dev/null || true
                fi
            done
        fi
    else
        mkdir -p "$TARGET_BASE/bin" "$TARGET_BASE/src" "$BIN_DIR"

        local changed_files=""
        local deleted_files=""

        if [ "$OLD_COMMIT" != "$NEW_COMMIT" ]; then
            changed_files=$(git -C "$REPO_ROOT" diff --name-only --no-renames --diff-filter=AM "$OLD_COMMIT" "$NEW_COMMIT" 2>/dev/null || true)
            deleted_files=$(git -C "$REPO_ROOT" diff --name-only --no-renames --diff-filter=D "$OLD_COMMIT" "$NEW_COMMIT" 2>/dev/null || true)
        fi

        if [ -n "$deleted_files" ]; then
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                if [[ "$file" == bin/* ]]; then
                    rm -f "$TARGET_BASE/$file"
                elif [[ "$file" == src/* ]]; then
                    rm -f "$TARGET_BASE/$file"
                elif [[ "$file" == config/* ]]; then
                    local rel_cfg="${file#config/}"
                    local cfg_name="${rel_cfg%%/*}"
                    for cfg in "${EXTRA_CONFIGS[@]}"; do
                        if [[ "$cfg" == "$cfg_name" ]]; then
                            rm -f "$HOME/.config/$rel_cfg"
                        fi
                    done
                elif [[ "$file" == compositors/* || "$file" == compositor/* ]]; then
                    if [ "$is_update" != "true" ]; then
                        local comp_part="${file#compositor*/}"
                        local comp_name="${comp_part%%/*}"
                        local comp_file="${comp_part#*/}"
                        for comp in "${COMPOSITORS[@]}"; do
                            if [[ "$comp" == "$comp_name" ]]; then
                                local target_config_name
                                case "$comp" in
                                    hyprland) target_config_name="hypr" ;;
                                    niri) target_config_name="niri" ;;
                                    sway) target_config_name="sway" ;;
                                    *) target_config_name="$comp" ;;
                                esac
                                rm -f "$HOME/.config/$target_config_name/$comp_file"
                            fi
                        done
                    fi
                fi
            done <<< "$deleted_files"
        fi

        if [ -n "$changed_files" ]; then
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                if [[ "$file" == bin/* ]]; then
                    mkdir -p "$(dirname "$TARGET_BASE/$file")"
                    cp "$REPO_ROOT/$file" "$TARGET_BASE/$file"
                    chmod +x "$TARGET_BASE/$file" 2>/dev/null || true
                elif [[ "$file" == src/* ]]; then
                    mkdir -p "$(dirname "$TARGET_BASE/$file")"
                    cp "$REPO_ROOT/$file" "$TARGET_BASE/$file"
                    if [[ "$file" == *.sh ]]; then
                        chmod +x "$TARGET_BASE/$file" 2>/dev/null || true
                    fi
                elif [[ "$file" == config/* ]]; then
                    local rel_cfg="${file#config/}"
                    local cfg_name="${rel_cfg%%/*}"
                    for cfg in "${EXTRA_CONFIGS[@]}"; do
                        if [[ "$cfg" == "$cfg_name" ]]; then
                            mkdir -p "$(dirname "$HOME/.config/$rel_cfg")"
                            cp "$REPO_ROOT/$file" "$HOME/.config/$rel_cfg"
                        fi
                    done
                elif [[ "$file" == compositors/* || "$file" == compositor/* ]]; then
                    if [ "$is_update" != "true" ]; then
                        local comp_part="${file#compositor*/}"
                        local comp_name="${comp_part%%/*}"
                        local comp_file="${comp_part#*/}"
                        for comp in "${COMPOSITORS[@]}"; do
                            if [[ "$comp" == "$comp_name" ]]; then
                                local target_config_name
                                case "$comp" in
                                    hyprland) target_config_name="hypr" ;;
                                    niri) target_config_name="niri" ;;
                                    sway) target_config_name="sway" ;;
                                    *) target_config_name="$comp" ;;
                                esac
                                mkdir -p "$(dirname "$HOME/.config/$target_config_name/$comp_file")"
                                cp "$REPO_ROOT/$file" "$HOME/.config/$target_config_name/$comp_file"
                            fi
                        done
                    fi
                fi
            done <<< "$changed_files"
        fi
    fi

    if [ -f "$TARGET_BASE/bin/yoake" ]; then
        ln -sf "$TARGET_BASE/bin/yoake" "$BIN_DIR/yoake"
        sudo ln -sf "$TARGET_BASE/bin/yoake" /usr/local/bin/yoake 2>/dev/null || true
    fi

    if [ -f "$TARGET_BASE/bin/yoaked" ]; then
        ln -sf "$TARGET_BASE/bin/yoaked" "$BIN_DIR/yoaked"
        sudo ln -sf "$TARGET_BASE/bin/yoaked" /usr/local/bin/yoaked 2>/dev/null || true
    fi
}
