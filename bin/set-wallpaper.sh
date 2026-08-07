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
# 30, not 20. The rule below halves rather than clamps -- an uneven divisor is
# what judder is -- so a cap of 20 sent every ordinary 24fps video to 12fps,
# which is both visibly choppy and six seconds of x264 to produce. At 30 the
# common cases (24 and 30) pass through untouched and 60 halves to 30.
MAX_FPS=${YSHELL_WALLPAPER_MAX_FPS:-30}
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
  [ -n "$fps" ] || { printf '%s\t\t' "$src"; return 0; }
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
    printf '%s\t\t' "$src"
    return 0
  fi

  stamp=$(stat -c '%s-%Y' "$src")
  out="$CACHE/wallpaper-play-$(printf '%s' "$src-$stamp-$target_fps-$MAX_HEIGHT" | sha1sum | cut -c1-16).mp4"
  if [ -s "$out" ]; then
    printf '%s\t\t' "$out"
    return 0
  fi

  # Old prepared copies are dead the moment a new one is named, and so is the
  # encoder still making one. Changing wallpaper twice inside the ten seconds a
  # transcode takes otherwise leaves the first ffmpeg running against a file
  # that has just been deleted: it burns a core to produce something the
  # staleness check below will refuse, and then leaves it on disk until the
  # next change sweeps it.
  #
  # Matched by reading /proc rather than with `pkill -f`, which matches its own
  # caller's command line as readily as its target -- that mistake has already
  # killed the wrong process on this machine once.
  for pid in $(pgrep -x ffmpeg 2>/dev/null); do
    if tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q 'wallpaper-play-'; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  find "$CACHE" -maxdepth 1 -name 'wallpaper-play-*.mp4' -delete 2>/dev/null || true

  # The wallpaper does not wait for the encoder.
  #
  # A transcode is seconds of x264 -- longer for something big -- and making the
  # change of wallpaper block on it is what made changing the wallpaper feel
  # broken. The source plays immediately, the prepared copy is built behind it,
  # and the trigger file is rewritten when it is ready. The shell watches that
  # file, so the swap happens on its own.
  # Three tab-separated fields, because this runs inside a command
  # substitution and a subshell's variables do not survive it: what plays now,
  # where the prepared copy goes, and how to make it.
  printf '%s\t%s\t%s' "$src" "$out" "${scale}fps=$target_fps"
}

# Called after the trigger file has been written, so the swap has something to
# rewrite.
start_pending_transcode() {
  [ -n "${PENDING_OUT:-}" ] || return 0
  local src="$PLAY" out="$PENDING_OUT" vf="$PENDING_VF"
  local wanted="$IMG" still="$STILL" blur="$BLUR" trigger="$TRIGGER"
  (
    if ffmpeg -y -loglevel error -i "$src" \
        -vf "$vf" -an \
        -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
        -movflags +faststart "$out" </dev/null 2>/dev/null && [ -s "$out" ]; then
      # Only if the wallpaper is still the one this copy was made for: the user
      # may have moved on twice while the encoder was working.
      if [ "$(sed -n 1p "$trigger" 2>/dev/null)" = "$wanted" ]; then
        printf '%s\n%s\n%s\n%s\n' "$wanted" "$still" "$blur" "$out" > "$trigger.tmp"
        mv -f "$trigger.tmp" "$trigger"
      fi
    else
      # A transcode that failed is not a reason to have no wallpaper; the source
      # is already playing.
      rm -f "$out"
    fi
  ) >/dev/null 2>&1 &
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
    ffmpeg -y -loglevel error -ss 1 -i "$IMG" -frames:v 1 -vf scale=1920:-1 "$STILL.tmp.png" </dev/null
    if [ ! -s "$STILL.tmp.png" ]; then
      # Shorter than a second, so fall back to the very first frame.
      ffmpeg -y -loglevel error -i "$IMG" -frames:v 1 -vf scale=1920:-1 "$STILL.tmp.png" </dev/null
    fi
    [ -s "$STILL.tmp.png" ] && mv -f "$STILL.tmp.png" "$STILL"
    IFS=$'\t' read -r PLAY PENDING_OUT PENDING_VF <<<"$(prepare_video "$IMG")"
    ;;
esac

PALETTE_SRC="${STILL:-$IMG}"

# Pre-blurred copy for the frosted glass under every panel. Blurring on the GPU
# instead cost one offscreen render target and one multi-pass blur per panel —
# about twenty of each — to produce an image that never changes between
# wallpaper switches. Doing it once here reduces each panel to a plain textured
# quad sharing a single small texture.
#
# 1024px wide with sigma 16 is the same visual blur as the 512/sigma-8 this
# replaces — both scale together — but it is no longer being stretched nearly
# four times to fill a screen. Behind a bar island the difference was invisible;
# behind the whole lock screen the old one was a smear with no wallpaper left in
# it. One 1024x576 texture shared by every panel costs 2.4 MB.
BLUR="$CACHE/wallpaper-blur.png"
# Written through a temp file and renamed. The shell watches this path, and
# magick writes it in place over several seconds: reloading halfway through gets
# a truncated PNG, which is the "Unable to read image data" every panel logged
# on a wallpaper change. A rename is atomic, so a reader sees the old file or
# the new one and never half of either.
#
# Blurred small and then enlarged, rather than blurred at full size. A true
# gaussian convolution with sigma 16 over a 1024px image took 17 seconds --
# which was the whole of the "changing the wallpaper takes forever" -- and the
# result is a picture with no detail left in it by definition, so the detail
# thrown away by working at 256px was never going to survive the blur anyway.
# Measured against the old output: RMSE 0.24%, indistinguishable side by side,
# 0.33 seconds instead of 17.02.
#
# The jpeg:size hint matters as much as the resize: it lets the decoder produce
# a small image directly instead of unpacking twenty megapixels to throw them
# away.
magick -define jpeg:size=512x512 "$PALETTE_SRC" \
  -resize 256x -blur 0x4 -resize 1024x -strip "$BLUR.tmp"
mv -f "$BLUR.tmp" "$BLUR"

ln -sf "$IMG" ~/.config/current-wallpaper

# quickshell draws the wallpaper itself on the background layer and crossfades
# when this trigger file's path changes — swaybg is gone, it hard-cut the image.
# Line 2 carries the extracted still for video wallpapers (empty for images),
# line 3 the pre-blurred copy the panels sample, line 4 the copy actually played
# — which is the source itself unless it needed capping.
TRIGGER=~/.config/quickshell/.wallpaper-path
printf '%s\n%s\n%s\n%s\n' "$IMG" "$STILL" "$BLUR" "$PLAY" > "$TRIGGER"

# Now that the desktop has its wallpaper, catch up on the encode if one is due.
start_pending_transcode

# Regenerates generated-colors.json + fuzzel.ini. quickshell reads the JSON
# live (FileView) and fades to the new palette, so no restart is needed and the
# reload-quickshell hook is gone.
#
# This replaced `wallust run "$PALETTE_SRC" --palette dark16 -w`: wallust hands
# back positional ANSI slots, and the accent was slot 12 regardless of whether
# that slot held a colour — on a near-monochrome wallpaper it was grey, which
# the template then saturated into a cyan that appeared nowhere in the image.
~/.local/bin/wallpaper-palette.py "$PALETTE_SRC"

# The login screen wears the same picture, but it runs as its own user and
# cannot read a 700 home directory -- so it needs a copy taken for it. Done here
# rather than by hand, because a greeter still showing last month's wallpaper is
# how you find out this step was never wired up.
#
# -n: never prompt. A wallpaper change must not stop and ask for a password, and
# the sudoers rule that makes this work is narrow enough to be optional -- if it
# is missing, the desktop still changes and only the login screen lags.
if command -v yoake-greeter-sync >/dev/null 2>&1; then
  sudo -n /usr/local/bin/yoake-greeter-sync >/dev/null 2>&1 || true
fi
