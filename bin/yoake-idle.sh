#!/usr/bin/env bash
# The idle chain for yoake.
#
# There was none: swayidle was installed and never started, so the screen sat
# lit at full brightness indefinitely and the session never locked itself. Four
# stages rather than one, because a screen that goes from working to black is
# indistinguishable from a crash — dimming first is the warning, and moving the
# mouse during it costs nothing.
#
#   4:00  dim the backlight          (reversible, no interruption)
#   8:00  lock the session
#   9:00  power the monitors off
#  20:00  suspend, but only on battery
#
# Locking before the screen goes off, not after: the lock surface has to be up
# and drawn before the panel dies, or the desktop is briefly readable when it
# comes back.
set -u

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/yoake"
mkdir -p "$STATE_DIR"
DIM_FILE="$STATE_DIR/pre-dim-brightness"
# Present means every stage is a no-op. A runtime path rather than a config
# one: staying awake is a decision about this session, and a machine that comes
# back from a reboot still refusing to sleep is a machine whose battery dies in
# a bag.
AWAKE_FILE="$STATE_DIR/keep-awake"

# Timings live in a file the user can edit, with the environment still winning
# for a one-off. The four numbers were constants in this script, which meant
# changing when the screen locks required editing the program that locks it.
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/idle.conf"
if [ -r "$CONF" ]; then
  # Only KEY=VALUE lines with a bare number, so a stray line in the file cannot
  # become a command.
  while IFS='=' read -r key value; do
    case "$key" in
      dim_percent)  [ -z "${YSHELL_IDLE_DIM_PERCENT:-}" ] && CONF_DIM_PERCENT=$value ;;
      dim)          [ -z "${YSHELL_IDLE_DIM:-}" ]         && CONF_DIM=$value ;;
      lock)         [ -z "${YSHELL_IDLE_LOCK:-}" ]        && CONF_LOCK=$value ;;
      screen_off)   [ -z "${YSHELL_IDLE_SCREEN_OFF:-}" ]  && CONF_OFF=$value ;;
      suspend)      [ -z "${YSHELL_IDLE_SUSPEND:-}" ]     && CONF_SUSPEND=$value ;;
      suspend_on_battery_only) CONF_BATTERY_ONLY=$value ;;
    esac
  done < <(grep -E '^[a-z_]+=[0-9]+$' "$CONF" 2>/dev/null)
fi

DIM_TO=${YSHELL_IDLE_DIM_PERCENT:-${CONF_DIM_PERCENT:-15}}
T_DIM=${YSHELL_IDLE_DIM:-${CONF_DIM:-240}}
T_LOCK=${YSHELL_IDLE_LOCK:-${CONF_LOCK:-480}}
T_OFF=${YSHELL_IDLE_SCREEN_OFF:-${CONF_OFF:-540}}
T_SUSPEND=${YSHELL_IDLE_SUSPEND:-${CONF_SUSPEND:-1200}}
BATTERY_ONLY=${CONF_BATTERY_ONLY:-1}

# Every stage asks first. Gating the daemon instead would mean restarting it to
# change the answer, and the answer changes while you are watching something.
case "${1:-run}" in
  dim|lock|screen-off|suspend)
    if [ -e "$AWAKE_FILE" ]; then exit 0; fi
    ;;
esac

case "${1:-run}" in
  dim)
    # Remembered rather than assumed: coming back to a hardcoded brightness is
    # its own small insult on a screen the user had set deliberately.
    current=$(brightnessctl -m | cut -d, -f4 | tr -d '%')
    # Only when there is something to dim, and only then is the old value
    # recorded: writing it unconditionally means undim later drags the screen
    # back down over a brightness the user raised in the meantime.
    if [ -n "${current:-}" ] && [ "$current" -gt "$DIM_TO" ]; then
      brightnessctl -m get > "$DIM_FILE" 2>/dev/null || true
      brightnessctl -q set "${DIM_TO}%" 2>/dev/null || true
    fi
    ;;
  undim)
    if [ -s "$DIM_FILE" ]; then
      brightnessctl -q set "$(cat "$DIM_FILE")" 2>/dev/null || true
      rm -f "$DIM_FILE"
    fi
    ;;
  lock)
    # Through the shell, so it is the yoake surface and not swaylock's
    # defaults. If the shell is not running there is nothing to lock with, and
    # falling back to swaylock is better than leaving the session open.
    if qs ipc call lock state >/dev/null 2>&1; then
      qs ipc call lock lock >/dev/null 2>&1
    else
      swaylock -f 2>/dev/null || true
    fi
    ;;
  screen-off)  niri msg action power-off-monitors >/dev/null 2>&1 || true ;;
  screen-on)   niri msg action power-on-monitors  >/dev/null 2>&1 || true ;;
  suspend)
    # Only on battery. Suspending a plugged-in machine mid-download is a
    # behaviour people disable idle timers over.
    state=$(cat /sys/class/power_supply/A[CD]*/online 2>/dev/null | head -1)
    if [ "$BATTERY_ONLY" != "1" ] || [ "${state:-1}" = "0" ]; then
      systemctl suspend
    fi
    ;;
  run)
    # Only ever one of these. Two swayidle daemons on the same chain fight over
    # the screen -- one asserts screen-off while the other has just powered the
    # monitors back on -- and there were two running, which is what made sleep
    # and wake behave differently on different days. Startup commands have to be
    # idempotent, because something re-runs them.
    for pid in $(pgrep -x swayidle 2>/dev/null); do
      [ "$pid" = "$$" ] && continue
      kill "$pid" 2>/dev/null || true
    done
    for _ in $(seq 1 20); do
      pgrep -x swayidle >/dev/null 2>&1 || break
      sleep 0.1
    done

    exec swayidle -w \
      timeout "$T_DIM"     "$0 dim"        resume "$0 undim" \
      timeout "$T_LOCK"    "$0 lock" \
      timeout "$T_OFF"     "$0 screen-off" resume "$0 screen-on" \
      timeout "$T_SUSPEND" "$0 suspend" \
      before-sleep "$0 lock" \
      after-resume "$0 screen-on"
    ;;
  awake-on)     : > "$AWAKE_FILE" ;;
  awake-off)    rm -f "$AWAKE_FILE" ;;
  awake-toggle)
    if [ -e "$AWAKE_FILE" ]; then rm -f "$AWAKE_FILE"; else : > "$AWAKE_FILE"; fi
    ;;
  awake-state)  [ -e "$AWAKE_FILE" ] && echo on || echo off ;;
  *)
    echo "usage: $0 [run|dim|undim|lock|screen-off|screen-on|suspend|awake-on|awake-off|awake-toggle|awake-state]" >&2
    exit 1
    ;;
esac
