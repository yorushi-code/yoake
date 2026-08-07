# Visual audit

Measured 2026-08-05 against the running shell, not read off the design docs.

## The finding that reframes the rest

The brief asks for eleven updated systems — spacing, typography, radius,
elevation, glass, lighting, motion, reveal, hierarchy, composition. Ten of them
**already exist and are well designed**. `Theme.qml` carries a four-rung shape
ladder, a six-rung surface ladder, a five-rung spacing ladder, an eight-rung
type scale, three elevations and a named motion vocabulary, each with the
reasoning written beside it. `Surface.qml` is the one object every raised thing
is supposed to be made of.

They are not missing. They are **unenforced**, and the gap between the document
and the tree is now larger than the gap the documents were written to close:

| ladder | rungs | distinct values actually in the tree |
|---|---|---|
| surface alphas | 6 | **44** |
| motion durations | 7 | **26 literals**, 66 call sites |
| shape radii | 4 | 15 literals |
| type sizes | 8 | 7 off-scale literals |

`Theme.qml` says, of the surface ladder: *"There were twelve distinct alphas
before this; twelve is not a scale, it is a habit."* It is now forty-four —
nearly four times what was considered bad enough to write a ladder for.

**Why nobody noticed.** `bin/yoake-lint` has had an `off_ladder()` check the
whole time, and it reported zero. It matches values *against the rungs*: it
catches `radius: 10` where `Theme.radiusChip` says the same thing, and it is
blind by construction to `radius: 26`, which is on no rung at all. The linter
could only see conformity where conformity already existed. Green meant
unmeasured, not clean.

So the first deliverable is not a document. It is the gate. `yoake-lint` now has
a `drift()` pass reporting values that belong to no rung, printed separately and
**not counted toward the exit status** — design debt is not a bug, and a scanner
that turns one broken cat into a hundred and eighty spacing complaints is a
scanner nobody runs. `yoake-lint --drift` lists them with line numbers.

## What the screen actually shows

Read off a capture of the live desktop rather than off the source.

**The right-hand column is four objects, not a composition.** Clock, spectrum,
three gauge rings and the media card each have a different left edge, a
different width and a different visual treatment — display type, a bar
spectrum, circular gauges, a glass card. Nothing shares an alignment, so the
eye has no path through them. This is the "islands feel independent" complaint
in its most literal form, and it is a composition problem, not a styling one.

**The gauge rings duplicate the bar.** Three small rings with 3-character
labels, sitting under a bar that already reports network, battery and volume.
Duplication is visual noise by definition, and this is the strongest single
elimination candidate on the desktop.

**The media card duplicates the bar's centre island.** Same track, same artist,
two places, both permanently visible.

**The clock renders seconds.** Continuous motion on the largest element on the
desktop, carrying the least information of anything on it. Under Direction's
vocabulary this is a `continuous` surface where nothing asked for one.

**`Surface.qml` is bypassed ten times.** Eleven `RectangularShadow` instances
live in nine files; exactly one of them is inside `Surface.qml`. The file's own
comment says depth, edge and highlight *"are not per-widget decisions — they are
what tells the eye which surfaces belong to the same thing."* Ten widgets make
that decision privately. Twelve gradients across eleven files are the same
story.

**The greeter is a second design system.** `greeter/Theme.qml` has no shape
ladder, no surface ladder and no motion vocabulary — it is a parallel set of
constants that happens to look similar. Two of the remaining radius findings are
there, and they cannot be fixed from here: the greeter installs to
`/usr/share/yoake` and needs a root install to take effect.

## Done in this pass

Radius drift, 8 → 2 (both remaining are the greeter).

Five of the eight were **circles**: `28×28 radius 14`, `72×72 radius 36`,
`14×14 radius 7`, and two more in the greeter. `Theme.pill(height)` already
exists for exactly this, and its comment says it is a function *"so the call
site cannot drift from the height it is rounding"* — five call sites were
computing `height / 2` by hand, which is the precise drift the function was
written to prevent. Now `Theme.pill(height)`.

One was a **false positive in the new check**: `DesktopWidget`'s scrim is a
`RectangularShadow` with `anchors.margins: -6` and `radius: 26`, which is
`20 + 6` — derived shadow geometry, not a chosen shape. The check now exempts
radii inside `RectangularShadow`. A lint that teaches the reader to "fix"
correct code is worse than no lint, which is this project's own rule.

Two were genuinely off-family: `MediaCard` at 20 (a standalone surface floating
on the wallpaper — takes `radiusPanel`, not a third shape family between the two
that exist) and a keycap hint at 6 (`radiusPip`; at chip radius a 21px hint is
most of a pill and stops reading as a key).

## Worked since, in the order it was done

Measured against the running shell again, not against this document.

**4 and 5 are done.** The right-hand column is one object: `WidgetRail`, one
measure (440, the player card's own width), one right edge, one vertical
rhythm, dragged as a whole. The gauge rings and `StatGauge` are deleted —
`BarLoad` already reports the same numbers and only while they are worth
reporting, with the culprit processes named in its card. The clock's seconds
are gone; the separator was already pulsing on the second, so the beat they
carried was never theirs. `SystemClock` on the desktop and on the overview both
drop to minute precision, which is the same fix twice.

The spectrum stopped being a widget that vanishes. It is the rail's connective
band now, drawn at rest as a dotted arc — the floor shape the file had
described since it was written and that nothing had ever shown, because the
widget faded out with the audio and the arc only exists in silence.

**A third clock was on screen at all times** — bar, desktop, dashboard — and the
dashboard's is the one nothing else was standing in for. Its slot is the
notification history, which was one keystroke away and summarised nowhere.

**The toasts moved out from under the rail.** They fell down the right-hand
edge onto a 112px clock. Centre is the only free column and it is the honest
one: the centre island is already where this shell puts "what is going on".

**1 and 6 are done.** Sixty-six literal durations, twenty-six distinct values,
now zero. The gap they lived in had no names in it — a *transition* is neither
the shell answering nor a thing idling, and both existing groups were the wrong
shape for a wallpaper changing or a lock screen arriving. `animEnter`,
`animArrive`, `animDrift`, `animDoze`, plus `animTick` for the leg of an
oscillation. Type gained `fontHeadline` and `fontIconHero`; ten off-scale sizes
are now zero.

**The greeter has ladders.** Shape, motion and the headline rung, so its two
radius findings are gone and its seventeen literal durations with them. Its
motion deliberately does *not* scale with Perception: a login screen that is
slower at three in the morning looks broken to somebody who has just woken up.
The files are edited but **not installed** — `bin/yoake-greeter-install` needs
root and its only real test is a logout, which must not happen unattended.

**The desks page was a two-column empty table.** The window title was set
against the far right edge, so a desk with one window showed six hundred pixels
of nothing between the icon and its own label. Title beside the number, icons
against the edge.

**The quick-actions card contradicted its neighbour.** The Apps card below it
says in its own comment that a centred list leaves "a hand's width of nothing
directly under the heading"; the tile grid above it argued the opposite and
centred. Resolved in favour of the card that was right.

## Backlog, in the order it should be worked

1. **99 off-ladder surface alphas**, the last drift category with anything in
   it. Not one problem but three wearing one name, which is why a sweep would
   be wrong: the linter matches `Qt.alpha(Theme.x, n)` and cannot tell a *fill*
   (0.05, 0.07, 0.12, 0.16 — the existing ladder, missed by a rung) from a
   *veil* (0.42, 0.62, 0.86 — a scrim over content, which the ladder stops
   short of entirely) from *ink* (0.6, 0.75, 0.8 — how much of a colour a mark
   keeps, a third axis with no rungs at all). The fills are mechanical. The
   veils want a ladder of their own before anything is moved onto it, and the
   three-stop gradients in `LockScreen` and `DashOverview` are the shape it
   should be cut to.
2. **The four accent glows.** `BarIsland`, `BarWorkspaces`, `MediaOrb` and
   `WidgetSpectrum` each build the same figure by hand — an accent-tinted
   `RectangularShadow` at zero offset, spread ~1, blur chosen per object. This
   is the part of "the ten private shadows" that survived reading: the rest are
   depth (`Surface` owns it) or documented one-offs. A glow is not depth and
   should not be pushed into `Surface`; it wants its own object, with blur
   derived from the size of the thing glowing.
3. **The bar is still a container**, three islands each a `Row`, which is
   `Direction.md`'s own open item: rule 2 wants a composer that recomposes the
   interval rhythm and the optical centre when the media widget appears, rather
   than reflowing.
4. **`Reveal` still has one caller.** `ActionMenu`, `VpnPanel`, `CcWifiPage`,
   `CcBluetoothPage` and the notification stack each still spell their own
   motion out, and `LockScreen`'s entrance is a hand-rolled four-beat cascade
   written in pauses.
5. **The greeter needs installing** once somebody is at the machine, and that
   is the only way to find out whether any of the above reached it.

Nothing above is an aesthetic preference. Every item is either a number the
linter can check or a duplication visible in a screenshot.
