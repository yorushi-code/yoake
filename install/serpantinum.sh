#!/usr/bin/env bash
# Installs clean upstream Serpantinum (ilyamiro/serpantinum), not yoake.
#
# Upstream's own installer does the work, so what gets installed is exactly
# what upstream ships. On Arch it runs as it is. On Fedora it runs with
# install/compat in front of PATH (pacman/yay/sudo shims that answer with dnf)
# and three small patches to its copy, each checked before it runs:
#
#   deps.sh  "fedora" in its distro allowlist
#   ui.sh    SDDM's Wayland greeter by default: Fedora ships no Xorg server,
#            so the X11 greeter would leave the machine without a login screen
#   ui.sh    GPU/CPU detection that does not end the installer (set -e) when
#            grep finds nothing
#
# Started by install/install.sh (--product serpantinum), or directly.

set -e

YOAKE_INSTALL_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
UPSTREAM_SLUG="${UPSTREAM_SLUG:-ilyamiro/serpantinum}"
UPSTREAM_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum-installer"

export PKG_PRODUCT=serpantinum
source "$YOAKE_INSTALL_DIR/modules/pkg.sh"

if [ "$EUID" -eq 0 ]; then
    echo "Run this as your user, not root; it asks for sudo where it needs it." >&2
    exit 1
fi

case "$PKG_FAMILY" in
    arch|fedora) ;;
    *)
        echo "Serpantinum installs on Arch or Fedora (and their derivatives) only." >&2
        exit 1
        ;;
esac

# The installer itself needs git (and, on Fedora, the tools upstream expects
# to find before it installs anything: fzf, jq, lspci...).
if [ "$PKG_FAMILY" = "fedora" ]; then
    pkg_bootstrap
elif ! command -v git &>/dev/null; then
    sudo pacman -Sy --noconfirm --needed git
fi

# Same place and update logic as upstream's installer, so a later upstream
# run reuses this checkout.
if [ ! -d "$UPSTREAM_DIR/.git" ]; then
    rm -rf "$UPSTREAM_DIR"
    git clone "https://github.com/${UPSTREAM_SLUG}.git" "$UPSTREAM_DIR"
else
    git -C "$UPSTREAM_DIR" remote set-url origin "https://github.com/${UPSTREAM_SLUG}.git"
    git -C "$UPSTREAM_DIR" fetch origin
    git -C "$UPSTREAM_DIR" reset --hard origin/HEAD 2>/dev/null \
        || git -C "$UPSTREAM_DIR" reset --hard origin/master
fi

if [ "$PKG_FAMILY" = "arch" ]; then
    exec bash "$UPSTREAM_DIR/install/install.sh" "$@"
fi

# Applies one sed to upstream's copy and confirms it took effect; a pattern
# that no longer matches means upstream changed, and running on regardless
# could leave Fedora without a login screen.
patch_upstream() {
    local file="$UPSTREAM_DIR/install/modules/$1" expr="$2" check="$3"
    sed -i "$expr" "$file"
    if ! grep -qE "$check" "$file"; then
        echo "Upstream's installer changed ($1: $check); stopping rather than guessing." >&2
        echo "Please report it at https://github.com/yorushi-code/yoake/issues" >&2
        exit 1
    fi
}

patch_upstream deps.sh \
    's/^SUPPORTED_DISTROS=($/SUPPORTED_DISTROS=(\n    "fedora"/' \
    '^    "fedora"$'
patch_upstream ui.sh \
    's/^SDDM_WAYLAND=false$/SDDM_WAYLAND=true/' \
    '^SDDM_WAYLAND=true$'
patch_upstream ui.sh \
    "s/grep -iE 'vga|3d|display')$/grep -iE 'vga|3d|display' || true)/" \
    "display' \\|\\| true\\)$"

# Upstream installs its packages one at a time. That suits pacman; dnf reads
# the repository metadata again on every call, which turns ~70 packages into
# the better part of an hour. Its own list goes in first, as one transaction
# (what fails there is left for upstream's loop to retry and report).
upstream_pkgs=()
mapfile -t upstream_pkgs < <(
    source "$UPSTREAM_DIR/install/modules/deps.sh" >/dev/null 2>&1
    printf '%s\n' "${REQUIRED_PKGS[@]}" sddm qt6-declarative qt6-svg sddm-wayland-generic
)
# What Arch pulls in with those packages and Fedora splits out: pw-play (the
# shell's interface sounds) lives in pipewire-utils, and the fonts it names.
upstream_pkgs+=("${FEDORA_EXTRA_PKGS[@]}")
if [ ${#upstream_pkgs[@]} -gt 0 ]; then
    missing_pkgs=()
    for pkg in "${upstream_pkgs[@]}"; do
        if [ -n "$(pkg_name "$pkg")" ] && ! pkg_installed "$pkg"; then
            missing_pkgs+=("$pkg")
        fi
    done
    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        echo -e "\n\e[36m[ INFO ]\e[0m Installing upstream's ${#missing_pkgs[@]} packages in one dnf transaction..."
        pkg_install_batch "${missing_pkgs[@]}" || true
    fi
fi

export YOAKE_PKG_LIB="$YOAKE_INSTALL_DIR/modules/pkg.sh"
export PATH="$YOAKE_INSTALL_DIR/compat:$PATH"
exec bash "$UPSTREAM_DIR/install/install.sh" "$@"
