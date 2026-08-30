# Running yoake on Fedora

Upstream's installer does not run here and is not meant to. `check_supported_os()`
in `install/modules/deps.sh` allowlists Arch and its derivatives and exits 1 on
anything else, and every package call underneath it is `pacman`/`yay`. This is
the manual path instead, written down as it was actually walked.

Verified on Fedora 44, niri 26.04, quickshell 0.2.1 (`0.2.1^git20260209`, the
only build Fedora ships).

## Quickshell version

It runs on 0.2.1. This was worth checking rather than assuming: upstream
squashed its history and cut v2.0.0 on 2026-08-30, nine days after Quickshell
0.3.1, and declares no minimum version anywhere. It loads with no import errors
regardless, so there is no reason to leave Fedora's package for a COPR build or
a local prefix yet.

If that changes, the failure will be loud — missing QML types at startup, in
`qs`'s own stderr — not subtle.

## Running it

The shell finds its assets, scripts and sounds through `$YOAKE_DIR`, which must
point at the `src/` directory. `bin/yoake` and `bin/yoaked` derive it from their
own location, so from a checkout they need nothing:

```bash
bin/yoaked start
```

Running `qs -p src/quickshell/Shell.qml` by hand without that variable set is
the one mistake worth warning about, because it half-works: the bar draws and
reads real system state, but every panel-opening click is silently dead, since
each widget opens its popout through `$YOAKE_DIR/scripts/qs_manager.sh`.

## Configuration

`~/.config/yoake/settings.json`, seeded once from `config/yoake/settings.json`
and live-reloaded thereafter. Two keys matter for this fork:

```json
"theme": { "matugen": false, "yoake": true }
```

`yoake: true` puts the layer's palette in charge (see below); `matugen: false`
stops upstream's generator from overwriting it. Setting `yoake` to `false`
hands the shell back to upstream's theming unaltered, which is the only
reliable way to tell whether something is the layer's doing.

## Packages

Everything the base shell needs to start was already present. What is missing
from upstream's list, and what each one actually gates:

| Package | Gates | Needed? |
|---|---|---|
| `matugen` | upstream's wallpaper theming | No — the yoake palette layer replaces it |
| `acpi` | nothing | No — it is in upstream's package list, but no code in the tree references it |
| `satty` | annotating a screenshot after taking it | Only for that |
| `gpu-screen-recorder` | screen recording | Only for that |
| `wl-gammarelay-rs` | the blue light filter | Only for that |
| `zbar` | reading a QR code out of a screenshot | Only for that |

`imagemagick` is present as `magick` — Fedora's ImageMagick 7 package, which
upstream's Arch-shaped list names differently. It is a hard dependency of the
palette extractor, not optional.

## Testing without disturbing a running session

Two full shells in one session fight: duplicate bars and wallpaper layers, and
a scrap over the `org.freedesktop.Notifications` bus name, which the one that
started first keeps. Run the fork inside a nested niri instead — **without**
`--session`, so it does not take over D-Bus:

```bash
niri -c /path/to/minimal.kdl -- env YOAKE_DIR=$PWD/src qs -p $PWD/src/quickshell/Shell.qml
```

niri does not forward the child's stderr, so redirect it inside a wrapper
script if you want to read it. `WAYLAND_DISPLAY=wayland-2 grim shot.png` will
screenshot the nested output from outside.

## The palette

`src/scripts/wallpaper-palette.py <image>` writes
`~/.local/state/yoake/generated-colors.json`, which `YoakePalette` watches and
applies to `ThemeBackend`. It also rewrites `~/.config/fuzzel/fuzzel.ini`, so
fuzzel re-themes with the shell.

Note the state path. The shell this was ported from is still installed and
still reads its own palette out of `~/.config/quickshell/generated-colors.json`;
these two must not be pointed at the same file while both are installed.

## Known, and upstream's

Present before any change here, left alone deliberately:

- `Caching.getConfigDir` is called in `quickactions/actions/DrawAction.qml` and
  does not exist.
- `ScreenshotOverlay.qml` calls `.trim()` on something undefined at startup.
- The media widget's marquee scrolls "Nothing is playing" continuously while
  nothing is playing.

Idle CPU measured 18.3% of one core inside a nested compositor shortly after
startup — a rough figure taken under bad conditions, recorded only so there is
something to compare against once it runs for real.
