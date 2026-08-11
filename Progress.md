# Progress record

The brief this serves: bring the shell from "collection of widgets" to "coherent
living surface". Beautiful is not finished. Screenshots are not an acceptance
test. The architecture — Collectors → Context → Perception → Theme → Direction →
Presentation — is preserved, not replaced.

**Read this file first. Do not restart the audit from scratch. Do not undo
decisions already marked correct.**

Status keys: `IMPLEMENTED` / `PARTIAL` / `MISSING` / `WRONG`.

---

## Phases

| # | phase | state |
|---|---|---|
| 1 | Audit | IMPLEMENTED |
| 2 | Architecture map | IMPLEMENTED |
| 3 | Visual system | PARTIAL |
| 4 | Motion system | MISSING |
| 5 | Bar composition | MISSING |
| 6 | Media / player system | PARTIAL |
| 7 | Notifications | PARTIAL |
| 8 | System panels | MISSING |
| 9 | Performance | MISSING |
| 10 | Integration testing | MISSING |
| 11 | Visual polish | MISSING |
| 12 | Regression pass | MISSING |

---

## Standing corrections to earlier work

- **Do not copy the reference.** The previous pass drew too close to
  Serpantinum's visual language — coloured pill chips, its panel structure, its
  card shapes. Keep the *principles* (motion quality, staging, materiality,
  hierarchy, finish) and change the *forms*. If something reads as a direct
  borrowing, redo it.
- **Read the whole implementation before editing.** Rework.md §3.2 rule 0.
- **Compilation is the lowest bar.** Behaviour, interaction, motion,
  performance, hierarchy and reliability are the acceptance criteria.

---

## Phase 1 — Audit

Findings go here as they are established, each with a status and a file. Nothing
in this section is a fix; fixes are separate commits referencing the finding.

### Terminology correction

**`Mod+D` on this machine is the launcher**, not "show desktop" — see
`~/.config/niri/config.d/50-binds.kdl:15`. Every "Win+D" item in the brief is
therefore about *launcher open → close → open in rapid succession*, and about
panel open/close races generally. There is no show-desktop feature and one must
not be invented to satisfy a checklist.

### What is already correct — do not "fix" these

- **Motion timing is on the ladder.** Four numeric `duration:` literals exist in
  the whole tree and all four are the documented Perception → Theme Behaviors in
  `Theme.qml`. Zero `PauseAnimation` literals. The "hardcoded animation timing"
  item on the brief's list was closed by an earlier pass; re-tokenising it would
  be churn.
- **Toast focus.** `NotificationCenter` is the only surface with
  `WlrKeyboardFocus.OnDemand` besides the dashboard peek — a toast is visible
  without being focusable until clicked. Correct by construction; still needs
  verifying under a real fullscreen game.
- **`visible: opacity > 0`** is used in ten files and is the right guard. The
  fourteen files with a bare `opacity: 0` are almost all cascade entries inside
  a positioner, where occupying geometry from the first frame is deliberate —
  they are not the "hidden UI reserving geometry" bug. Check individually
  before touching any of them.

### Findings

**F1 — Notifications are centred. FIXED, see B4.**
`NotificationCenter.qml:204` anchors the toast window to `top` only, which
layer-shell centres horizontally. The file's own comment argues the centre is
"the only free column" because the desktop rail took the right side. The brief
overrules it: the centre is content territory. Needs a peripheral zone, and the
collision with the desktop rail and the bar's right cluster has to be solved
rather than dodged.

**F2 — Player selection exists and is unreachable. FIXED, see B5.**
`Media.pinned` / `Media.pin()` are real, and there are two selectors:
`BarMedia.qml:160` (buried in a right-click menu) and `DashMedia.qml:277`
(chips) — but `DashMedia` sits on the "Медиа" dashboard tab, which was deleted
in `043d542`. So the only visible selector was orphaned by this pass. The
fallback rule itself is sound (`pinned` → first playing → first known), but the
brief wants selection explicit, and right-click on a bar widget is not explicit.

**F3 — The chip vocabulary is a direct borrowing. FIXED, see phase 3.**
Saturated pastel pills with dark ink, one hue per domain, a coloured pill per
status: that is Serpantinum's visual signature, adopted almost literally in
`Chip.qml` + `Theme.tone()`. The *principle* (a mark should name its subject,
and colour should sort before reading) is worth keeping. The *form* has to
change. This is the single largest "looks copied" item and it is load-bearing
for the whole bar, so it belongs in phase 3 and must be planned, not improvised.

**F4 — Panel widths are magic numbers. PARTIAL.**
430, 460, 700, 520, 340, 320, 218 all appear as raw literals. Some are genuine
optical decisions; none of them is written down as one. Radii, spacing, type and
alpha are on ladders and these are not, so panels are the last place where a
number can drift unnoticed.

**F5 — Thirteen surfaces take `WlrKeyboardFocus.Exclusive`.**
Correct for a panel the user asked for, and untested during a fullscreen game.
Needs a real check: open one over a game and confirm the game keeps its input
and gets it back cleanly on close.

**F6 — `VpnNodeRow.qml` and `VpnSubscriptionRow.qml` were orphaned. FIXED, see B7.**
Originally:, along with
the subscription editor's reachability. Carried over from the earlier list; see
the VPN items below.

### Carried over

Closed in B7 below, except **group switching** — the panel still hardcodes
`Mihomo.primaryGroup` ("PROXY"). The old panel could show another group. Left
open deliberately: this machine has one group, so the feature cannot be verified
here, and shipping an unverifiable control is worse than a recorded gap.

## Phase 2 — Architecture map

Checked against the invariants in the brief rather than described in prose. The
finding is that the architecture holds; it did not need defending, it needed
verifying, and now it has been.

| invariant | verdict | evidence |
|---|---|---|
| Perception may filter input history | HOLDS | axes are read only to produce the Theme Bindings and the debug string; nothing reads a previous decision |
| Perception may not read its own outputs | HOLDS | no self-reference in `Perception.qml`; the smoothing lives in Theme's Behaviors, downstream, which is the whole point of the split |
| Theme owns tokens, not sequencing | HOLDS | no `stagger`, `beat`, `cascade` or `delay` in `Theme.qml` except comments recording that `stagger()` moved out |
| Direction owns sequencing, not state | HOLDS | zero references to CPU, battery, wifi, `Context` or `Perception` in `Direction.qml` |
| Veto may only remove cost | HOLDS | `_affordable` appears twice: its own definition and the `frost` binding. It reaches nothing else |
| Veto may not invent semantics | HOLDS | same evidence |
| Layout owns geometry, no second engine | HOLDS | four manual `x:`/`y:` arithmetic sites in 158 files, all optical centring (a slider handle, a digit in a tile, the bar's optical centre). Not an engine |
| Optical must not be the universal axis | HOLDS | `optical` drives `inkScale` only. Frost is not on an axis at all |
| Documentation describes reality | **VIOLATED, now fixed** | see below |

**A2 — `Theme.qml` claimed `frost <- optical`.** The code has bound frost to
`_affordable && frostWanted` for some time. That comment was the single most
misleading line in the file, because it is exactly the coupling the brief
forbids: it would talk the next reader into treating ink and frost as one
decision. They are not. Frost is a cost and a budget may take it; ink is
legibility and nothing may. Corrected in place, with the reason recorded so the
line cannot quietly come back.

**What this means for the phases below.** No architectural surgery is needed.
Everything remaining is presentation, composition, behaviour and reliability —
which is where the brief said the real problems were, and the map now supports
that rather than assuming it.

---

## Log

Newest last.

- **P3.1 — Chip redesigned.** The borrowed form (saturated pill, dark ink on
  colour, one hue per domain as the ground) is gone. Three classes now, and they
  differ structurally rather than by hue: *passive* is neutral ink with no rule,
  *live* is a domain-tinted glyph with a neutral label and a domain hairline
  underneath, *alert* is the only filled ground in the bar. Verified on screen:
  the rules form a row of ticks on one baseline, which scans better than ten
  pills at ten widths, and the muted-microphone alert is the single filled mark
  and needs nothing else to be found. Colour ranks again, because a coloured
  ground no longer appears while the machine is fine. Lint clean, log clean.

  Follow-ups from this decision are below.

- **P3.2 — One rule for colour inside a panel.** The selected `DeviceRow` and
  the chosen `Segmented` cell were each filled with the *domain's* hue, which
  put two different "this is the chosen one" colours in one panel and made each
  panel a differently-coloured product rather than one of six relatives. Both
  now fill with the shell's own accent. The domain survives where it does real
  work: tinting the glyph of a row that is not selected, and the liquid in a
  `LevelTile`, which is subject identity rather than choice.

  The rule, written once so it stops being re-decided: **accent means chosen,
  domain means what this is about, and no control holds both jobs.**

- **P3.3 — F4 closed. Sheet widths have a ladder.** `sheetList` 430,
  `sheetReading` 520, `sheetWide` 700, `sheetToast` 340, named by what they hold
  because they are decisions about line length rather than arithmetic. All eight
  panels moved onto it; VPN was 460 for no reason anyone recorded and is now on
  the list rung with the rest.

- **P3.4 — Popover has one measure.** Six callers passed 236, 240, 244, 244, 248
  and 264 — values inside 28px of each other, which is what a token looks like
  before anyone writes it down. `Theme.popoverWidth` 256, and it is a floor: the
  card still grows to its content. The notification card's inner column asked
  its parent for a width while being the thing that gave the parent its width;
  that is a loop, and its symptom is a row rendering at whatever Qt resolved
  first rather than an error. It measures against the card now.

- **P3.5 — Header toggles tint instead of filling.** The wifi and bluetooth
  power switches were filled with the domain hue, which put a second "chosen"
  colour directly above an accent-filled selected row. A header toggle reports
  an on/off state, and a live state in this shell is a tinted glyph on the
  surface's own ground. Verified: network and power panels now read as
  relatives, one selection colour each, domain surviving in the glyphs.

  **Phase 3 is still not finished.** Remaining:
  1. Spacing and radii sweep across the panels written this pass — they were
     built fast and never audited against the ladders as a set.
  2. Screenshot the bluetooth, media, weather and VPN panels; only audio,
     network and power have been seen since the colour change.
  3. Done — see B9.

- **B1 — Notifications never expired. FIXED.** Found by running the brief's own
  scenario rather than by reading: twenty at once, then wait. The card was still
  on screen eleven seconds later, and a single notification behaved the same, so
  it was not a grouping fault.

  Two bugs stacked, and the outer one hid the inner one.

  *The identity bug.* The countdown was created holding the notification it was
  born with, and grouping makes a card take over the newest message — so after
  the second message arrives, the timer's notification is no longer the one any
  card is showing, and dismissing "its" notification matches nothing. The reaper
  had the same fault. Both now work by the card's own id, which grouping
  preserves.

  *The bug underneath.* `property string key` against an entry id that is a
  number. QML converted it, and `t.id !== key` then compared `109` with `"109"`
  and matched nothing. The countdown fired on time, every time, and dismissed a
  card that did not exist.

  This is the shape of failure the brief is about, and it is worth keeping as
  the example: lint clean, log clean, config loaded, no error anywhere — and the
  feature simply did not work. It was only found by instrumenting the timer and
  watching it fire into nothing. Verified after the fix in both scenarios:
  single notification gone at 9s, fifteen grouped gone at 10s.

- **B2 — `parent` inside an animation, three times. FIXED.** Surfaced by a rapid
  panel toggle: `VpnPanel.qml:139` logged `ReferenceError: parent is not
  defined`. Swept the tree for the class and found two more, both silent.

  An animation is not a visual item, so it has no `parent`, and QML says so only
  when the expression is evaluated — which is why two of the three never
  appeared in a log at all.

  - `VpnPanel` — `onStopped: parent.opacity = 1` wrote to nothing, so a tunnel
    that finished connecting kept a half-faded icon until the panel was rebuilt.
  - `LockScreen` — `target: parent` on the pip that marks a typed character.
    It has never once popped in.
  - `WallpaperTile` — `running: parent.visible` on a *property-value-source*
    animation, which runs by default. A broken `running` binding therefore left
    it shimmering forever behind every thumbnail that had already loaded, in a
    grid of them. The worst of the three and the only one with a cost.

  Also here: `VpnPanel`'s header toggle still filled with the domain hue and now
  follows P3.5 like the other two.

- **B3 — Rapid panel toggling is clean.** Ten open/close cycles in a row on the
  audio panel, then a close: nothing stuck, nothing half-drawn, no stale window,
  log clean. This scenario passes and does not need revisiting.

- **M1 — Measured, not assumed.** Wallpaper picker open: 48.3% of a core, which
  is thumbnail decoding and is over the contract while it lasts. Two seconds
  after closing: 35.6%. Twelve seconds after closing: 7.0%. So the picker leaves
  nothing running — the tail is decode, not a leak. Recorded because "probably
  fine" is not an answer and the number was worth having.

- **B4 — Toasts moved out of the centre.** They now arrive under the right end
  of the strip, where the bell is, which is the rule every sheet in this shell
  already follows: a surface comes from the chip that owns it. The centre is
  where content is, and the old comment defending it was solving a collision
  with the desktop rail by moving into the one column that is never free.

  The rail can still be under a toast on a bare desktop, and that is left alone
  on purpose. The rail is a widget the user drags and its position is theirs; a
  toast that dodged it would be guessing at a layout nobody asked it to know,
  and two unrelated surfaces would have to know about each other to do it. Six
  seconds across the clock is a smaller cost than covering the middle of the
  screen every time.

  **Broke the shell doing it** — the edit that replaced the comment block also
  swallowed the `PanelWindow {` opening and its layer declaration, so the
  configuration failed to load for about a minute. Caught by the log check that
  follows every change, restored, `Configuration Loaded` confirmed. Recorded
  because the night rules say to record it, and because it is the argument for
  checking the log after every single edit rather than at the end of a batch.

- **B5 — Player selection is explicit again.** The shell picked a player on a
  heuristic -- pinned, else playing, else the first it had heard of -- and never
  said which, or that there was a choice; and the only visible selector had been
  orphaned when the Медиа dashboard tab was deleted. The media panel now carries
  a row of the live players with the controlled one marked, and clicking the
  chosen one releases the pin and hands the shell back its own judgement.

  Shown only when there is more than one. A list of one is not a choice, and it
  would be a row of chrome asking to be read every time.

  Also: a pinned player that goes away used to leave a dangling choice. `player`
  already fell back correctly so nothing looked wrong, but the pin survived and
  would have silently re-taken control if the same object ever came back. It is
  cleared the moment the player leaves — honoured or forgotten, never haunting.

  **Not verified with two players.** Only Firefox is alive on this machine
  tonight and starting a second one would mean making noise while the user
  sleeps. `playerctld` is installed and would appear as a second MPRIS name;
  that is the way to check it in the morning.

- **B6 — Two defects on the panel's own face, found by looking at it.**
  The disc was blank whenever a track reported no artwork, which a browser
  playing a stream does routinely — an empty circle reads as art that failed
  rather than as a record with no sleeve. It carries a music glyph now, and the
  spindle hole is hidden while it does, because a hole punched through the
  middle of the placeholder made the two read as neither.

  And the source line said "VIA Mozilla org.mozilla.firefox", because that is
  literally what Firefox puts in its MPRIS `Identity`. Dropping a reverse-DNS
  token is not guessing at what an application meant; it is refusing to print a
  field the application filled in badly.

- **B7 — The VPN panel can build a list again, not just operate one.** The
  rewrite had left it able to start, refresh and delete nothing — adding a
  subscription was gone with the editor, and so were removal and per-subscription
  core switching. `VpnSubscriptionEditor` is wired back into the Подписки tab,
  and refresh / core / delete live in a right-click menu, which is where every
  other list of actions in this shell already goes: three actions do not fit in
  a row's two gestures.

  `VpnNodeRow.qml` and `VpnSubscriptionRow.qml` are deleted along with their
  qmldir entries. `DeviceRow` covers what the first did and the menu covers what
  the second did, and a registered type that nothing instantiates is a trap for
  whoever reads the file list next.

  Verified on screen: the node list renders with types and the restored egress
  row reads `2a12:bec4:1b50:2fe::2 · United Kingdom`.

- **B8 — The weather panel stated things the machine did not know.** Only the
  empty row was gated on `Weather.valid`; the reading itself was not. So before
  the first fetch landed, and after any failure, the panel drew a complete and
  confident **0°** with a blank description and a blank place, and three
  key-values reading 0°, 0 км/ч, 0%. A designed surface asserting a fact nobody
  had is worse than an empty one, and it is exactly the "beautiful state that
  does not match the state of the system" the brief names.

  Everything that is a reading is now gated on there being one, and the empty
  case is three states rather than one: looking for a location, waiting for the
  fetch, or failed — and only the last carries an action, because only the last
  has one. Verified with data present: the ready panel is unchanged.

  **Not verified:** the error branch itself. Forcing it means breaking the
  network, which the night rules forbid. The loading branch is transient and was
  not caught on camera either. Both are one screenshot each with the network
  briefly down, in the morning.

- **B9 — Settings and acts stopped sharing a visual class.** A power profile is
  a choice that persists and shows which one is current; a session action is a
  verb that happens once and takes the panel with it. Drawn identically, the
  four verbs read as four more settings, which is how "Выключение" ends up
  looking like something you can browse.

  A rule and a caption separate them now, and `DeviceRow` learned one property:
  `danger`. Reboot and power-off tint alert **under the pointer** rather than
  permanently — a row that is red before anyone has reached for it is a row that
  shouts at a person for opening a panel. Caught on camera with the pointer over
  Перезагрузка, so the state is verified rather than assumed.

