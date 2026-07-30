#!/usr/bin/env bash
# Sets the wallpaper and recolours quickshell/fuzzel to match it.
# Accepts a still image or a video file.
set -euo pipefail

IMG="${1:-}"
if [ -z "$IMG" ]; then
  echo "Usage: set-wallpaper.sh <path-to-image-or-video>" >&2
  exit 1
fi
if [ ! -f "$IMG" ]; then
  echo "File not found: $IMG" >&2
  exit 1
fi
IMG="$(readlink -f "$IMG")"

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
mkdir -p "$CACHE"

# The palette extractor needs a still image, and so does the frosted glass
# under every panel:
# blurring live video under six surfaces every vsync costs real GPU time for a
# result that is blurred past recognition anyway. One extracted frame serves
# both, which also means the whole existing recolour pipeline is reused
# untouched for video wallpapers.
STILL=""
case "${IMG,,}" in
  *.mp4|*.mkv|*.webm|*.mov|*.m4v|*.avi)
    STILL="$CACHE/wallpaper-still.png"
    # Seek before decoding, and take a frame a second in: many videos open on
    # black, which would produce a palette of pure greys.
    ffmpeg -y -loglevel error -ss 1 -i "$IMG" -frames:v 1 -vf scale=1920:-1 "$STILL" </dev/null
    if [ ! -s "$STILL" ]; then
      # Shorter than a second, so fall back to the very first frame.
      ffmpeg -y -loglevel error -i "$IMG" -frames:v 1 -vf scale=1920:-1 "$STILL" </dev/null
    fi
    ;;
esac

PALETTE_SRC="${STILL:-$IMG}"

# Pre-blurred copy for the frosted glass under every panel. Blurring on the GPU
# instead cost one offscreen render target and one multi-pass blur per panel —
# about twenty of each — to produce an image that never changes between
# wallpaper switches. Doing it once here reduces each panel to a plain textured
# quad sharing a single small texture.
#
# 512px wide with sigma 8 lands close to the MultiEffect blur it replaces once
# the GPU scales it back up; the upscale is itself a bilinear smooth, which is
# why storing it small is free quality-wise as well as cheap.
BLUR="$CACHE/wallpaper-blur.png"
magick -define jpeg:size=1024x1024 "$PALETTE_SRC" \
  -resize 512x -gaussian-blur 0x8 -strip "$BLUR"

ln -sf "$IMG" ~/.config/current-wallpaper

# quickshell draws the wallpaper itself on the background layer and crossfades
# when this trigger file's path changes — swaybg is gone, it hard-cut the image.
# Line 2 carries the extracted still for video wallpapers (empty for images),
# line 3 the pre-blurred copy the panels sample.
printf '%s\n%s\n%s\n' "$IMG" "$STILL" "$BLUR" > ~/.config/quickshell/.wallpaper-path

# Regenerates generated-colors.json + fuzzel.ini. quickshell reads the JSON
# live (FileView) and fades to the new palette, so no restart is needed and the
# reload-quickshell hook is gone.
#
# This replaced `wallust run "$PALETTE_SRC" --palette dark16 -w`: wallust hands
# back positional ANSI slots, and the accent was slot 12 regardless of whether
# that slot held a colour — on a near-monochrome wallpaper it was grey, which
# the template then saturated into a cyan that appeared nowhere in the image.
~/.local/bin/wallpaper-palette.py "$PALETTE_SRC"
