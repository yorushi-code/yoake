#!/usr/bin/env python3
"""Derives the shell palette from a wallpaper, in OKLCh.

Replaces `wallust run`. wallust hands back sixteen positional ANSI slots and
the templates then picked one of them — color12 — as the accent. Position says
nothing about whether that slot is actually a colour: for sunset-cat.jpg,
color12 is #74787A, a neutral grey at 2.5% saturation, and the template's
`saturate(0.4)` amplified its noise-level blue bias roughly sevenfold into
#62808E. That is where the steel-cyan clock came from on a wallpaper with no
cyan in it, and why Theme.blue and Theme.yellow were both brown.

Here the wallpaper's dominant hue is measured — a chroma-weighted circular mean
over OKLCh — and the accent is *synthesized* on it. The measured mean chroma
travels with the hue as a confidence value, so a genuinely near-monochrome
image yields a genuinely muted accent instead of an invented one.

Written without Pillow or numpy on purpose: ImageMagick is already a hard
dependency of the wallpaper pipeline and, with the JPEG DCT scaling hint, it
hands back a 200px raw buffer in under 200ms. That is ~22k pixels, which plain
Python walks in a few milliseconds.
"""

import json
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HOME = Path.home()

# Repointed on the way into this tree, and not cosmetically. The shell this
# came from is still installed and still reads its palette out of
# ~/.config/quickshell/generated-colors.json; writing there would have one
# shell repainting another one while both are running. State also simply does
# not belong beside the source now that the source is a git checkout.
STATE_DIR = Path(os.environ.get("YOAKE_STATE_DIR")
                 or HOME / ".local" / "state" / "yoake")
COLORS_FILE = STATE_DIR / "generated-colors.json"
OVERRIDE_FILE = STATE_DIR / "palette-override.json"
FUZZEL_FILE = HOME / ".config" / "fuzzel" / "fuzzel.ini"

SAMPLE_PX = 200

# Semantic anchors. These stay recognisably themselves and are only nudged
# toward the wallpaper — a "blue" that has drifted to brown, which is what
# reading ANSI slot 3 produced, is worse than no tint at all.
HUE_BLUE = 250.0
HUE_YELLOW = 85.0
HUE_NUDGE_MAX = 22.0

# Mean chroma at which an image counts as fully, confidently coloured.
CHROMA_CONFIDENT = 0.09
# Below this the image is near-monochrome and the accent stays muted.
CHROMA_MUTED = 0.06

# APCA Lc the accent must reach against the background. 60 is the threshold for
# large text and UI shapes, which is what the accent is used for.
APCA_TARGET = 60.0


# ── colour space ──────────────────────────────────────────────────────────


def _srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _linear_to_srgb(c):
    if c <= 0.0031308:
        return c * 12.92
    return 1.055 * (c ** (1 / 2.4)) - 0.055


def rgb_to_oklab(r, g, b):
    r, g, b = _srgb_to_linear(r), _srgb_to_linear(g), _srgb_to_linear(b)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = l ** (1 / 3) if l > 0 else 0, m ** (1 / 3) if m > 0 else 0, s ** (1 / 3) if s > 0 else 0
    return (
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    )


def oklab_to_rgb(L, a, b):
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (
        _linear_to_srgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
        _linear_to_srgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
        _linear_to_srgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
    )


def lch_to_rgb(L, C, H):
    h = math.radians(H)
    return oklab_to_rgb(L, C * math.cos(h), C * math.sin(h))


def _in_gamut(rgb):
    return all(-0.0005 <= c <= 1.0005 for c in rgb)


def lch_to_hex(L, C, H):
    """Chroma is reduced until the colour fits sRGB.

    Clipping the channels instead would shift the hue, which defeats the point
    of choosing the hue deliberately.
    """
    if not _in_gamut(lch_to_rgb(L, C, H)):
        lo, hi = 0.0, C
        for _ in range(20):
            mid = (lo + hi) / 2
            if _in_gamut(lch_to_rgb(L, mid, H)):
                lo = mid
            else:
                hi = mid
        C = lo
    r, g, b = lch_to_rgb(L, C, H)
    return "#{:02X}{:02X}{:02X}".format(
        *(max(0, min(255, round(c * 255))) for c in (r, g, b))
    )


def hex_to_rgb(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) / 255 for i in (0, 2, 4))


# ── contrast ──────────────────────────────────────────────────────────────


def _apca_y(rgb):
    return 0.2126729 * rgb[0] ** 2.4 + 0.7151522 * rgb[1] ** 2.4 + 0.0721750 * rgb[2] ** 2.4


def apca_lc(text_hex, bg_hex):
    """APCA lightness contrast, absolute value.

    WCAG 2's ratio is a poor guide on dark backgrounds — it rates pale-on-black
    far higher than it reads — and the whole shell is dark.
    """
    ytxt, ybg = _apca_y(hex_to_rgb(text_hex)), _apca_y(hex_to_rgb(bg_hex))
    thr, clamp = 0.022, 1.414
    ytxt = ytxt if ytxt > thr else ytxt + (thr - ytxt) ** clamp
    ybg = ybg if ybg > thr else ybg + (thr - ybg) ** clamp
    if abs(ybg - ytxt) < 0.0005:
        return 0.0
    if ybg > ytxt:
        s = (ybg ** 0.56 - ytxt ** 0.57) * 1.14
        return abs(0.0 if s < 0.1 else s - 0.027) * 100
    s = (ybg ** 0.65 - ytxt ** 0.62) * 1.14
    return abs(0.0 if s > -0.1 else s + 0.027) * 100


# ── sampling ──────────────────────────────────────────────────────────────


def sample_pixels(path):
    """Returns [(L, C, H)] for a downsampled copy of the image.

    The jpeg:size hint lets libjpeg decode at a reduced DCT scale, which is the
    difference between 1.6s and 0.19s on a 7680x4320 wallpaper — and this runs
    on every wallpaper change.
    """
    hint = f"{SAMPLE_PX * 2}x{SAMPLE_PX * 2}"
    proc = subprocess.run(
        ["magick", "-define", f"jpeg:size={hint}", str(path),
         "-resize", f"{SAMPLE_PX}x{SAMPLE_PX}", "-depth", "8",
         "-colorspace", "sRGB", "RGB:-"],
        capture_output=True, timeout=60,
    )
    if proc.returncode != 0 or not proc.stdout:
        raise RuntimeError(proc.stderr.decode("utf-8", "replace").strip() or "magick produced no output")

    raw = proc.stdout
    out = []
    for i in range(0, len(raw) - 2, 3):
        L, a, b = rgb_to_oklab(raw[i] / 255, raw[i + 1] / 255, raw[i + 2] / 255)
        C = math.hypot(a, b)
        H = math.degrees(math.atan2(b, a)) % 360
        out.append((L, C, H))
    return out


# ── analysis ──────────────────────────────────────────────────────────────


def _mean_lightness(pixels):
    """How bright the picture is, over every pixel.

    Separate from _usable on purpose: hue and chroma have to ignore washed-out
    regions or a large flat grey area votes on a question it has no opinion
    about, but brightness is not that question. A black-and-white photograph
    has no usable pixels at all and used to report 0.5, so anything drawn
    straight onto the wallpaper could not tell white from black.
    """
    if not pixels:
        return 0.5
    return sum(p[0] for p in pixels) / len(pixels)


def _usable(pixels):
    # Near-black and near-white pixels carry a hue that is mostly sensor noise
    # and codec ringing, and they are usually the largest areas in the frame.
    return [p for p in pixels if 0.15 < p[0] < 0.95]


def dominant(pixels):
    """Chroma-weighted circular mean hue, and the mean chroma behind it.

    Weighting by chroma is what stops a large flat grey region from voting: a
    plain average over hue angles is meaningless when most pixels barely have
    one. The mean chroma comes back as the confidence in the answer.
    """
    usable = _usable(pixels)
    # Lightness over every pixel, not only the colourful ones. Hue and chroma
    # have to ignore washed-out regions or a large flat grey area votes on a
    # question it has no opinion about -- but how bright the picture is is not
    # that question. A black-and-white photograph has no usable pixels at all
    # and reported 0.5, so anything drawn straight onto it could not tell a
    # white wallpaper from a black one.
    if not usable:
        return 0.0, 0.0, _mean_lightness(pixels), 0.9

    x = y = weight = 0.0
    for L, C, H in usable:
        w = C * C  # squared, so saturated regions dominate washed-out ones
        h = math.radians(H)
        x += w * math.cos(h)
        y += w * math.sin(h)
        weight += w

    hue = math.degrees(math.atan2(y, x)) % 360 if weight > 0 else 0.0
    mean_c = sum(p[1] for p in usable) / len(usable)
    mean_l = _mean_lightness(pixels)
    return hue, mean_c, mean_l, max(p[0] for p in usable)


def hue_peaks(pixels, limit=8):
    """Candidate accent hues, for the swatch strip the user can pin from."""
    usable = [p for p in _usable(pixels) if p[1] > 0.012]
    if not usable:
        return []

    bins = 72
    hist = [0.0] * bins
    for _, C, H in usable:
        hist[int(H / 360 * bins) % bins] += C * C

    # Circular 3-tap smoothing, or a single noisy bin reads as a peak.
    smooth = [
        (hist[(i - 1) % bins] + 2 * hist[i] + hist[(i + 1) % bins]) / 4
        for i in range(bins)
    ]

    peaks = [
        (smooth[i], i * 360 / bins)
        for i in range(bins)
        if smooth[i] >= smooth[(i - 1) % bins] and smooth[i] >= smooth[(i + 1) % bins] and smooth[i] > 0
    ]
    peaks.sort(reverse=True)

    chosen = []
    for _, h in peaks:
        if any(min(abs(h - k), 360 - abs(h - k)) < 25 for k in chosen):
            continue
        chosen.append(h)
        if len(chosen) >= limit:
            break

    out = []
    for centre in chosen:
        near = [p for p in usable if min(abs(p[2] - centre), 360 - abs(p[2] - centre)) < 15]
        if not near:
            continue
        x = sum(p[1] * math.cos(math.radians(p[2])) for p in near)
        y = sum(p[1] * math.sin(math.radians(p[2])) for p in near)
        out.append((
            math.degrees(math.atan2(y, x)) % 360,
            sum(p[1] for p in near) / len(near),
        ))
    return out


# ── synthesis ─────────────────────────────────────────────────────────────


def _nudge(anchor, hue, confidence):
    """Pulls a semantic hue a bounded distance toward the wallpaper's."""
    delta = (hue - anchor + 540) % 360 - 180
    return (anchor + max(-HUE_NUDGE_MAX, min(HUE_NUDGE_MAX, delta * confidence))) % 360


def accent_chroma(chroma):
    """How much colour the accent is allowed to claim.

    Shared by the palette and by the swatch strip, so a swatch the user pins
    lands on exactly the colour the swatch was showing.
    """
    out = max(0.045, min(0.16, chroma * 1.6))
    if chroma < CHROMA_MUTED:
        # Honest: an image with barely any colour gets barely any accent,
        # rather than an invented one amplified out of sensor noise.
        out = min(out, chroma * 1.35 + 0.025)
    return out


def _accent_hex(hue, chroma, bg_hex, lightness=0.74):
    """Accent at the given hue, raised in lightness until it is readable."""
    hexed = lch_to_hex(lightness, chroma, hue)
    while apca_lc(hexed, bg_hex) < APCA_TARGET and lightness < 0.95:
        lightness += 0.02
        hexed = lch_to_hex(lightness, chroma, hue)
    return hexed


def synthesize(hue, chroma, mean_l):
    """The full palette for one hue and one measured chroma."""
    confidence = max(0.0, min(1.0, chroma / CHROMA_CONFIDENT))

    # Dark shell regardless of the wallpaper — it is a shell, not a theme
    # switcher — but the exact darkness leans a little on the image.
    bg_l = max(0.14, min(0.22, 0.13 + mean_l * 0.16))
    fg_l = max(0.90, min(0.96, 0.88 + mean_l * 0.08))

    # Surfaces carry only a trace of the hue. Any more and panels read as
    # tinted plastic rather than as glass over the wallpaper.
    tint = min(0.022, chroma * 0.28)

    accent_c = accent_chroma(chroma)
    background = lch_to_hex(bg_l, tint, hue)
    accent = _accent_hex(hue, accent_c, background)

    role_c = max(0.055, min(0.13, chroma * 1.4))
    return {
        "background": background,
        "foreground": lch_to_hex(fg_l, min(0.012, chroma * 0.1), hue),
        "surface0": lch_to_hex(bg_l + 0.09, tint * 1.2, hue),
        "surface1": lch_to_hex(bg_l + 0.17, tint * 1.3, hue),
        "surface2": lch_to_hex(bg_l + 0.25, tint * 1.4, hue),
        "accent": accent,
        "accentAlt": lch_to_hex(0.60, accent_c * 0.85, (hue - 20) % 360),
        "blue": lch_to_hex(0.70, role_c, _nudge(HUE_BLUE, hue, confidence)),
        "yellow": lch_to_hex(0.80, role_c, _nudge(HUE_YELLOW, hue, confidence)),
        "subtext1": lch_to_hex(fg_l - 0.14, min(0.010, chroma * 0.08), hue),
        "subtext0": lch_to_hex(fg_l - 0.28, min(0.008, chroma * 0.06), hue),
    }


# ── output ────────────────────────────────────────────────────────────────


def write_atomic(path, text):
    """FileView watches these; a partial read shows up as a palette that fails
    to parse and silently keeps the previous colours."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(text)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


FUZZEL_TEMPLATE = """\
# Auto-generated from the current wallpaper by wallpaper-palette.py.
# Do not edit by hand.
[main]
font=JetBrains Mono:size=11
terminal=kitty
prompt="> "
lines=8
width=40

[colors]
background={background}f0
text={foreground}ff
match={accent}ff
selection={surface0}ff
selection-text={foreground}ff
selection-match={accent}ff
border={accent}ff
placeholder={surface2}ff
counter={surface2}ff

[border]
width=2
radius=10
"""


def write_fuzzel(colors):
    write_atomic(FUZZEL_FILE, FUZZEL_TEMPLATE.format(
        **{k: v.lstrip("#") for k, v in colors.items() if isinstance(v, str)}
    ))


def effective_colors():
    """What the shell is actually showing: the pin if there is one."""
    for path in (OVERRIDE_FILE, COLORS_FILE):
        try:
            return json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
    return None


# ── commands ──────────────────────────────────────────────────────────────


def analyse(image):
    pixels = sample_pixels(image)
    hue, chroma, mean_l, _ = dominant(pixels)
    colors = synthesize(hue, chroma, mean_l)

    swatches = [
        {"hex": _accent_hex(h, accent_chroma(c), colors["background"]),
         "hue": round(h, 1), "chroma": round(c, 4)}
        for h, c in hue_peaks(pixels)
    ]

    colors["meta"] = {
        "source": str(image),
        "hue": round(hue, 1),
        "chroma": round(chroma, 4),
        "meanL": round(mean_l, 4),
        "confidence": round(max(0.0, min(1.0, chroma / CHROMA_CONFIDENT)), 3),
        "muted": chroma < CHROMA_MUTED,
        "swatches": swatches,
    }
    return colors


def cmd_probe(image):
    """The palette an image *would* produce, written nowhere.

    The picker shows this beside the wallpaper the cursor is on, which is the
    only moment at which "why will the clock be that colour" is answerable
    before committing to the change.
    """
    return analyse(image)


def cmd_generate(image):
    colors = analyse(image)

    # A pin belongs to the wallpaper it was chosen against; carrying it onto a
    # different image would reintroduce exactly the "where did this colour come
    # from" problem this script exists to fix.
    OVERRIDE_FILE.unlink(missing_ok=True)
    write_atomic(COLORS_FILE, json.dumps(colors, indent=2) + "\n")
    write_fuzzel(colors)
    return colors


def cmd_pin(hue, chroma):
    try:
        base = json.loads(COLORS_FILE.read_text())
    except (OSError, json.JSONDecodeError):
        base = {}
    meta = base.get("meta", {})
    colors = synthesize(hue, chroma, meta.get("meanL", 0.5))
    colors["meta"] = {
        **meta,
        "hue": round(hue, 1),
        "chroma": round(chroma, 4),
        # Recomputed, not inherited: the pinned swatch has its own chroma and
        # the confidence describes the colour actually in use.
        "confidence": round(max(0.0, min(1.0, chroma / CHROMA_CONFIDENT)), 3),
        "pinned": True,
    }
    write_atomic(OVERRIDE_FILE, json.dumps(colors, indent=2) + "\n")
    write_fuzzel(colors)
    return colors


def cmd_unpin():
    OVERRIDE_FILE.unlink(missing_ok=True)
    colors = effective_colors()
    if colors:
        write_fuzzel(colors)
    return colors


def main(argv):
    args = list(argv)
    if not args:
        print("usage: wallpaper-palette.py <image> | --probe <image> "
              "| --pin <hue> <chroma> | --unpin", file=sys.stderr)
        return 2

    if args[0] == "--probe":
        if len(args) < 2:
            print("--probe needs an image", file=sys.stderr)
            return 2
        probe = Path(args[1]).expanduser()
        if not probe.is_file():
            print(f"not a file: {probe}", file=sys.stderr)
            return 1
        print(json.dumps(cmd_probe(probe)))
        return 0

    if args[0] == "--unpin":
        cmd_unpin()
        return 0
    if args[0] == "--pin":
        if len(args) < 3:
            print("--pin needs a hue and a chroma", file=sys.stderr)
            return 2
        cmd_pin(float(args[1]) % 360, max(0.0, min(0.4, float(args[2]))))
        return 0

    image = Path(args[0]).expanduser()
    if not image.is_file():
        print(f"not a file: {image}", file=sys.stderr)
        return 1
    colors = cmd_generate(image)
    if "--print" in args:
        print(json.dumps(colors, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
