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

# Playback caps for video wallpapers. Measured on this machine, shell CPU with
# the wallpaper fully on screen:
#
#   1080p24 (source)          20.7%
#   720p24  (-56% pixels)     16.5%
#   1080p15 (-50% frames)     13.3%
#   a still image              8.1%
#
# Frames cost roughly twice what pixels do, because what dominates is per-frame
# work — upload, scene graph, present — not decode. So the frame rate is halved
# and the resolution is left alone: a sharp wallpaper at half rate is both
# cheaper and better looking than a soft one at full rate.
#
# Halving rather than clamping to a fixed number, because an uneven divisor is
# what judder is: 24 -> 12 drops every other frame and stays perfectly regular,
# where 24 -> 16 would alternate 1 and 2 frame gaps.
MAX_FPS=${YSHELL_WALLPAPER_MAX_FPS:-20}
MAX_HEIGHT=${YSHELL_WALLPAPER_MAX_HEIGHT:-0}

if [ "$MAX_HEIGHT" -eq 0 ] && command -v niri >/dev/null 2>&1; then
  # The tallest connected output: anything above it is detail no monitor here
  # can show.
  MAX_HEIGHT=$(niri msg --json outputs 2>/dev/null | python3 -c '
import json, sys
try:
    outs = json.load(sys.stdin)
except ValueError:
    print(0); raise SystemExit
best = 0
for o in outs.values():
    logical = o.get("logical") or {}
    if logical.get("height"):
        best = max(best, int(logical["height"]))
print(best)
' 2>/dev/null || echo 0)
fi
[ "${MAX_HEIGHT:-0}" -gt 0 ] || MAX_HEIGHT=1080

# Transcodes a video wallpaper down to what the screen can actually show, once,
# and caches it against the source's path, size and mtime — the same wallpaper
# picked again must not re-encode.
prepare_video() {
  local src="$1"
  local fps height out stamp
  fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate \
        -of default=nw=1:nk=1 "$src" 2>/dev/null | head -1)
  height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height \
           -of default=nw=1:nk=1 "$src" 2>/dev/null | head -1)
  [ -n "$fps" ] || return 0
  fps=$(python3 -c "
n, _, d = '$fps'.partition('/')
try:
    print(round(float(n) / float(d or 1), 3))
except (ValueError, ZeroDivisionError):
    print(0)
")
  [ "${height:-0}" -gt 0 ] || height=0

  local target_fps="$fps"
  while python3 -c "import sys; sys.exit(0 if float('$target_fps') > $MAX_FPS else 1)"; do
    target_fps=$(python3 -c "print(round(float('$target_fps') / 2, 3))")
  done

  local scale=""
  if [ "$height" -gt "$MAX_HEIGHT" ]; then
    scale="scale=-2:$MAX_HEIGHT,"
  fi

  # Nothing to gain: already within both caps.
  if [ -z "$scale" ] && python3 -c "import sys; sys.exit(0 if abs(float('$target_fps') - float('$fps')) < 0.01 else 1)"; then
    printf '%s' "$src"
    return 0
  fi

  stamp=$(stat -c '%s-%Y' "$src")
  out="$CACHE/wallpaper-play-$(printf '%s' "$src-$stamp-$target_fps-$MAX_HEIGHT" | sha1sum | cut -c1-16).mp4"
  if [ -s "$out" ]; then
    printf '%s' "$out"
    return 0
  fi

  # Old prepared copies are dead the moment a new one is named.
  find "$CACHE" -maxdepth 1 -name 'wallpaper-play-*.mp4' -delete 2>/dev/null || true

  if ffmpeg -y -loglevel error -i "$src" \
      -vf "${scale}fps=$target_fps" -an \
      -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
      -movflags +faststart "$out" </dev/null 2>/dev/null && [ -s "$out" ]; then
    printf '%s' "$out"
  else
    # A transcode that failed is not a reason to have no wallpaper.
    rm -f "$out"
    printf '%s' "$src"
  fi
}

# The palette extractor needs a still image, and so does the frosted glass
# under every panel:
# blurring live video under six surfaces every vsync costs real GPU time for a
# result that is blurred past recognition anyway. One extracted frame serves
# both, which also means the whole existing recolour pipeline is reused
# untouched for video wallpapers.
STILL=""
PLAY=""
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
    PLAY="$(prepare_video "$IMG")"
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
# line 3 the pre-blurred copy the panels sample, line 4 the copy actually played
# — which is the source itself unless it needed capping.
printf '%s\n%s\n%s\n%s\n' "$IMG" "$STILL" "$BLUR" "$PLAY" > ~/.config/quickshell/.wallpaper-path

# Regenerates generated-colors.json + fuzzel.ini. quickshell reads the JSON
# live (FileView) and fades to the new palette, so no restart is needed and the
# reload-quickshell hook is gone.
#
# This replaced `wallust run "$PALETTE_SRC" --palette dark16 -w`: wallust hands
# back positional ANSI slots, and the accent was slot 12 regardless of whether
# that slot held a colour — on a near-monochrome wallpaper it was grey, which
# the template then saturated into a cyan that appeared nowhere in the image.
~/.local/bin/wallpaper-palette.py "$PALETTE_SRC"
