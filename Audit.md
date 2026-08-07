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

## Backlog, in the order it should be worked

1. **66 literal durations.** The highest-value category and no longer merely a
   consistency issue: since `Perception` drives `motionScale`, a literal
   duration *stands still while the whole shell speeds up and slows down around
   it*. Every one of these is a widget that will visibly fall out of step at
   night and under load. Mechanical to fix, verifiable by the linter.
2. **99 off-ladder surface alphas.** Needs judgement per site, so it wants a
   file-at-a-time pass rather than a sweep. `LockScreen.qml` (28) and
   `WallpaperPicker.qml` (12) are half of it.
3. **The ten private shadows and twelve gradients.** Route through `Surface`
   or justify each in place. This is what "one surface" means concretely — more
   than any spacing change.
4. **The right-hand column.** Give the desktop widgets one alignment grid;
   delete the gauge rings; decide whether the media card or the bar island owns
   now-playing, because both cannot.
5. **The clock's seconds.** Remove, or demote to a state the shell enters
   deliberately.
6. **10 off-scale font sizes**, then the greeter as its own pass — it needs the
   ladders before it needs a repaint.

Nothing above is an aesthetic preference. Every item is either a number the
linter can check or a duplication visible in a screenshot.
