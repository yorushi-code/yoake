# Yoake

The desktop shell for this machine. Quickshell on niri: the bar, the wallpaper,
the notification stack, the control centre, the launcher, the session lock and
the desktop widgets are all one program drawing one design.

夜明け — daybreak. It keeps the `y` that pairs this with `~/yworld`, the VPN
backend, and the rest of the word is the arc the shell actually runs: the
greeter, the lock and the idle chain are all about a machine going dark and
coming back. It was called `yshell` until the semantic layer landed, at which
point "shell" had stopped describing what it was.

Colours, spacing, pace and light are not constants. `Perception.qml` derives
them from what the machine is doing, `Theme.qml` computes the tokens, and the
bindings already in the tree carry the change outward — see
[PerformanceContract.md](PerformanceContract.md) for the rules that keeps
honest.

## What it is made of

| | |
|---|---|
| `shell.qml` | what exists, and which parts are loaded lazily |
| `Theme.qml` | colours, type scale, elevation, motion vocabulary |
| `Bar*.qml` | the three bar islands and every widget in them |
| `Launcher*.qml` | app launcher (`Mod+D`) |
| `LockScreen.qml`, `LockState.qml` | session lock (`Super+Alt+L`) |
| `Wallpaper*.qml` | wallpaper layer, picker and palette plumbing |
| `Dashboard.qml`, `Dash*.qml`, `Cc*.qml` | the dashboard and its three pages: the glance, the controls (`Mod+P`) and the desks |
| `Notif*.qml`, `Notifs.qml` | notification server, toasts and history (`Mod+N`) |
| `Vpn*.qml`, `Mihomo*.qml` | the front end for `~/yworld` |
| `Desktop*.qml`, `Widget*.qml` | desktop widgets (`Mod+Shift+E` to move them) |
| `bin/` | wallpaper pipeline and the idle chain |

Colours are not a fixed palette. `bin/set-wallpaper.sh` extracts them from the
wallpaper and writes `generated-colors.json`, which the shell reads live and
fades to — so the whole desktop, fuzzel included, re-themes itself when the
wallpaper changes.

## Video wallpapers

`set-wallpaper.sh` prepares three things beside the image itself: a still frame
for the palette, a blurred copy for the panels' frosted glass, and — for video —
a playable copy with its frame rate halved.

That last one is measured, not guessed. Shell CPU with the wallpaper fully on
screen:

| | |
|---|---|
| 1080p24 source | 20.7% |
| 720p24, 56% fewer pixels | 16.5% |
| 1080p15, half the frames | 13.3% |
| a still image | 8.1% |

Frames cost about twice what pixels do — what dominates is per-frame work, not
decode — so the rate is halved and the resolution is left alone. Halved rather
than clamped to a number, because an uneven divisor is what judder is: 24 → 12
drops every other frame and stays regular, 24 → 16 would alternate one- and
two-frame gaps.

Playback pauses only when a window's tile is the size of the whole output, which
is what niri gives a fullscreen window and nothing else. It reports neither tile
positions nor an `is_fullscreen` flag, so nothing short of that is knowable, and
anything less keeps playing: niri's gaps leave real wallpaper showing under even
a maximised column, and a frozen strip there is a worse bug than the CPU.
Pausing itself changes nothing on screen — VideoOutput keeps its last frame.

## The lock

`WlSessionLock`, one surface per output, one PAM conversation for all of them.
Authenticating per surface would open a conversation per monitor and count a
wrong password twice.

The PAM service is `/etc/pam.d/yoake` — `auth include login`, the same shape
swaylock and hyprlock ship. There is deliberately no unlock over IPC: a shell on
this machine must not be able to open the physical screen. If it ever traps the
session, the way out is Ctrl+Alt+F2, log in, `pkill niri`.

## Idle

`bin/yoake-idle.sh` drives swayidle: dim at 4 minutes, lock at 8, monitors off
at 9, suspend at 20 and only on battery. Dimming first is the warning — a screen
that goes straight from working to black is indistinguishable from a crash.

## Budget

The shell is held under 20% of one core on the desktop. Measure with two
interleaved passes and a long settle, never one sample: setting a wallpaper
re-runs the palette extractor and every panel animates to the new colours, so a
sample taken four seconds later measures the transition. The first attempt at
this reported a 1080p source as cheaper than its own downscale, which is
impossible and was the giveaway.

This used to point at a `wallbench.sh` under `~/.claude/jobs/*/tmp/`, which is a
scratch directory that gets collected — the reference had already rotted. The
method is the part worth keeping, and it is short enough to inline. Read the
counters rather than sampling with `top`: `utime + stime` over a fixed window is
exactly the CPU the process was given, where a sampler guesses at it.

```sh
pid=$(pgrep -x qs); hz=$(getconf CLK_TCK); w=15
a=$(awk '{print $14+$15}' /proc/$pid/stat); sleep $w
b=$(awk '{print $14+$15}' /proc/$pid/stat)
awk -v a=$a -v b=$b -v w=$w -v hz=$hz 'BEGIN{printf "%.2f%% of one core\n",(b-a)/hz/w*100}'
```

Interleave the conditions and take several windows each: on a live desktop, with
music playing and a clock ticking, two runs of the *same* configuration differ
by two or three points. A difference smaller than that is not a difference.

## The greeter does not run from this directory

`greetd` starts `/usr/local/bin/yoake-greeter`, which loads
`/usr/share/yoake/greeter/`. Everything under `greeter/` here is **source for a
package**, and editing it changes nothing about the machine until:

```
sudo bin/yoake-greeter-install
```

This is written down because it has already cost one fix: a correction to the
login screen was made, committed, and recorded as done, while every login for
days afterwards ran the older copy that was actually installed. From inside the
repo the two are indistinguishable — `git` is perfectly happy, and the file it
is happy about is not the file being executed.
