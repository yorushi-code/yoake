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
- `DashCard.qml` is the first real consumer. Every dashboard card now assembles
  instead of appearing, and its eyebrow is bound to the accent beat.
- `BarIsland.qml` is the second, and the one that matters most: the bar is the
  surface that is on screen before anything else and was the only one that
  never said hello. Left, then right, then centre, so the accent lands last —
  which is rule 3 and also the build anyone would choose. No slide: the layer
  surface is exactly as tall as the island, so anything moved vertically is
  cropped rather than travelling, and the space beat is the scale.
- `Traveller.qml` and rule 7. Consumers: the workspace pill, which travels
  between fixed cells rather than being redrawn wide somewhere else, and the
  launcher's selection.
- the bar is a composer rather than a container. The clock is what is centred
  and the island grows around it, so starting music opens room to the clock's
  left instead of sliding the clock right by half a player's width. Written
  without a `Behavior` on purpose: the island's `x` and the clock's position
  inside it come from one layout pass, so they move on the same frame and the
  clock is exactly still while the island widens under it.

Not done:

- **`Reveal` had one caller** and now has two. `ActionMenu`, `VpnPanel`,
  `CcWifiPage`, `CcBluetoothPage` and the notification stack still spell their
  own motion out.
- the **rest** beat is defined and nothing enforces it. Rule 5 is currently an
  intention.
- rule 7 has two consumers and at least two more places that want it: the
  control centre's pager, where a page slides in and the main view drifts, and
  the dashboard's own navigation.
