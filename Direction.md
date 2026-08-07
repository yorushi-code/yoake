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

Not done:

- **`Reveal` had no callers at all** before this. It was registered, documented
  as the thing that stops motion drifting, and used by nobody, while the panels
  each still hand-rolled their own `Behavior` pairs — the same failure as
  `partOfDay` computed and never read. `DashCard` is one consumer. `ActionMenu`,
  `VpnPanel`, `CcWifiPage`, `CcBluetoothPage` and the notification stack still
  spell their own motion out.
- the **rest** beat is defined and nothing enforces it. Rule 5 is currently an
  intention.
- the bar is still a container — three islands, each a `Row`. Rule 2 wants a
  composer: when the media widget appears the interval rhythm and the optical
  centre should recompose, not just reflow. That is a layer above this one, and
  it is the same work as the bar constructor from the very start of all this,
  approached from the other side.
