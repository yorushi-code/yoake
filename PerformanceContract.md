# The contract

What the shell is allowed to do, written down rather than left to whoever
touches it next. Everything here is either checkable by grep or measurable with
a command; a rule that is neither teaches people to skip the whole document,
which is why one line from the first draft of this file is gone (see the end).

## The layers

Each answers exactly one question, and may not answer another's.

| | question | memory |
|---|---|---|
| collectors (`SysInfo`, `Niri`, `Media`, `Cava`) | what does the world report | none — no policy |
| `Context.qml` | what is going on | hysteresis, debounce, rate limiting — no aesthetics |
| `Perception.qml` | how should the space be perceived | may filter inputs — may not remember decisions |
| `Theme.qml` | what are the token values | none — animation parameters only |
| `Behavior` / springs | how does a change become physical | this is where interpolation lives |
| QML bindings | draw | — |

## Invariants

**1. `Context.mode` is a summary, never an input.** It is an ordered if-chain,
so it is lossy by construction: coding, at night, on battery, with music on
collapses to `"music"` and the rest is discarded before anything can draw it.
It is the right shape for a readout and for `Notifs`, which genuinely wants one
word. No rendering decision may derive from it.

    grep -n 'Context\.mode' *.qml   # expected: Context.qml, Notifs.qml

**2. Perception may filter observations, but must never remember decisions.**
A function of input history, never of output history. Filtering an input is
required — unsmoothed CPU driving blur makes the surface shimmer on an idle
machine — but no value there may be a function of a previous value there, so
there is no feedback path and no way for the shell to settle into a state it
talked itself into.

Smoothing lives in `Perception` rather than in the collectors because a time
constant is a perceptual decision, not a measurement one: `SysInfo` cannot know
whether its number is about to drive a shadow or a log line, and a collector
that pre-smooths either picks one constant wrong for every consumer or publishes
several differently-damped copies of `cpu`, which is `Perception`'s policy
leaking downward.

**3. No layer may invent information it did not receive.** Aggregating,
filtering and compressing are allowed. Guessing is not. `cpu samples → EMA` is
fine. `focusedWindow → dwell` is fine, because dwell is named for what it
measures. `musicPlaying → userIsRelaxed` is not: that is a hypothesis wearing an
observation's clothes. This is the same rule `Context.qml` already applies when
it refuses to derive a `gaming` mode from a fullscreen flag niri does not report.

**4. Every semantic axis owns an exclusive set of visual outputs.** Axes are
partitioned by what they touch, not by what they mean — `calmness`, `motion` and
`tension` are one axis written three ways. Two axes wanting the same token is not
a matter of taste to be discussed; it is a design error, and the fix is that they
were one axis.

| axis | owns |
|---|---|
| spatial | `densityScale` — gaps, padding, margins |
| temporal | `motionScale` — durations, springs, damping |
| optical | `inkScale` — contrast, glass softness, opacity |
| hierarchy | `emphasis`, `chromeEmphasis` — accent strength, secondary chrome |
| — (budget veto) | `frost` |

This rule has already caught two mistakes in this tree.

Pulling decorative chrome back by lowering its ink would have put hierarchy and
optical on the same token, so hierarchy got a scalar of its own instead.

`frost` is the second and the more interesting one. Optical owned both `inkScale`
and `frost`, and they want opposite things from a busy machine: frost should go,
because it is the most expensive thing the shell draws, while ink should stay
full, because that is the moment someone is reading. One axis driving both made
one of them wrong at all times. The resolution was that dropping frost under load
was never a perceptual decision — it is this document talking. So it is a veto
applied after the axis rather than a term inside it, and optical went back to
meaning only what it says.

**A veto is not an axis.** It may only ever take something away on grounds of
cost, never add or restyle, and it must be traceable to a line in this file.
Anything richer than that is an axis in disguise and has to be argued as one.

## Rules

Semantic outputs shall be continuous whenever inputs are continuous.
Discontinuities require an explicit architectural reason, stated at the site.

- No semantic output may depend on presentation state.
- No presentation component may infer semantic state.
- Filtering is allowed only before semantic interpretation.
- Animation must never change semantics.
- Presentation is interruptible at any point.
- `Theme` contains no timing policy except animation parameters.
- No visual token may have more than one semantic owner.
- No polling faster than the display refresh.
- No fullscreen fragment shader unless benchmarked. Film grain, surface noise
  and glass imperfection are static tiled textures or they are not in the shell:
  a per-frame pass over a video wallpaper trades directly against the budget
  below, and it is the first thing that would have to be reverted.
- No allocation during steady-state animation.

## Budget

The shell is held under 20% of one core on the desktop.

It was not. Measured on an idle desktop with nothing playing and nothing on
screen moving, it sat at **48%**, and had done since the semantic layer was
written. Two causes, and both are worth naming because neither is visible in
the code that causes them:

**A continuous value published continuously.** `Perception`'s axes never settle
— a two-second tick nudged `hierarchy` by 0.02 and `spatial` by 0.002, forever
— and each nudge started a 1400ms `Behavior` in `Theme` on a token that every
size, gap, alpha and duration in the shell derives from. The whole design
system was therefore interpolating for 1.4 seconds out of every 2, in every
window, whether or not anyone could see it, and none of it was visible:
`emphasis` moving from 0.999 to 1.009 scales a glow by one part in a hundred.
The values are now published on a grid coarse enough that crossing a line means
something — about half a pixel of gap, four milliseconds of duration — and the
drift between lines costs nothing. **48% → 32%.**

**A pause is not a stop.** Two decorative animations ran forever: the desktop
clock's breathing colon and the sleeping cat's floating "z", the latter looping
with a `PauseAnimation` for its gap. A paused animation is still a running one,
so the render loop kept producing frames at the refresh rate for a "z" that was
not moving — and the widget layer is the size of the screen, so the cost has
nothing to do with how small the animated thing is. **Any** permanently running
animation on a full-output surface costs about a fifth of a core. **32% → 17%.**

The rule that follows: continuous motion is for something that is *happening*.
`cava` has music behind it and the load ring has load; a colon pulsing at three
in the morning for nobody is the whole cost with none of the reason. Decoration
that wants to repeat gets a `Timer` that restarts it, so the animation is
genuinely stopped in between.

    ~/.claude/jobs/*/tmp/wallbench.sh <wallpaper> [wallpaper...]

Measure with two interleaved passes and a long settle, never one sample: setting
a wallpaper re-runs the palette extractor and every panel animates to the new
colours, so a sample taken four seconds later measures the transition.

Two per-frame limits belong here — roughly 2 ms of CPU and 0.5 ms of JS per
frame — but they are **not currently measurable**: `wallbench.sh` reports
whole-process CPU percentage and cannot separate a frame from a settle. Until
something can produce those numbers (`QSG_RENDER_TIMING=1`, or the QML profiler
against a scripted interaction), they are an intention and are marked as one.
Writing an unenforceable number here as though it were checked is how a contract
becomes decoration.

## The line that was cut

The first draft carried `All semantic values monotonic`. It is either
unfalsifiable or false — density has to move in both directions — and a rule
nobody can fail is worse than no rule, because it trains the reader to skim past
the ones that bite. It was replaced by the continuity rule above, which is what
it was reaching for.
