# Direction

The other three documents are about being right. This one is about being
noticed, which is a separate problem and the one a demo reel is actually won on.

`PerformanceContract.md` governs truth: what is happening, and what may be
inferred from it. This governs experience: in what order a person lives through
it. A panel can have every value correct — the right air, the right tempo, the
right accent — change all of them on one frame, and read as digital. The same
four events spread across a fifth of a second read as breathing. No token
changed. Only the order did.

Theme answers *how much*. This answers *when*. They are orthogonal, and neither
is downstream of the other.

## The unit

Nothing here is written in milliseconds.

A motion spec normally reads: space at 0, object at +40, accent at +90, content
at +150. That is correct at exactly one tempo. `Perception` moves `motionScale`
between 0.55 and 1.60, so at 3am `Theme.animNormal` is 352ms while a hardcoded
+40 is still +40 — the content would arrive before the space finished opening,
and the choreography would invert itself precisely in the state it was written
for. Every offset in `Direction.qml` is a fraction of `Direction.tempo`, so the
sequence stretches and compresses as one thing.

| beat | fraction | at tempo 220 |
|---|---|---|
| `beatSpace` | 0 | 0ms |
| `beatObject` | 0.20 | 44ms |
| `beatAccent` | 0.45 | 99ms |
| `beatContent` | 0.65 | 143ms |
| `rest` | 1.40 | 308ms |

## Principles

**1. Never move more than one large object at a time.** Simultaneity is what
makes an interface read as a machine executing instructions rather than a space
rearranging itself.

**2. Space first, object second.** Always. A surface that moves into room which
has not been made yet has to shove something aside, and shoving is the
difference between an interface that opens and one that interrupts.

**3. The accent arrives last, never first.** It answers "where do I look", and
asking that before there is anything to look at is what makes a shell feel like
it is flashing at you.

**4. Motion begins before content is legible.** The movement is what the eye
catches; arriving and then starting to move is two events where there should be
one.

**5. After any large movement, a state of rest.** `Direction.rest`, not a fixed
250–400ms — a constant is dead air at a fast tempo and an overlap at a slow one,
which is rule 1 reintroduced through the back door.

This is a rule an author obeys when writing a sequence, like 2 and 3, and not a
mechanism. Enforcing it globally would mean a scheduler holding every animation
back until the last large movement had settled, which is a second engine sitting
between every surface and its own motion. Checked where it plainly applies —
switching sheets closes one and opens another on the same frame — and it holds:
at forced slow tempo the old panel leaves, there is a clean frame with neither on
screen, and the new one arrives. `LazyPanel` has to build the incoming panel, and
that costs exactly the frame the rule asks for.

**6. Only what is in focus may move.** Everything else holds still.

**7. A change with a before and an after is a journey, not a cross-fade.** If
one thing stops being selected and another starts, the honest drawing is one
object travelling between them — not two objects changing in opposite
directions on the same frame. A cross-fade says the state changed without
saying from what, so the eye has nothing to follow and the change reads as a
repaint. This is the rule the whole shell was breaking: the workspace pill
widened while the one you came from gave up its width, and the launcher row lit
its own fill while another put one out. `Traveller.qml` is the object; the
deformation along its direction of travel is not decoration but the cheapest
possible statement that it *went* there rather than being redrawn there.

## Surface types

Two of the rules above are wrong applied to everything. That was written here
first as a pair of exemptions, which was the wrong shape: an exemption is a
philosophical claim the next person has to be persuaded of, it has to be
re-argued every time, and it accumulates. A type is an API. A caller either
declares one or it does not.

| type | beats | for |
|---|---|---|
| `narrative` | 0 · 0.20 · 0.45 · 0.65 | anything that opens and tells you something |
| `acknowledge` | all zero | answers a key you just pressed |
| `continuous` | not sequenced | never arrives — cava, the bass glow, a spectrum |
| `ambient` | 0 · 0.12 · 0.12 · 0.12 | present, never the subject |

`acknowledge` is rule 3 turned into a type. On a volume or brightness key the
accent *is* the message, and holding it back by a beat turns a keypress into
lag — `Theme` says as much where `animFlick` is defined: not the shell
answering, the shell acknowledging.

`continuous` is rule 6 turned into a type. Applied literally, rule 6 stops the
bar island breathing with the bass and stops cava altogether — the two things on
this desktop that most read as alive, and the exact register the reference reel
wins in. `Theme` already carried the distinction that settles it:
`animFlick/Fast/Normal/Slow` are the shell *answering*, `animBusy/animBreath`
are a thing showing it is *running*. Rule 6 governs the first group only.

An unknown type falls back to `narrative`, not to zero. A surface that forgot to
declare itself should look overdressed rather than instant: the first is noticed
and fixed, the second is silently the old behaviour.

## State

Implemented:

- the beat vocabulary and `tempo`, all relative
- surface types, replacing the exemptions
- `Direction.stagger()`, moved out of `Theme` where it violated the contract
  line about timing policy — and where it was also the only number in the shell
  that stayed fixed while the tempo moved underneath it
- `Reveal.qml` plays the four beats. It contains no durations and no offsets;
  it asks `Direction` for the beats of its type. The accent beat is *exposed*
  as `accentProgress` rather than applied, because the wrapper cannot know
  which of its children carries the emphasis — without that the fourth beat
  would be unplayable and the sequence would be three beats pretending to be
  four.

  **One property per beat**, and it took a correction to get there. The content
  layer used to carry an opacity of its own as well as the travel. That layer
  holds every child a caller passes, so it *is* the surface the object beat
  fades — the two opacities multiplied, and because the inner one sat at zero
  until the content beat, the product was zero for the whole of the object
  beat. Beat 2 could not be seen by anyone. What every panel in this shell
  actually played was a scale nobody could see followed by a plain fade: four
  beats in the code, two on screen. Space is the scale, the object is the fade,
  the accent is exposed, the content is the travel, and no beat shares a
  property with another.
- Five consumers: `PanelChrome.qml` (and through it all seven system sheets),
  `DashCard.qml`, `DashControl.qml`, `Trail.qml` and `BarStrip.qml`.
  `DashCard` was the first, and is still the only one that binds the accent
  beat — its eyebrow rides `accentProgress`.
- `BarStrip.qml` is the one that matters most: the bar is on screen before
  anything else and was the only surface that never said hello. It arrives left,
  then right, then centre, so the accent lands last — rule 3, and also the build
  anyone would choose. No vertical slide: the layer surface is exactly as tall
  as the bar, so anything moved vertically is cropped rather than travelling,
  and the space beat is the scale.

  The bar is three islands again, and the choreography reads better on them than
  it did on the strip it briefly was. Each island is one `Reveal` holding its own
  surface *and* its own chips, so the thing that scales, fades and travels is the
  object you can see — where the strip grew as one surface while its contents
  slid about inside it, which is two events drawn as one thing. Three objects on
  three beats is what the rule was asking for.

  (This paragraph has now described `BarIsland.qml`, then `BarStrip.qml` as a
  single strip, then this. The shape keeps changing and the beats have not,
  which is the argument for keeping them somewhere other than in the file that
  draws them.)
- `Traveller.qml` and rule 7. Consumers: the workspace pill, which travels
  between fixed cells rather than being redrawn wide somewhere else, and the
  launcher's selection.
- the bar is a composer rather than a container. The clock is what is centred
  and the centre island composes itself around it, so a recording starting opens
  room to the clock's right instead of sliding the clock left by half a chip.
  Written without a `Behavior` on purpose: the island's width and the clock's
  position inside it come from one layout pass, so they move on the same frame
  and the clock is exactly still while the island widens under it. Measured
  since: the recorder chip forced in and the weather pushed along after it, and
  the clock lands on the same pixel it was on before.
- rule 8 — a change that crosses a row travels along it. `Direction.crossing`
  and `sweep()`, with the VPN node list as the consumer.
- `Traveller` will *place* rather than travel when the list under it is being
  rebuilt (`snapping`). The journey is a claim about continuity, and a list that
  did not exist a frame ago has none to claim. The launcher holds it for the
  length of its restage.
- `CascadeEntry.qml` is the one arrival every cascading list plays: fade and
  grow from `Theme.revealScale` after `Direction.stagger(index)`, on the
  durations and curves `Reveal` uses for its space and object beats. Consumers:
  the notification history, the toasts and the cheat sheet.

  It is deliberately **not** `Reveal`. A wrapper would add an Item and four
  Behaviors to every row of every list, and the beats it would buy are worth
  nothing there: a delegate is `ambient` by the table above — present, never the
  subject — and at that type the beats fall 15 to 42 ms apart depending on
  tempo, under the threshold at which a sequence reads as a sequence. What the
  lists actually needed was the *one* thing they each spelled out separately,
  and a list whose items come from a direction adds its travel inside the shared
  arrival rather than beside it, so the drop and the fade cannot come apart.

Not done:

- the `acknowledge` type has no consumer and cannot easily get one. The OSD is
  what it was written for, and the OSD spells its motion out because `Surface`
  samples the backdrop from a fixed `screenX`/`screenY` — a scale transform on
  an ancestor slides the sampled rectangle out from under the glass. The type is
  still worth having as the place the argument is written down, but it is an
  unplayed card and should be recorded as one rather than looking like coverage.

  (This was two bullets making the same point, one of them ending "for the reason
  above" and pointing at the other. Merged.)

## Whether any of it reached the screen

Everything above describes what the code does, and for most of the time it
described something nobody could see. Two faults, both fixed and both recorded
in `Progress.md` as B46 and B47, meant the beats were played into a void:

- the curves put nearly all of their travel in the first tenth of the duration,
  so each beat had finished before the next one began — four beats in the code,
  a single pop on screen
- and the arrival started on the frame the window was asked to map, which is
  50–60 ms before the compositor puts it there, so on every open after the first
  the whole sequence had run before anything was visible at all

The sequence is now measured rather than asserted. At 60fps: the dashboard, the
launcher, the OSD and the toast all show continuous arrivals of seven to ten
frames where the warm reopen used to be a single frame of hard cut. **A
choreography is a claim about what a person sees, and it has to be filmed to be
believed.**

Rule 7 is done in all four places it was wanted:

- the workspace pill and the launcher's selection, via `Traveller`
- `CcPager` — the detail page slides in from the right while the main view
  drifts 22% of the width the other way, rather than leaving at the same speed:
  "the page is what the eye should follow"
- the dashboard's three pages, which used to cross-fade. They lie in a row now
  and the row slides; the offset is the index difference, so the direction falls
  out of the arithmetic and a two-tab jump travels twice as far
