#!/usr/bin/env bash
# Package management across distribution families.
#
# Upstream is written for Arch alone: pacman, yay, Arch package names. Every
# package operation of the installer goes through here instead, so the rest
# keeps using upstream's (Arch) names and the Arch path behaves as before.
#
#   arch    pacman + yay/paru, names used as they are
#   fedora  dnf, names translated through FEDORA_NAMES; what Fedora does not
#           package comes from its upstream release or COPR (see below)

# Arch name -> Fedora name. "-" means: not needed on Fedora, or installed
# another way (pkg_install_extra).
declare -A FEDORA_NAMES=(
    [fd]=fd-find
    [qt6-multimedia]=qt6-qtmultimedia
    [qt6-5compat]=qt6-qt5compat
    [qt6-websockets]=qt6-qtwebsockets
    [qt6-wayland]=qt6-qtwayland
    [qt6-declarative]=qt6-qtdeclarative
    [qt6-svg]=qt6-qtsvg
    [qt5-wayland]=qt5-qtwayland
    [qt5-quickcontrols]=qt5-qtquickcontrols
    [qt5-quickcontrols2]=qt5-qtquickcontrols2
    [qt5-graphicaleffects]=qt5-qtgraphicaleffects
    [bluez-utils]=bluez
    [networkmanager]=NetworkManager
    [pipewire-pulse]=pipewire-pulseaudio
    [libpulse]=pulseaudio-libs
    [python]=python3
    [python-websockets]=python3-websockets
    [imagemagick]=ImageMagick
    [wget]=wget2-wget
    [ffmpeg]=ffmpeg-free
    [adw-gtk-theme]=adw-gtk3-theme
    [base-devel]=-
    # The shell's own palette layer replaces matugen (docs/fedora.md).
    [matugen]=-
    # Not packaged; installed from their releases by pkg_install_extra.
    [satty]=-
    [starship]=-
    # Not packaged and optional: recording falls back to wf-recorder, the
    # blue light filter is simply unavailable.
    [gpu-screen-recorder]=-
    [wl-gammarelay-rs]=-
)

# Fedora-only additions: fonts the shell names that Arch pulls in otherwise,
# and pipewire-utils, which holds pw-play (interface sounds) and pw-cli (the
# equaliser); Arch ships those inside the pipewire package itself.
FEDORA_EXTRA_PKGS=("jetbrains-mono-fonts" "fontawesome-6-free-fonts" "xdg-user-dirs" "xwayland-satellite" "pipewire-utils")

detect_pkg_family() {
    local id="" like=""
    if [ -f /etc/os-release ]; then
        id=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
        like=$(awk -F= '/^ID_LIKE=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    fi
    case " $id $like " in
        *" fedora "*|*" rhel "*) echo "fedora" ;;
        *" arch "*) echo "arch" ;;
        *)
            if command -v pacman &>/dev/null; then echo "arch"
            elif command -v dnf &>/dev/null; then echo "fedora"
            else echo "unknown"
            fi
            ;;
    esac
}

PKG_FAMILY="${PKG_FAMILY:-$(detect_pkg_family)}"
export PKG_FAMILY

# Maps an upstream (Arch) name to this family's name; empty = skip.
pkg_name() {
    local pkg="$1"
    if [ "$PKG_FAMILY" = "fedora" ]; then
        local mapped="${FEDORA_NAMES[$pkg]:-$pkg}"
        [ "$mapped" = "-" ] && return 0
        echo "$mapped"
    else
        echo "$pkg"
    fi
}

# On Fedora the original name counts too: RPM Fusion's ffmpeg provides
# "ffmpeg" but not "ffmpeg-free", and installing the latter would conflict.
pkg_installed() {
    local name
    name=$(pkg_name "$1")
    [ -z "$name" ] && return 0
    case "$PKG_FAMILY" in
        fedora) rpm -q --whatprovides "$name" &>/dev/null || rpm -q --whatprovides "$1" &>/dev/null ;;
        *) pacman -Q "$name" &>/dev/null ;;
    esac
}

# Prints the upstream names from "$@" that are not installed yet.
pkg_missing() {
    case "$PKG_FAMILY" in
        fedora)
            local pkg
            for pkg in "$@"; do
                [ -z "$(pkg_name "$pkg")" ] && continue
                pkg_installed "$pkg" || echo "$pkg"
            done
            ;;
        *) pacman -T "$@" 2>/dev/null || true ;;
    esac
}

pkg_sync() {
    case "$PKG_FAMILY" in
        fedora) sudo dnf -y makecache ;;
        *) sudo pacman -Syyu --noconfirm ;;
    esac
}

pkg_install() {
    local pkg="$1"
    local safe_jobs="${2:-2}"
    local name
    name=$(pkg_name "$pkg")
    [ -z "$name" ] && return 0

    case "$PKG_FAMILY" in
        fedora)
            if [ "$pkg" = "hyprland" ]; then
                sudo dnf -y copr enable solopasha/hyprland || return 1
            fi
            sudo dnf -y install "$name"
            ;;
        *)
            if pacman -Si "$name" &>/dev/null; then
                sudo pacman -S --noconfirm --needed "$name"
            elif command -v yay &>/dev/null; then
                env CARGO_BUILD_JOBS="$safe_jobs" MAKEFLAGS="-j$safe_jobs" yay -S --noconfirm --needed "$name"
            elif command -v paru &>/dev/null; then
                env CARGO_BUILD_JOBS="$safe_jobs" MAKEFLAGS="-j$safe_jobs" paru -S --noconfirm --needed "$name"
            else
                sudo pacman -S --noconfirm --needed "$name"
            fi
            ;;
    esac
}

# One transaction for the whole list where the package manager allows it
# (dnf resolves repo metadata once instead of once per package). Returns
# non-zero if anything failed, and the caller retries one by one.
pkg_install_batch() {
    [ "$PKG_FAMILY" = "fedora" ] || return 1
    local names=() pkg name
    for pkg in "$@"; do
        [ "$pkg" = "hyprland" ] && return 1
        name=$(pkg_name "$pkg")
        [ -n "$name" ] && names+=("$name")
    done
    [ ${#names[@]} -eq 0 ] && return 0
    sudo dnf -y install "${names[@]}"
}

pkg_remove() {
    local name
    name=$(pkg_name "$1")
    [ -z "$name" ] && return 0
    case "$PKG_FAMILY" in
        fedora) sudo dnf -y remove "$name" ;;
        *) sudo pacman -Rns --noconfirm "$name" ;;
    esac
}

# Installs the tools the installer itself needs.
pkg_bootstrap() {
    local tools=(fzf jq curl git pciutils unzip fontconfig)
    local missing=() tool
    for tool in "${tools[@]}"; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done

    case "$PKG_FAMILY" in
        fedora)
            # lspci and fc-cache are the commands behind pciutils/fontconfig.
            if [ ${#missing[@]} -gt 0 ]; then
                sudo dnf -y install "${missing[@]}"
            fi
            ;;
        *)
            command -v makepkg &>/dev/null || missing+=("base-devel")
            if [ ${#missing[@]} -gt 0 ]; then
                sudo pacman -Sy --noconfirm --needed "${missing[@]}"
            fi
            if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
                local cache_build="${XDG_CACHE_HOME:-"$HOME/.cache"}/yoake-yay-bin"
                rm -rf "$cache_build"
                mkdir -p "$cache_build"
                git clone https://aur.archlinux.org/yay-bin.git "$cache_build"
                (cd "$cache_build" && makepkg -si --noconfirm)
                rm -rf "$cache_build"
            fi
            ;;
    esac
}

# Downloads a release tarball, finds the named binary inside and installs it
# into ~/.local/bin. Used for what Fedora does not package.
install_release_binary() {
    local url="$1" binary="$2"
    local bin_dir="$HOME/.local/bin"
    local tmp
    tmp=$(mktemp -d)
    mkdir -p "$bin_dir"
    if curl -fsSL --connect-timeout 15 --retry 3 "$url" -o "$tmp/pkg.tar.gz" \
        && tar -xzf "$tmp/pkg.tar.gz" -C "$tmp"; then
        local found
        found=$(find "$tmp" -type f -name "$binary" -perm -u+x | head -1)
        [ -z "$found" ] && found=$(find "$tmp" -type f -name "$binary" | head -1)
        if [ -n "$found" ]; then
            install -m 0755 "$found" "$bin_dir/$binary"
            rm -rf "$tmp"
            return 0
        fi
    fi
    rm -rf "$tmp"
    return 1
}

# Everything that is not a distribution package. On Arch the AUR covers all
# of it through REQUIRED_PKGS.
pkg_install_extra() {
    [ "$PKG_FAMILY" = "fedora" ] || return 0

    if ! command -v satty &>/dev/null; then
        echo -e "\n\e[36m[ INFO ]\e[0m Installing satty (screenshot annotation) from its release..."
        install_release_binary "https://github.com/gabm/Satty/releases/latest/download/satty-x86_64-unknown-linux-gnu.tar.gz" satty \
            || FAILED_PKGS+=("satty")
    fi

    if ! command -v starship &>/dev/null; then
        echo -e "\n\e[36m[ INFO ]\e[0m Installing starship (terminal prompt) from its release..."
        install_release_binary "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz" starship \
            || FAILED_PKGS+=("starship")
    fi
}
