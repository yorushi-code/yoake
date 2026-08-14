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
| 3 | Visual system | IMPLEMENTED |
| 4 | Motion system | IMPLEMENTED |
| 5 | Bar composition | IMPLEMENTED |
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


- **B10 — The launcher printed the same word forty times.** Every row carried a
  kind badge on the right: `прил.`, `прил.`, `прил.`, all the way down. The row
  type was written for a list of four kinds and says so in its own comment — but
  a prefix selects exactly one generator, so every list the launcher could
  produce was homogeneous by construction and the badge could never once tell
  two rows apart. Forty labels answering nothing, in the one surface that opens
  on a keystroke.

  Two ways out: delete the badge, or make its premise true. The premise is the
  better product and the row type was already built for it, so it is finished
  rather than removed. A plain query now searches applications, open windows and
  shell actions together — searching for firefox while firefox is open no longer
  hides the window — and the three prefixes stay for asking one list directly.

  Ranking had to become one scale for that to mean anything. The substring
  ladder moved out of `score()` into `_textScore()` and is shared; subsequence
  matching stayed behind, because "every letter in order" earns its place
  against a short application name and makes any sixty-character window title
  match almost any query. Ties go to the kind you more often meant: an
  application and its own window score identically on their shared name, and
  launching is the commoner intent, so the app leads and the window sits under
  it. The window you are already looking at drops below everything — switching
  to where you already are is the one row that can do nothing.

  An empty query is still applications only. Nothing has been typed, so there is
  no ranking to speak of, and a list of every open window is noise.

  The badge appears exactly when the list holds more than one kind. Verified on
  screen both ways: `fire` returns Firefox, Fedora Media Writer and the open
  Firefox window with two kinds marked; an empty query returns a clean right
  edge with no badges at all.

- **B11 — The selection marker travelled through lists that no longer existed.**
  Caught on camera by accident: a screenshot taken 1.6s after opening the
  launcher had the marker parked halfway between two rows, mid-journey, with no
  row selected.

  `Traveller`'s journey is a sentence about continuity — *the thing you had is
  now this thing instead* — and `_primed` already refuses to say it on the very
  first placement. But the launcher window is hidden, not destroyed, so every
  reopen was primed: select the eighth row, close, reopen, and the marker glides
  up through eight rows of a list that was built a frame ago. Typing did it too,
  since a new query resets the selection to the top.

  `Traveller` learned `snapping`, which stands the four geometry Behaviors down
  and suppresses the deformation, and the launcher holds it for exactly the
  window in which the list is being rebuilt — `root.cascading`, which already
  existed for the row entrance and is already the right length, because rows
  arriving in a cascade keep moving the slot for several frames after the query
  changed. Outside that window the marker still travels, because then the
  selection really did move within a list that stayed put.

  Checked the other three callers: workspaces, dashboard tabs and `Segmented`
  all mark a stable set, so their journeys are always true and none of them
  wants this.

- **M2 — A 45% reading that was not a bug.** Measured the shell at 44.7 / 45.3 /
  44.8 across three samples with every panel closed and music playing, against a
  contract of 20. Followed it into `Cava` and its six consumers and had a
  rewrite half-planned — twenty-eight `Glow` items in `WidgetSpectrum` whose
  amount changes on every cava frame is exactly what an expensive shell looks
  like.

  Then measured again at rest: 14.9 / 8.0 / 7.0. Open the launcher and hold it
  open: 9.9 / 6.0 / 5.0. The spike was my own test load — repeated screenshots,
  synthetic input, the launcher opening and closing in a loop — and it is not
  reproducible.

  Reading the code afterwards showed why the rewrite would have been wrong.
  `Glow` is a `RectangularShadow` with fixed geometry that animates opacity and
  grows by transform, precisely so the blur is rasterised once instead of per
  frame, and the file records the 4.4-points-of-a-core measurement that taught
  it. `Cava` smooths the fall itself rather than through 42 per-bar Behaviors,
  and `WidgetSpectrum` drops its delegates rather than hiding them, both with
  the measurement written next to them. Three rounds of this fight are already
  won. **One number is not a measurement.** Recorded so the next pass does not
  start the same rewrite from the same single sample.

- **E1 — Synthetic keyboard input is not safe on this machine, and stopped.**
  `wtype` was used to type into the launcher, which worked once and then did
  not: the layout was on Russian, six `wtype -k Down` presses arrived as six
  Cyrillic characters instead of arrow keys, and the stray text landed in
  whatever surface held focus — at one point a Telegram window. Nothing was
  sent, and no further synthetic input was used.

  The rule for the rest of this work: drive the UI through `qs ipc call toggles`
  and read it with `grim`. Anything that needs a keystroke waits for the user.
  It also cost a measurement — see M2, whose spike was partly this.

- **B12 — Three panels printed the same sentence twice.** Found by finally
  looking at the bluetooth panel, which phase 3 had never screenshotted: the
  title said "Ничего не подключено" and the empty row a hundred and forty pixels
  below said "Ничего не подключено". One short panel, one sentence, twice.

  The cause is the same in all three: the header title falls back to a *state*
  when there is no subject to name, and the body reports that same state
  underneath. `SheetHeader` names what the panel is about; `EmptyRow` says what
  it is doing, and does it per page, which one title never could.

  - Bluetooth — the subject with nothing connected is the radio itself, so the
    title is "Bluetooth" over the adapter's name.
  - Network — "Wi-Fi выключен" was duplicated word for word; the title is
    "Wi-Fi" now. "Не подключено" stays, because with Wi-Fi on the body is a list
    of networks rather than an empty row and nothing repeats it.
  - VPN — "Выключен" over "Туннель выключен" became "VPN". "Подключаюсь…" stays
    a title: it is not a state the body reports, it is an operation in flight,
    and the header is where this shell puts what is currently happening.

  Verified on screen: the panel reads Bluetooth / fedora / Ничего не подключено,
  which is subject, identity, state, in that order and each said once.

- **B13 — Phase 3 closed: the sweep, and what it actually found.** The remaining
  phase-3 item assumed the panels written this pass were built too fast to be on
  the ladders. Checked rather than assumed, and the assumption was wrong.

  *Radii.* Eighteen raw `radius:` literals in the tree and every one of them is
  half of its own width — a 3px rule at 1.5, a 1.5px marker at 0.75, a 13px pill
  at 6.5. Those are geometry written out, not drift. The ladder holds.

  *Panel spacing.* Zero raw spacing or margin literals in all seven panels
  rewritten this pass. Nothing to sweep.

  *What the sweep did find*, in the places nobody was looking:

  1. **The pair gap was off the ladder.** Nineteen sites set `spacing: 1` or
     `spacing: 2` on a Column holding a name over the line that belongs to it —
     eleven at 1, six at 2, chosen by eye every time. It is the F4 pattern
     exactly: values inside a pixel of each other is what a token looks like
     before anyone writes it down. Worse, it was the one gap in the shell that
     did not scale with density while every other one did. `Theme.gapPair`, and
     all nineteen moved onto it. `BarMedia`'s spectrum gap was left alone: two
     pixels between two-pixel bars is geometry, not typography.
  2. **`NotificationPanel` was the one file with real drift** — ten raw margins
     against zero in the seven panels. Its header sat sixteen pixels from the
     left edge and its list of cards ten, so the title and the cards it names
     did not share a left edge. Close enough that nobody could name it, far
     enough to look untidy at every scroll position. Both on `Theme.gapCard`
     now, and the header's other three literals onto `rowPad` and `spacing`.
     Verified against a real notification.
  3. **The B12 defect again, in the panel I had not opened.** With nothing
     unread the notification centre's title read "Нет уведомлений", above a
     sleeping cat, above the word "Тихо" — three statements of one fact in a
     panel with nothing in it. The title is the subject now.

  The card internals in `NotificationPanel` (9/9 vertical, 18 left after the
  urgency rule, 10 right) are left as literals deliberately: they are internally
  consistent and balanced around a 3px rule, and snapping them to the ladder
  without seeing a long history on screen would be moving numbers by feel.

- **M3 — Verify the reload before believing the screenshot.** Edited
  `NotificationPanel`, opened it twice, and both screenshots showed the old
  text. The string was gone from the source. `touch` on the same file produced
  `Reloading configuration…` immediately, and then the change was there.

  Whatever the watcher missed, the lesson is procedural and cost twenty minutes:
  `qs log | grep -c "Configuration Loaded"` before and after, and only then read
  the screenshot. A screenshot of a shell that has not reloaded is a screenshot
  of the previous edit.

- **B14 — Panels seen, and one finding left open.** Bluetooth, media, the
  notification centre and VPN have now been looked at since the colour change.
  All four follow the rule: accent fills the chosen node, the chosen segment and
  the chosen preset; the domain survives in the glyphs. The VPN panel's egress
  row reads `2a12:bec4:1b50:2fe::2 · United Kingdom` and its node list marks
  `direct policy` as current.

  **Open finding, not fixed.** The VPN panel ends with the core's raw log tail,
  in red, wrapped over three lines: `-0400 2026-08-12 07:58:39 ERROR
  [2182309428 16m56s] connection: open connection to 149.154.167.41:443 using
  outbound/vless[direct policy]: read tcp …: network is unreachable`. It is the
  only undesigned surface left in the shell — a mangled timestamp, a goroutine
  id and a port, pasted under a composed panel. It is also the most useful thing
  on that panel when the tunnel is broken, which it was at the time, and
  "Задержка: нет ответа" agreed with it. Reshaping it means deciding what a
  person needs from a core error without throwing away the line an operator
  needs, and that is a decision to make deliberately rather than at the end of a
  night shift.

  Also unverified still: the media panel's disc was empty of artwork in one
  capture and correct in the next two, both times matching what the desktop card
  showed. That was a reload transient, not a defect.

## Phase 4 — Motion system

- **B15 — Two of the four beats never played.** `Reveal` is the shell's arrival
  wrapper and it is where the four beats live: space, object, accent, content.
  Read end to end, it had one layer too many carrying opacity.

  The content layer holds every child a caller passes — `default property alias
  content: contentLayer.children` — so it *is* the surface that the object beat
  fades. It carried an opacity of its own as well, and the two multiplied.
  Because the inner one sat at zero until the content beat began, the product
  was zero for the whole of the object beat.

  The arithmetic, at tempo 220: the scale starts at 0 over `animSlow` 420; the
  object fade starts at 44 over `animNormal`; the content fade starts at 143.
  Nothing is visible at all until 143ms, by which point a spring curve has taken
  the scale from 0.90 to about 0.98. So the space beat happened where nobody
  could see it and the object beat could not be seen by anyone at any tempo.
  What every panel in this shell actually played was an invisible scale followed
  by a plain fade: four beats in the code, two on screen.

  One property per beat now — space is the scale, the object is the fade, the
  accent is exposed, the content is the travel. The file's own comment for the
  content beat already said it was "the only beat that travels"; the opacity was
  the accident. This reaches all seven system sheets through `PanelChrome`, plus
  `DashCard`, `DashControl`, `Trail` and `BarStrip`.

  **Not verified on screen.** The proof here is arithmetic, which is sound, but
  a 350ms arrival cannot be caught with `grim` bursts and the machine was in use.
  One slow-tempo capture in the morning: `qs ipc call perception force temporal
  1.0`, open a panel, capture, then `qs ipc call perception auto`.

- **B16 — `Direction.md` described a bar that no longer exists.** Its State
  section named `BarIsland.qml` as the second and most important `Reveal`
  consumer. That file was deleted when the bar became one strip. It also said
  `Reveal` had two callers; it has five. Same class as A2 — the code was right
  and the document was talking about a previous version of the shell, which is
  worse than no document because it is believed.

  Rewritten to reality, including the beat correction above, rule 8, and
  `Traveller.snapping`. The "Not done" list is now accurate: the list cascades,
  the unenforced rest beat, and the two remaining places that want rule 7.

- **F5 — evidence at last, and it is not good.** A fullscreen game (DDNet) was
  running when a panel was opened over it by IPC. Two seconds later the
  screenshot showed the game and no panel. Every sheet is on `WlrLayer.Overlay`,
  which is above a fullscreen window and is exactly the reason `Launcher` gives
  for not using `Top` — so the panel should have been there.

  Not chased further: the user was in a live match and a surface that takes
  `WlrKeyboardFocus.Exclusive` would have taken their keyboard mid-game. One
  observation, no confirmation, and the wrong moment to experiment.

  The suspect is in `Toggles.holdsFocus`, which names only the dashboard and the
  launcher. The seven sheets are not in it, so the compositor's `attentionMoved`
  runs `closeTransient()` on them — and `Niri._applyWindowFocusChanged` ignores
  a *null* focus, which is what opening a layer surface normally produces, but a
  fullscreen game may produce a real window id instead. If so, the sheet closes
  itself on the frame it opens.

  **Next concrete action**, with the machine free: start any window fullscreen,
  run `qs ipc call toggles panel audio`, and watch `qs ipc call context state`
  for the focus field while capturing. If the panel closes itself, the fix is
  one line — the sheets belong in `holdsFocus` for the same reason the dashboard
  does.

- **M4 — Measured while gaming, and M2 repeated itself.** Spot readings during
  the game gave 39.6 / 44.2 / 45.8, then 54.4 / 49.2 / 47.8 — against a game
  costing 20%. A shell more expensive than the game it is sitting behind would
  be a serious defect.

  Sampled properly instead, ten samples at three seconds: **7.0 – 9.9%**, steady.
  The spikes were my own IPC calls, screenshots and a panel opening and closing.
  Occlusion is working, which is why: `qs ipc call wallpaper state` reports
  `desktopVisible=false` and `occluded={"eDP-1":true}` with the game up, so the
  wallpaper and all twenty-eight spectrum delegates are dropped rather than
  drawn behind an opaque window.

  This is the second time a spot reading nearly started a rewrite. Sampling is
  not optional.

  **Recorded, not chased: RSS is 1.45 GB.** Stable, not a spike, and large for a
  shell. Wallpaper decoding, album art and the icon cache are the candidates.
  Needs a proper look with the machine free, not a guess at night.

**Phase 4 remaining, in order:**
1. The list cascades onto `Reveal` — `ActionMenu`, `CcWifiPage`,
   `CcBluetoothPage`, `CheatSheet`, `NotificationPanel`, `NotificationCenter`.
   Each currently runs a `ParallelAnimation` of two `SequentialAnimation`s that
   separately wait out the same `Direction.stagger(index)`, so a card arrives as
   one event instead of four. `Reveal` takes `delay` for exactly this. Mechanical
   but it changes each delegate's layout tree, so it needs a screen.
2. Rule 5: the `rest` beat is defined and nothing enforces it.
3. Rule 7 in the control centre's pager and the dashboard's navigation.

- **B17 — Seven surfaces entered at seven different sizes.** `PanelChrome`'s own
  header comment has said "0.88, 0.90, 0.94 and revealScale — four answers to a
  question that has one" for some time. Counted properly it is worse than four:
  0.80, 0.88, 0.90, 0.92, 0.92, 0.94, 0.94, and every one of them was written
  meaning "the panels' entrance language".

  `Reveal` exists to stop this drift and it did — for the five surfaces that go
  through it. The menus, the popover, the tooltip, the toasts, the history cards,
  the cheat sheet and the OSD all spell their own entrance out, so the token
  never reached them. All seven are on `Theme.revealScale` now, and the token
  carries the count so the next person can see what it is for.

  Left alone deliberately: `MenuItemRow`'s 0.4 and `BarWorkspaces`' 0.6. A check
  mark popping in and a numeral arriving on the content beat are not surface
  entrances, and the second is tuned against the pill it lands on.

  The worst of them was the OSD at 0.80 — the largest pop in the shell, spent on
  the surface that should announce itself least. It also had no way to say that
  its beats are all zero *on purpose*: `Direction`'s `acknowledge` type is
  documented as existing for exactly this surface and has had no consumer at all.
  It cannot become one without changing shape — `Surface` samples the backdrop
  from a fixed `screenX`/`screenY` and a scale transform on an ancestor slides
  the sampled rectangle out from under the glass, which is why the OSD spells
  its entrance out in the first place. Verified in `Surface.qml`: `screenX` and
  `screenY` are passed straight to `FrostedBackground`. So the reason is written
  down in the file instead, where the next reader will look.

  **Not verified on screen.** `qs ipc call osd brightness` only announces a
  reading that changed, so the OSD never appeared for the capture. One volume key
  in the morning shows it.

- **A3 — Rule 1 holds; checked rather than assumed.** Walked every `.qml` file
  counting how many properties a single item animates simultaneously — four or
  more is where "a space rearranging itself" turns into a demo effect. Four sites
  in the tree, and all four are one event rather than several:

  | site | properties | verdict |
  |---|---|---|
  | `GeneratedColors` | eleven colours | one palette change, not eleven objects |
  | `Theme` | the four Perception axes | the documented smoothing, downstream of the split |
  | `Traveller` | opacity, x, y, width, height | one marker: the journey, its slot, its presence — and the size settles faster than the position on purpose |
  | `BarWorkspaces` dot | color, width, scale, opacity | four different triggers that never coincide: window count, focus, hover |

  `BarWorkspaces` is also the one place outside `Reveal` that plays a beat
  correctly: the workspace numeral is held to `Direction.beatContent` so it
  confirms the arrival instead of announcing it.

- **B18 — Rule 7 finished, and one of the two places already had it.**
  `Direction.md` listed the control centre's pager and the dashboard's
  navigation as wanting rule 7. `CcPager` has had it all along — the detail page
  slides in from the right while the main view drifts 22% of the width the other
  way rather than leaving at the same speed, with the reason written beside it:
  "the page is what the eye should follow". The document was stale again.

  The dashboard genuinely was cross-fading. Three pages, each
  `opacity: root.tab === N ? 1 : 0` with a Behavior, so one went down while
  another came up on the same frame. The tab marker travelled and the content
  did not, which means half the navigation said "you moved right" and the other
  half said "something was repainted".

  They are three adjacent places, so they lie in a row and the row slides. The
  offset is `(N - tab) * width * 0.10` on a `Translate`, so the direction is
  never tracked or stored — going back moves the other way because the
  arithmetic does, and a two-tab jump travels twice as far because it is twice
  as far. A transform rather than `x` because the pages are anchor-filled and
  anchors win against a plain x; it is also the cheaper of the two. Verified on
  screen at rest: the current page sits exactly centred.

- **B19 — A finding that was wrong, and how it got that far.** For most of an
  hour this file was going to record that niri draws a fullscreen window above
  every layer surface, that the shell is therefore invisible under one, and that
  it burns a third of a core drawing frames nobody receives. Two observations
  supported it: a panel opened over a fullscreen DDNet match did not appear, and
  the dashboard opened over a fullscreen video did not appear. A CPU measurement
  seemed to confirm the panel was alive and unseen — 5% idle against 30% with the
  dashboard "open".

  All of it was wrong, and the launcher disproved it in one screenshot: it draws
  over the same fullscreen video perfectly. So does the dashboard.

  The cause was in the test, not the shell. `Toggles.dash(page)` toggles, so
  stepping `overview → control → desks` opened, **closed**, and opened again —
  and the frame I read was the middle one. The dashboard was never hidden; it
  was shut, by me, and I photographed the shutting and called it a compositor.

  Two lessons, both procedural and both cheap:
  1. **A negative observation needs a positive control.** "The panel is not
     there" means nothing until something else known-good is put in the same
     place under the same conditions. One launcher screenshot would have ended
     this at the start.
  2. **Read the tool before trusting the test.** `dash()` is one line and says
     `exclusive()`, which is named for what it does.

  The DDNet observation is still unexplained — that call had no toggle-parity
  trap. It stays open as the only live part of F5. **Next concrete action:** with
  a fullscreen game up, open the *launcher* first as the control, then a sheet,
  and compare.

- **B20 — Asking for a page closed the panel.** Falling out of B19: `dash(page)`
  toggled the dashboard unconditionally, so asking for a page that was not the
  one showing closed the panel and left the page selected behind it. The load
  widget opens Обзор; the shell menu's "Управление" then shuts the dashboard;
  getting to the page you asked for takes two goes. Three callers had it —
  `BarLoad`, `ShellActions` and the IPC.

  `toggleSheet` has been correct since the sheets were written: the same name
  closes, a different name switches. `dash` is that gesture on a panel whose
  siblings are pages, and now behaves the same way. An unknown page does nothing
  rather than toggling the panel on a name the shell does not have; `dashboard()`
  remains the entry point for toggling without choosing.

  Verified on screen: open on Обзор, ask for Управление, the panel stays up and
  shows Управление; ask for Управление again and it closes.

- **M5 — Check which file you appended to.** The B18 and B19 entries were written
  while the shell's working directory had drifted to the scratch directory, so
  they landed in a `Progress.md` that is not this one, and the commit that should
  have carried them carried only the code. Found by grepping for an entry that
  should have existed. Same family as M3: the check is cheap, the silence is
  total, and `cd` into the project explicitly at the start of every command that
  writes.

- **B21 — Three lists spelled the same arrival, and waited for it seven times.**
  Phase 4's recorded next action was to put the list cascades on `Reveal`. Doing
  it would have been wrong, and working out why was the useful part.

  What the six cascading lists actually had:

  | list | properties | pauses |
  |---|---|---|
  | notification history | opacity, scale | 2 |
  | cheat sheet categories | opacity, scale | 2 |
  | toasts | opacity, scale, a `Translate` y | 3 |
  | action menu | opacity | 1 |
  | wifi page, bluetooth page | opacity, via a Behavior | 1 |

  Every pause counts the same `Direction.stagger(index)`. Seven timers across
  three lists for three delays — three chances for the parts of one arrival to
  come apart, and three animation objects built and torn down per delegate for a
  job that needs one. They had drifted the usual quiet way too: the toasts grew
  over `animSlow` with the big spring, the other two over `animNormal` with the
  small one, all three meaning "the entrance the panels have".

  `CascadeEntry.qml` is that sentence written once — one wait, then opacity and
  scale in parallel, on the durations and curves `Reveal` plays for its space and
  object beats. Anything declared inside it joins that parallel group, which is
  how the toasts keep their drop from under the bar without a second clock.

  **Why not `Reveal`.** It would add an Item and four Behaviors to every row of
  every list, and buy beats that cannot be seen. A delegate is `ambient` by
  Direction's own table — present, never the subject — and ambient's beats are
  0 and 0.12 of a tempo, which at the range Perception can reach is 15 to 42 ms
  apart: under the threshold at which a sequence reads as a sequence. Wrapping
  in `narrative` would be worse: each card would take ~200ms to arrive while
  cards are staggered 19ms apart, so ten of them would be mid-arrival at once,
  which is mush. The coherence was worth having. The layer was not.

  The action menu and the two control-centre pages were left alone: they already
  wait once, and converting them would *add* a scale pop they do not have. That
  disagreement — some list rows grow, some only fade — is real and is recorded in
  `Direction.md` as wanting a decision rather than a sweep.

  Verified on screen, all three: four history cards arrived and sit aligned with
  their header; a group of toasts arrived under the bar with its `+2` badge; the
  cheat sheet's five columns of categories all landed. Test notifications cleared
  afterwards.

- **B22 — A row inside a surface that grew was growing again.** `Direction.md`
  recorded, after B21, that list rows disagree about whether they scale: the
  notification history, the toasts and the cheat sheet faded *and* grew, the
  wifi and bluetooth pages only faded, "both defensible and one of them wrong".
  It is not a matter of taste. It is the `Reveal` defect one level up.

  `PanelChrome` gives every panel a `Reveal` that grows it from
  `Theme.revealScale`. A delegate inside that also grew from `Theme.revealScale`
  composed with it: **the card began at 0.81 of its size**, and one visual
  dimension had two animations owning it, agreeing only by luck. Checked rather
  than assumed — `NotificationPanel` binds `shown: win.open` and `CheatSheet`
  binds `shown: root.open`, so both chromes really do transition.

  The rule, written down once: **the surface owns its size; a row inside it
  fades, and travels if it comes from somewhere.** Under it everything lines up
  and nothing is left to preference — the wifi and bluetooth rows were right all
  along, and so were the action menu's.

  The toasts are the exception that proves it, and the reason is in the code:
  their `PanelChrome` never sets `shown`, and it defaults to `true`, so the
  `Reveal` inside is born shown and never transitions. Nothing else animates a
  toast's size, so the toast declares the grow itself — inside the shared
  arrival, after the one wait, beside its drop from under the bar.

  Verified on screen, all three: four history cards at full size and aligned
  with their header, a grouped toast with its `+2` badge, the cheat sheet's
  columns intact. Test notifications cleared.

- **A4 — Rule 5 is an authoring rule, not a missing feature.** `Direction.md`
  has listed "the rest beat is defined and nothing enforces it" as outstanding.
  Enforcing it globally would mean a scheduler that holds animations back until
  the last large movement has settled — a second engine, which the brief forbids
  for geometry and which would be worse here, because it would sit between every
  surface and its own motion.

  The one interaction where it plainly applies was checked instead: switching
  sheets. `toggleSheet` closes the old one and opens the new one on the same
  frame, which reads as a rule 1 violation waiting to happen. Captured at forced
  slow tempo (`perception force temporal 1.0`, tempo 352ms): the audio panel
  leaves, there is a clean frame with neither panel on screen, and then the
  network panel arrives at partial opacity. **No overlap.** The gap comes from
  `LazyPanel` having to build the incoming panel, which costs the frame that
  rule 5 asks for.

  So the rule holds where it matters, by construction rather than by
  enforcement, and it is written in `Direction.md` as what it is: a rule authors
  obey when they write a sequence, like rules 2 and 3, not a mechanism.

**Phase 4 closed.** What it consisted of, so the next pass does not reopen it:

| item | outcome |
|---|---|
| `Reveal` plays four beats | B15 — two of them could not be seen; one property per beat now |
| documentation describes the motion system | B16 and the updates after it |
| entrance scale | B17 — seven answers became one |
| rule 1, no demo effects | A3 — checked across every file, four sites, all one event |
| rule 5, rest | A4 — an authoring rule, verified where it applies, not a mechanism |
| rule 7, journeys not cross-fades | B18 — all four places, dashboard was the last |
| list cascades share one arrival | B21 — one wait instead of seven |
| one owner per property | B22 — the surface owns its size |

Left open on purpose, with the argument recorded in `Direction.md`: the
`acknowledge` surface type has no consumer and cannot easily get one, because
the OSD it was written for cannot be wrapped without moving the rectangle
`Surface` samples its frost from.

## Phase 5 — Bar composition

- **B23 — A chip was loud unless it said otherwise.** `Chip.live` defaulted to
  `true`, so the loudest of the three classes — domain-tinted glyph, domain rule
  underneath — was what a widget got for saying nothing about its subject. One
  widget had said nothing: the battery has carried a permanent power-coloured
  rule since the classes were written, because a rule under a percentage looks
  deliberate and nobody caught it.

  Counted on screen before the change: five marks in a 250px cluster — mauve
  under the VPN, green under the network, yellow-green under the battery, amber
  under the bell, and one filled alert. Colour was supposed to rank; four rules
  at once rank nothing.

  `Reveal` defaults the other way on purpose, and the reasoning is written there:
  a surface that forgot to declare itself should look overdressed, because
  overdressed gets noticed and fixed. That argument fails here on its own terms —
  this *was* overdressed, for weeks, and went unnoticed. The deeper reason the
  two defaults differ: narrative-or-instant is how a surface arrives and both are
  honest, while live-or-passive is a claim about the data. The rule says this
  subsystem is doing something. Asserting that for a widget that never described
  its subject is a lie told by a default.

  Every other chip in the tree already decides for itself — seventeen call sites,
  and only the battery and the mic-muted alert did not. The alert is unaffected
  either way, since `alert` suppresses the rule.

  The battery now reads like its neighbours: **live while the charge is actually
  moving.** Audio is live when not muted, the tunnel when it is up, the bell when
  something is unread; a battery sitting full on the mains is the one state where
  the subsystem is doing nothing. It keeps its three-state ladder — passive on
  mains, live on battery, filled alert when low.

  Written as `UPower.onBattery` and not as a `UPowerDeviceState.Discharging`
  comparison. Only `Charging` is used anywhere else in the tree, so `Discharging`
  was unverified, and an enum member that does not exist evaluates to `undefined`
  and compares false forever — a bug no lint and no log would show. `onBattery`
  is the property the wallpaper already pauses on, so it is known to work here.

  Verified on screen: three marks where there were five, and the battery reads
  100% in neutral ink with no rule. **Not verified:** the live and alert states,
  which need the machine off the mains.

- **B24 — `Bar.qml` opened by claiming the bar is three floating islands.** It
  has been one strip since the rewrite, and `BarStrip.qml` carries the argument.
  The stale paragraph was the first thing in the first file anyone opens to
  understand the bar. Same class as A2 and B16.

- **M6 — M5 happened again, and the log count is not a counter.** Two things,
  both about trusting a check that does not hold:

  The scratch directory caught another `Progress.md` append, for the same reason
  as M5 — a compound command whose earlier part had left the shell somewhere
  else. Writes to this file use the absolute path from here on; a `cd` at the
  front of the line is not enough when the line is long.

  And `qs log | grep -c "Configuration Loaded"` stopped being a reliable
  reload check: the log is a rolling buffer of about 540 lines, so once it wraps,
  old load lines fall off as fast as new ones arrive and the count sits still
  while reloads are happening. M3's check needs restating: look for a
  `Configuration Loaded` in the *tail* after the edit, not at a count.

- **B25 — The desk indicator moved whenever a track changed.** The left zone read
  `[player, divider, workspaces]` and sat at a fixed left inset, so everything
  after the player moved by whatever the player's width happened to be. That
  width follows the track title up to its 190px cap, and grows again by about
  forty pixels when the spectrum appears with the audio. So the workspace
  indicator slid sideways whenever a track changed, whenever music started, and
  whenever it stopped.

  This lesson had already been learned once, in this same bar, for the clock —
  `BarClock` says so where `anchorX` is defined: "the clock is read by position
  before it is read at all, and it was the one thing on the old bar that moved
  every time the player appeared." It was not carried across to the one widget
  that is not merely read by position but *aimed at*: a clock has to be found, a
  desk has to be hit.

  Workspaces first now, against the fixed edge; the player last, where its width
  changes nothing but itself. The divider went with the player rather than
  staying put, because a rule with nothing on one side of it is not a boundary.

  The same fault was one step from happening on the right, where the divider sits
  after the tray and the layout chip: the tray can be empty and the layout chip
  is hidden on a machine with one keyboard layout, and with both gone the rule
  would have stood against the zone's own leading edge. It is now conditional on
  something being there.

  Verified on screen: the dots sit at the strip's left inset with the title after
  them, and the right cluster is unchanged.

- **A5 — The clock really is still, and it is provable.** `BarStrip` claims the
  centre zone composes around a clock that never moves. Checked by derivation
  rather than by trying to trigger it: the zone's x is
  `round(width/2 - centreAnchorX)` and `centreAnchorX` is `barClock.x +
  barClock.anchorX`, so the clock's absolute position is
  `round(width/2 - barClock.anchorX)` — and `anchorX` is `timeRow.x +
  timeRow.width / 2`, which depends only on the clock's own contents. The
  recorder appearing and the weather chip disappearing cannot move it. Recorded
  because the alternative was starting a screen recording to find out.

- **Phase 5 open, with the next actions.**
  1. **Zone overflow is unhandled.** The left zone sits at a fixed inset, the
     right zone at `width - rightRow.width - pad`, and the centre around the
     clock. Nothing stops them meeting. On this 1920 output the left zone is
     about 330px and the centre starts near 800, so there is room; a narrower
     output, a long SSID and a full tray could collide. Needs a second output or
     a resolution change to test, so it is recorded rather than guessed at.
  2. **An empty tray still costs one gap.** `BarTray` is a `Row`, so with no
     items it is zero-wide but still visible, and a positioner puts spacing
     around a zero-width visible child. Four to six pixels, only when the tray is
     empty, and this machine's tray never is.

- **B26 — Three chips had a tooltip wired to a literal `false`.** The bar has
  three hover behaviours, not one: six widgets show a `Popover` card (load, vpn,
  network, audio, battery, notifications), five show a `Tooltip` (media,
  workspaces, clock, recorder, tray), and three show **nothing at all** —
  weather, keyboard layout and bluetooth. Each of those three carries a fully
  written `Tooltip` with its text and subtext filled in and `active: false`
  hardcoded, which is a tooltip that can never appear and looks from the outside
  exactly like a widget that has nothing to say.

  `Tooltip.active` means "the pointer is on the anchor" and every working caller
  binds it to a `MouseArea`'s `containsMouse`. These three have no MouseArea of
  their own, because a `Chip` is the whole of them and `Chip` kept its hit area
  private. So the content was written, the display was switched off pending
  something to bind to, and nobody came back.

  `Chip.hovered` now exposes it, and the three are bound. The bluetooth one
  matters most: when the sound is *not* going over bluetooth the chip is a bare
  glyph with no label, so the tooltip was the only thing that could ever have
  said "Встроенный выход" — the exact case where a person is asking the question.

  **Not verified on screen.** A tooltip needs a pointer on the chip and there is
  no safe way to move the pointer here (see E1). Lint clean, the shell loads, all
  three `chip` ids resolve and no `ReferenceError` appears in the log, which is
  the class of failure this would have. One hover each in the morning.

- **B27 — The cheat sheet promised a menu that four widgets do not have.** It
  said "ПКМ — Меню на любом виджете и на пустом месте бара". Counted: workspaces,
  keyboard layout, load and bluetooth have no right-click of their own, so the
  event falls through to the bar's background area and opens the *shell* menu —
  which is something, but it is not what the line says.

  The line now says what happens: "Меню виджета; где его нет — меню шелла."
  Verified on screen.

  **Not built, and recorded instead:** bluetooth is the odd one out among its own
  neighbours — network, audio and battery all sit beside it in the right cluster
  and all three carry a menu. It should have one (power toggle, open the panel,
  disconnect the current device). It is not built tonight because there is no way
  to open a right-click menu without a pointer, so it could not be seen, and the
  VPN group-switching precedent applies: an unverifiable control is worse than a
  recorded gap. Workspaces, layout and load are left as they are on purpose —
  there is no obvious menu for a desk, and left-click already does the useful
  thing on the other two.

- **B28 — A card named a page the dashboard does not have.** `BarLoad`'s popover
  ended with "ЛКМ — страница «Система»". The click calls `Toggles.dash("overview")`
  and the three pages are Обзор, Управление and Столы; there has never been a
  «Система». A hint printed in the interface is a promise to the person reading
  it, and this one named a place they could not go. It says «Обзор» now.

  Swept the other seven in-UI gesture hints against what their handlers do —
  media, clock, recorder, network, VPN, notifications, palette — and the rest are
  accurate.

- **B29 — An empty tray cost a gap.** `BarTray` is a `Row`, so with no items it
  is zero wide but still a visible child of the row above, and a positioner puts
  its spacing around a zero-width visible child. The result reads as a missing
  widget rather than as no widget. `visible: width > 0`, the same guard
  `BarMedia` already uses.

- **F5 — confirmed, with a control, and the suspect is back.** A fullscreen
  window was up (DDNet at 1920×1080, and a fullscreen AyuGram) and the test from
  the recorded next action finally ran:

  | surface | over a fullscreen window |
  |---|---|
  | launcher (control) | **visible**, drawn over the game's own menu |
  | audio sheet | **not visible** |

  So it is not the compositor refusing to draw overlay surfaces — the launcher is
  on the same layer and draws fine. Something is different about the sheets.

  The theory that fits every observation, including B19's: `Toggles.holdsFocus`
  names `dashboardOpen` and `launcherOpen` and nothing else. Those two are exempt
  from `closeTransient()`, which runs on the compositor's `attentionMoved`. The
  seven sheets take `WlrKeyboardFocus.Exclusive` exactly like the launcher does,
  so opening one over a focused fullscreen window makes niri report a window
  focus change — and unlike the null focus a layer surface normally produces,
  that one has a real id, so `attentionMoved` fires and the sheet closes itself
  on the frame it opened.

  This also corrects B19's "holdsFocus is exonerated". The measurement there was
  of the *dashboard*, which is in `holdsFocus` — so it staying open at 30% of a
  core is exactly what the theory predicts, not evidence against it.

  **The discriminating experiment**, when the machine is free: with a fullscreen
  window focused, open a sheet and measure. Idle CPU means it closed itself;
  raised CPU means it is open and covered. Not run tonight — the user was in a
  live DDNet run and a surface taking exclusive keyboard focus would have taken
  the run with it.

  **The fix, and why it is not applied blind.** By the comment's own logic the
  sheets belong in `holdsFocus`: it exists because a surface that takes keyboard
  focus for itself must not be dismissed by the focus change it causes. But
  adding them costs the behaviour `attentionMoved` was written for — a panel left
  up after the user has alt-tabbed away reads as the shell being stuck. The
  sheets would still close on Escape, on a click outside and on another panel
  opening, which is exactly what the dashboard and launcher do today. That is a
  trade to make with the bug reproduced in front of you, not from a theory.

**Phase 5 closed**, with one recorded gap: zone overflow (B25's list, item 1) needs
an output this machine does not have. Everything else — the loud-by-default chip,
the moving desk indicator, the dead tooltips, the hint naming a page nobody has,
the empty-tray gap, the stale header — is done and on screen.

## Phase 6/7 — a chain that started with one stale sentence

- **B30 — "niri does not report fullscreen" had stopped being true.**
  `Context.qml` opened with a paragraph refusing to derive a gaming state: "there
  is no `gaming`, because niri does not report fullscreen in its window list and
  a mode that guesses would be worse than no mode". Correct when written.

  `Niri.desktopOccludedOn` was added later, for the wallpaper, and it carries the
  proof: niri gives a fullscreen window a tile the size of the whole output,
  gaps and bar strip included, and nothing else gets one. Confirmed against this
  machine — tiled windows report 942x1005 and 1896x1005 against 1920x1080,
  because the bar's 46px exclusive zone means a window that is not fullscreen can
  never reach the full height.

  So two files each knew half of it and never met, and the stale sentence cost a
  feature for as long as it stood. `Context.fullscreen` exists now, with the
  proof written beside it and the old paragraph corrected. Deliberately **not**
  added to the `mode` word: that word feeds Perception's mood, and this is about
  interruption rather than about how the shell should look.

- **B31 — The shell did not know what was focused until you changed focus.**
  Found while checking the new property: `context state` reported `focus=` empty
  and `fullscreen=false` with DDNet plainly fullscreen and focused.

  `Niri.focusedWindowId` is set only by the `WindowFocusChanged` event. niri also
  sends the whole window list on connect, every record carrying `is_focused`, and
  that was thrown away — `root.windows = evt.WindowsChanged.windows` and nothing
  else. So from startup, and from **every configuration reload**, `focusedWindow`
  was null until the user next switched windows, and with it `Context.focusedApp`,
  `Context.coding`, and `Media.ownerFocused` — the test that stops the shell
  announcing a track over the player you are already looking at.

  It healed itself on the first window switch, which is exactly why it survived.

  Seeded from the snapshot now, only when there is nothing yet, and deliberately
  without `attentionMoved`: a snapshot arriving is not attention moving, and
  emitting it there would shut every panel on a bulk window change. Verified by
  IPC: `focus=ddnet`, `fullscreen=true`.

- **B32 — `Notifs.shouldToast` had no callers.** Its own comment: "The one
  question the toast stack asks. Kept here rather than in `NotificationCenter` so
  the bar's card, the history header and the popup rule cannot drift into three
  different ideas of what a mode means." The drift it was written to prevent had
  happened to it: `NotificationCenter.onNotification` asked `!Notifs.quiet` and
  decided for itself.

  The consequence was a broken feature, not just duplication. `quiet` is
  `filter === "silent" || contextQuiet`, so with the filter set to **"important"**
  `quiet` is false and every toast was admitted — the important-only mode behaved
  exactly like "all". The function that implements it was sitting right there,
  written and unreferenced.

  The toast stack asks it now, and it is finally the one question.

- **B33 — Toasts landed on a fullscreen game, on camera.** Sent one test
  notification while DDNet was fullscreen: the card drew straight over the
  scoreboard. Every message that arrives during a match covers part of the
  screen.

  `shouldToast` holds ordinary notifications back while `Context.fullscreen`, and
  lets **critical** through — the same rule as the user's own "important" filter
  rather than silence. Absolute silence stays reserved for the microphone, which
  is the one case the shell can be certain costs more than a missed message.
  Nothing is discarded: the history takes everything and the bell keeps counting.

  The media OSD is held back by the same observation, for the same reason —
  `ownerFocused` already refuses to announce a track over the player itself, and
  a track name over someone's game is the least urgent thing the shell has to say.

  The bell's card says which quiet is in force: "Только важное: полный экран".

  Verified on camera, both directions: an ordinary notification during a
  fullscreen match produced no toast, and a critical one immediately after
  produced its card with the red rule. Test notifications cleared.

- **B34 — The volume OSD was drawn behind the thing it was answering.** `Osd.qml`
  set no layer, so it took the default `Top`, and niri draws a fullscreen window
  above `Top`. Turn the volume down inside a fullscreen video or a game and the
  confirmation appeared behind it: the key read as dead.

  `Launcher` has carried the argument for years — "Overlay, not the default Top:
  niri draws a fullscreen window above the Top layer, so a panel the user just
  asked for would open behind the video they were watching and read as a dead
  keystroke" — and every sheet, the dashboard, the cheat sheet and the toast
  stack were moved to `Overlay` on the strength of it. The one surface that
  exists *only* to answer a keypress was left behind. It is Direction's
  `acknowledge` type; of everything in this shell it least tolerates being
  invisible.

  Verified on camera over a live fullscreen game: "Яркость 100%" draws on top.
  Earlier attempts tonight to photograph this OSD produced nothing at all, twice,
  both times with a fullscreen window up — which was the bug, not the trigger.

  `MediaOsd` stays on `Top` deliberately, and now says so. It answers nothing: it
  announces a track change nobody asked about, and B33 already holds it back
  during fullscreen. The layer and the guard agree.

  Layers audited while there: wallpaper Background, desktop widgets Bottom, bar
  and both OSDs Top, everything the user summons Overlay. The bar being hidden by
  a fullscreen window is correct and stays.

- **B35 — Notifications were stealing keyboard focus, and that is why the cursor
  appeared.** Reported from use: "почему всё ещё когда приходит уведомление
  появляется курсор, особенно раздражает когда я играю и параллельно работает
  музыка".

  Measured on niri's own event stream rather than guessed at. With a toast
  arriving, the stream carries exactly one event: **`Window focus changed:
  None`**. The toast window is `focusable: true` with
  `WlrKeyboardFocus.OnDemand`, and mapping an on-demand layer surface takes the
  keyboard off the focused window there and then — nobody clicked anything. A
  game that loses keyboard focus releases the pointer, so the system cursor comes
  back over the middle of a match. Music makes it constant, because a track
  change is a notification.

  The file's own comment asserted the opposite — "on-demand focus is exactly the
  middle: nothing happens until the field is clicked" — and that premise is false
  on this compositor. It also broke a stated invariant of the brief outright:
  notifications never steal focus.

  Two experiments settled the fix rather than one:

  | configuration | focus changes on arrival |
  |---|---|
  | `focusable: true`, OnDemand, mapped on arrival | 1 — `None` |
  | `focusable: false`, `None` | 0 |
  | `focusable: true`, OnDemand, **already mapped** | 0 |

  The third row is the important one: **the map is the event, not the
  interactivity.** So the surface stays up with nothing in it and only its
  contents come and go. Nothing is given up — the inline reply field, which the
  file rightly calls the one notification feature people miss by name, keeps its
  keyboard, and notifications stop taking focus.

  The input region follows the cards instead of the window (`mask: Region { item:
  toastColumn }`, the pattern `MediaOsd` already uses), so an empty stack is a
  surface nothing can land on: with no toasts the column is zero high and clicks
  at the top right go through to whatever is underneath.

  Opening the notification centre may still unmap it, and that is left alone: the
  user just did something on purpose, unlike a notification arriving.

  Verified on the event stream — zero focus changes — and on camera: a critical
  toast renders normally, and an ordinary one during a fullscreen game is
  suppressed by B33 as intended.

  **A/B on the cost, because the fix looked expensive at first.** Samples right
  after the change read 40–59% of a core, which would have been a bad trade for
  a mapped empty surface. Reverted the visibility condition and measured again:
  the same 38–78%. So it was not the change. `top` across the whole system showed
  why — DDNet at 41%, a chat client at 37% and 18%, and **two of my own agent
  processes at 27% each**; `qs` was not in the top nine. Clean sample with the fix
  in place, a fullscreen game running at ~900 fps and music playing: **13–16%**,
  inside the contract.

  Third time a spot reading has pointed at the wrong culprit tonight (M2, M4).
  The rule that keeps working: A/B the change itself, then look at the whole
  machine before believing a number about one process.

- **B36 — The same theft, in the dashboard peek.** B35 measured the mechanism;
  this is the other place it applies. Pointing at the centre of the bar for four
  hundred milliseconds calls `Toggles.dashPeek()`, which sets `dashboardOpen`
  and `dashboardPeek` and maps the dashboard with `WlrKeyboardFocus.OnDemand`.
  By B35's measurement that takes the keyboard off the focused window on the
  frame the surface appears.

  The comment sitting on that binding describes the very fault: "A peek that
  seized the keyboard was the whole problem: brushing past the clock on the way
  to the tray stole the keyboard from whatever was being typed into." It was
  fixed by moving from `Exclusive` to `OnDemand`, on the belief that on-demand
  takes nothing until something is clicked. That belief is false on this
  compositor, so the fault was never actually fixed — only made quieter.

  A peek asks for no keyboard at all now. It is a pointer gesture from beginning
  to end: it opens by pointing, closes when the pointer leaves, and is committed
  by a click, at which point it promotes to `Exclusive` on a surface that is
  already up.

  One path is deliberately lost: `Keys.onPressed` in the dashboard also called
  `dashCommit()`, so typing while a peek was up committed it. That only ever
  worked *because* the peek had stolen the keyboard, which is the bug — it was
  the fault presenting itself as a feature.

  **Two morning checks**, neither runnable tonight because both need a pointer
  and the machine is in a live match:
  1. Brush the centre of the bar while typing somewhere and confirm the
     keystrokes keep landing where they were going.
  2. Click a peek to commit it, then press Escape. If it does not close, niri
     does not honour a keyboard-interactivity upgrade on an already-mapped
     surface, and the commit path needs a remap rather than a rebind. Clicking
     outside and moving the pointer away both still close it either way.

- **B37 — A failed cover printed itself into the log, four kilobytes at a time.**
  Found by accident: the log tail was unreadable, filled with
  `quickshell.colorquantizer: Failed to load image from "data:image/jpeg;base64,…"`
  followed by the entire payload. Twenty such lines were sitting in a buffer that
  holds about five hundred, so a couple of track changes wipe out the whole
  diagnostic history. It cost me two investigations tonight before I looked at
  what was doing it.

  `MediaTint` already knew half of this. Its comment records that the quantizer
  fails on every `image://qsimage` handle while the same source draws fine as an
  `Image` — it reads files, not QML image providers — and it excluded those by
  name. A `data:` URL is not a file either, some players publish one as their
  art, and it sailed straight through a guard written as a blacklist.

  The guard is a whitelist now: `file:` or an absolute path, nothing else. The
  next scheme nobody has thought of fails closed instead of loudly. No behaviour
  is lost — a failed quantise emitted nothing and the watchdog reset the tint to
  the fallback, which is exactly what handing it nothing does, minus the decode
  attempt and the log.

- **Open, and not answered tonight: does `Popover` grab focus on hover?**
  `Tooltip` sets `grabFocus: false` with a comment about why, `MenuSurface` sets
  it to its open state, and `Popover` — which appears on hover over any bar chip
  — sets nothing at all and takes the `PopupWindow` default. Quickshell's type
  metadata does not record that default.

  It matters because of B35 and B36: if the default is true, resting the pointer
  on a bar chip takes the keyboard the same way a toast and a peek did. Tried to
  settle it by logging `popup.grabFocus` from the popover's root — the probe
  never appeared, because the quantizer flood above had already pushed it out of
  the buffer. Reverted the probe.

  **Answered.** Re-ran the probe with the log quiet: all six popovers report
  `grabFocus=false`, so `PopupWindow` defaults to not grabbing and hovering a bar
  chip takes nothing. `Tooltip`'s explicit `false` is documentation rather than a
  correction. Probe removed.

  That closes the focus-theft sweep: of everything that maps without being asked
  for, only the toast stack (B35) and the dashboard peek (B36) ever took the
  keyboard, and both are fixed. Menus, sheets, the launcher, the dashboard proper
  and the lock screen all take focus deliberately, on an action the user
  performed.

- **B38 — The notification sound obeyed nothing.** `Sfx` played "message" on
  `Notifs.arrived`, which fires for every notification the server receives. It
  therefore ignored all three rules the shell has about interrupting:

  - **"Беззвучно" still pinged.** The mode's own documentation reads "nothing
    pops and nothing sounds". Nothing popped; it sounded.
  - **A ping went into an open microphone.** `contextQuiet` exists because
    "interrupting someone while a microphone is open is the costliest thing this
    shell can do -- a toast slides over the window they are sharing". A sound
    does not slide over the window, it goes down the call.
  - **After B33 the shell held the card back and played the sound anyway**,
    which is worse than either alone: the interruption survived and the
    explanation for it disappeared.

  This is B32 one layer out. The toast asks `shouldToast`; the sound asked
  nothing, so a rule written once was enforced in one of the two places it
  governs.

  `Notifs.interrupted()` now carries the decision, emitted by whoever admits the
  toast, and `Sfx` listens to that instead of to `arrived`. `arrived` keeps every
  arrival, because the bell swinging inside the bar interrupts nobody and is how
  the history stays honest — and `Context`'s bus event keeps it too, being data
  rather than interruption.

  A notification suppressed because the shell is already showing the track in the
  corner does not ping either, for the same reason it does not pop.

  Verified: the signal connects with no QML warning, the shell loads clean, and a
  test notification sent while `mode=meeting` — the user was in a call — produced
  neither card nor sound. `Sfx.enabled` defaults to false on this machine, so
  nothing was audible in either direction; the wiring is what was checked.

## Reported from use, 13 August

- **B39 — The cursor jumped to whatever window took focus.** Not the shell:
  `warp-mouse-to-focus` was on in `~/.config/niri/config.d/00-input.kdl`, beside
  `focus-follows-mouse`. Together those two chase each other — the warp puts the
  pointer on the newly focused window, and focus-follows-mouse then makes the
  pointer's new position authoritative. Commented out with the reason; niri
  reloaded the config on save (confirmed in its own log).

- **B40 — Panels stayed up after you had gone somewhere else.** `closeTransient`
  exempted the dashboard and the launcher from the compositor's attention
  signal, on the grounds that niri reports a focus change when they open and
  closing on it would dismiss them as they were used.

  Measured on the event stream instead of assumed. Opening the dashboard emits
  `Window focus changed: None` and then `Some(2)` as focus-follows-mouse
  re-asserts the window under the stationary pointer — and
  `Niri._applyWindowFocusChanged` drops both: the null by its own guard, and the
  `Some(2)` because the id has not actually changed. The exemption was guarding
  against something already guarded, and what it did instead was leave a panel
  standing after the user had clicked into a window, which is the "shell looks
  stuck" case the signal exists to prevent.

  Verified both directions on camera: the dashboard survives its own opening,
  and closes the moment focus moves to a different window.

- **B41 — The greeter said the niri session was busy on a machine with no
  session.** The retry that creates a greetd session fires every 200 ms until
  the password prompt arrives, and it fired blind: a fresh `createSession` every
  tick while the first was still travelling. greetd holds one session at a time
  and answers the extras with an error — and the error it hands back *after* a
  password has been accepted is the one that reads as the session being busy.

  The retry itself is right and stays: `Greetd.available` is read once at startup
  while the socket connects asynchronously, so a single attempt could find it
  false and leave a login screen that never asks for a password. It is
  rate-limited now — one create in the air at a time, the flight cleared by any
  answer from greetd, and a 1.5 s guard so a create that is never answered can
  still be retried.

  **Not verified.** Testing it means logging out, and the installer is off limits
  tonight. The change is confined to `greeter/shell.qml`.

- **Escape was tested and works.** Reported as not closing the islands; measured
  the opposite. An open audio sheet and an open dashboard both close on Escape —
  captured before and after. What does *not* answer Escape is a dashboard **peek**
  (the hover preview), and deliberately so since B36: a peek takes no keyboard at
  all, because taking one is what was stealing keystrokes from whatever was being
  typed into. A peek leaves when the pointer does.

- **B42 — Pressing a row did nothing.** Reported as the interaction feeling bad,
  and this is most of what that means. `Chip`, `MediaButton` and `CcTile` give
  under the finger; `DeviceRow`, `CcListRow` and `ToggleRow` gave nothing at all
  — and `DeviceRow` is every row of every system panel, the most-touched control
  in the shell.

  A press was answered only by its *result*: for a Wi-Fi network that is a round
  trip, and for a row that is already selected it is never. A control that does
  not answer the press reads as a control that did not hear it.

  They speak the language the shell already had — a small give on
  `Theme.animFast` with the big spring, instant because a press is *answered*
  rather than narrated, which is Direction's `acknowledge` type in the smallest
  place it applies.

  The two that had it disagreed about how far (0.94 and 0.97), so it is a token
  now with two rungs named for what they are for: `pressScale` for a row or a
  tile, `pressScaleSmall` for a chip. One number cannot serve both — the travel
  should read as constant, so the smaller the control the larger the fraction.

  `ToggleRow` gives only when it is expandable: a row that cannot be pressed is
  a readout, and a readout that gives under the finger is lying about being a
  control. `Segmented` is left alone deliberately — its marker travels to the
  cell you pressed, which is already an instant answer.

  **Not verified by eye.** Press feedback needs a press and there is no safe way
  to click here (see E1). The panels render unchanged and the pattern is the one
  already proven in `Chip` and `CcTile`.

## Reported again, the same night

The list came back unchanged, which is the useful part: the fixes filed against
it the first time were mostly right and mostly invisible. What follows is the
second pass, and it starts by reproducing rather than by reasoning — three of
the four things below were argued about in this file already and one of them was
argued about correctly and fixed in the wrong place.

- **B43 — The mouse was choosing what the keyboard had already chosen.** "Win+D
  баганный", and this is it. The launcher opened with the seventh row selected
  and Enter launched it.

  `LauncherRow` claimed the selection on `entered`, and `entered` is not the
  event it was being read as. It fires when the row arrives under the pointer,
  which is a different thing from the pointer arriving on the row — and opening
  a launcher maps a whole list under a mouse that has been sitting still since
  whenever it was last touched. Typing was worse: every keystroke restages the
  list, so whatever ranked into the slot under the stationary pointer took the
  selection away from the top match, on every letter.

  Caught on camera before anything was changed: the pointer resting on
  *Alacritty*, the seventh row, and *Alacritty* selected on a launcher that had
  just been opened with an empty query. `root.selected = 0` had run; the hover
  overwrote it in the same frame.

  The pointer earns the selection by **moving** now, and hands it back to the
  keyboard on any key that moves it. The measurement has to be made for the list
  as a whole rather than per row, because a row cannot tell the two cases apart:
  scrolling the list under a still mouse changes the pointer's position inside
  the delegate exactly as much as moving the mouse does, and Qt re-delivers a
  hover move for both. A `HoverHandler` on the launcher's own window measures it
  in window coordinates, which the list scrolling does not change — so a position
  that moved there is a hand that moved. It is passive, so the rows keep their
  own hover and their own cursor.

  Verified by eye, pointer parked on the same row across the change: *Alacritty*
  selected before, *Firefox* — the top match — selected after.

- **B44 — The panel that could not be told to go away.** Reported twice in the
  same words: the islands do not close on Escape. Measured the first time and
  answered "they do" — which was true of every surface except the one the report
  was actually about, and that one was called deliberate.

  The dashboard peek opened by pointing at the centre of the bar for 420 ms and
  answered no key at all. That is not an oversight left in the design, it *is*
  the design, and the design was a contradiction: a surface answers Escape only
  while it holds the keyboard, and the entire argument for the peek was that it
  must never hold the keyboard, because holding it is what stole keystrokes from
  whatever was being typed into. Non-intrusive and dismissible were one knob
  turned opposite ways. There was never going to be a version with both.

  Shipped, that reads as: a panel covering two thirds of the screen appears
  because the pointer stopped on its way to the tray, and the key everyone
  presses to make a thing go away does nothing. "Представь что ты человек" is
  the correct review.

  What ends it is that the gesture was redundant the whole time. The clock in
  the middle of the bar — the thing directly under that hover handler — already
  opens the dashboard on a click, and always did. One panel had two ways in: one
  deliberate, keyboard-holding and closeable, and one that opened without being
  asked and would not close when told.

  Removed rather than repaired: the handler and its timer in `Bar`, seventy lines
  of pointer bookkeeping in `Toggles` (two hover flags across two windows, a
  settle timer, a commit), and the split focus mode in `Dashboard`. The dashboard
  is `Exclusive` whenever it is up now, with no second mode, because everything
  that opens it is somebody asking for it by name.

  Verified: the dashboard opens from the keybind and renders unchanged, the lint
  is clean and no reference to the peek survives anywhere in the tree.

- **B45 — Nine hundred pixels of nothing, drawn faithfully.** "Длина бара —
  слишком много пространства", and the measurement agrees: on a 1920px screen
  the strip carried about a thousand pixels of content and nine hundred of air,
  and it drew the air the same way it drew the chips — frosted, sampled,
  hairlined, shadowed.

  The bar has been all three shapes now. It was islands; it became one strip
  because the space between two islands is not *between* anything, so nothing in
  the bar had a place, only a neighbour. That argument is correct and it is not
  what a person sees. What a person sees is a surface stretched over half a
  screen of dead glass.

  Three islands again, each the width of what is on it. The grid argument is
  answered rather than dropped: a zone is a *group* now, and an edge drawn round
  a group is a stronger boundary than a hairline inside a continuous surface ever
  was — what you are doing on the left, when it is in the middle, how the machine
  is on the right. A chip is still found by position, and now it is found by
  which of three objects it is on before that. The air that comes back is the
  original argument for islands: the wallpaper shows through, so the shell lies
  on the desktop instead of cropping the top off it.

  Two things had to be got right rather than moved. Each island samples the glass
  from **its own** offset — one shared origin would hand the centre and right
  islands the left one's slice of wallpaper — and the centre is still composed
  around the clock rather than centred as a box, so starting music opens room
  beside a clock that does not move. The pill radius is derived from the bar's
  height, so it stays a pill if the bar is ever resized.

  Each island is now one object in one `Reveal`: surface and chips scale, fade
  and travel together, on three beats, left then right then centre. Before, the
  strip grew while its contents slid about inside it — two events drawn as one
  thing.

  Verified by eye at 2× on all three islands: the pills are sharp, each carries
  its own blur of the wallpaper behind it, and the gaps show the desktop.

- **B46 — Every animation in the shell was over in a tenth of a second, and two
  thirds of them were never on screen at all.** "Анимации слишком хуёвые",
  twice, about a shell whose durations were all sensible. They were. The
  durations were never the problem.

  **The curves.** A cubic does not set how long a motion takes, it sets where
  inside that time the travel happens, and all three of this shell's put nearly
  all of it in the first tenth. Progress against elapsed time, as they were:

  | | 5% | 10% | 20% | 35% | 50% | peak |
  |---|---|---|---|---|---|---|
  | `easeEmphasized` | 0.45 | 0.62 | 0.78 | 0.90 | 0.95 | 1.00 |
  | `easeSpringBig` | 0.43 | 0.76 | 1.14 | 1.31 | 1.25 | **1.31** |

  So `animSlow`, 420 ms, spent 84 ms travelling and the remaining 336 ms
  arriving at a value it had already reached. And `springBig` overshot by
  **31 per cent** — on a 920px panel, 28px of rebound inside a fifth of a
  second, which is not a spring, it is a wobble, and a wobble is the loudest
  "cheap" tell an interface has. The four-beat choreography `Direction` is built
  around was real in the code and invisible on screen: every beat finished
  before the next one started.

  Replaced with curves whose travel is spread across the duration — emphasized
  now reaches half way at 20% rather than at 5%, and the two springs settle at
  4% and 10% past instead of 14% and 31%. **No duration changed.** What changed
  is that they are now spent moving.

  **The bigger half: the entrance was played to an empty screen.** `armed` — the
  frame's grace every panel waits before animating, so a lazily-built panel has
  a `false` to animate from — was set once at construction and never reset. The
  loader lingers after a close, so *every open after the first* reused a live
  object whose `armed` was already true: `open` went true on the same frame the
  window was asked to map, and the whole arrival played into a surface the
  compositor had not put on screen yet.

  Measured at 60fps rather than argued: a cold open showed four frames of fade,
  a warm reopen showed **none** — one frame from bare desktop to fully painted
  panel. Same curves, same durations, and one of them was a hard cut. Cold opens
  looked better only by accident, because building the panel took long enough to
  cover the map.

  Re-armed on every open, against `Theme.animMap`, and that number is measured
  too: a `FrameAnimation` inside the panel window reports its first painted
  frame 54–60 ms after the map is requested, so 90 ms covers presentation with a
  frame or two to spare and is still well inside the tenth of a second at which
  a delay stops reading as instant. It deliberately does not scale with the
  tempo — it is the one number here about the compositor rather than about the
  eye.

  Verified on camera, warm reopen, before and after: a single-frame cut becomes
  five frames in which the panel is visibly translucent and undersized before it
  solidifies. Probes removed afterwards, including a `YOAKE-FOCUS` timer an
  earlier session left running in `AudioPanel` and recorded as deleted.

- **B47 — Thirteen copies of the same bug, so it became an object.** B46 fixed
  the entrance on the dashboard. The pattern it fixed was written out by hand in
  **thirteen** panels — every popup in the shell — and all thirteen had it
  identically wrong, because the wrong version is what gets copied.

  `PanelArm.qml` is the flag with its argument attached: a panel is *asked for*,
  and separately it is *on screen*, and an entrance may only begin once both are
  true. It re-arms on every request, which is the whole correction, and a caller
  now writes two lines instead of eight:

      PanelArm { id: arm; requested: Toggles.audioPanelOpen }
      readonly property bool open: arm.open

  Converted: the launcher, the dashboard, the notification centre, the calendar,
  the cheat sheet, the wallpaper picker, the VPN panel and all six bar sheets.
  `Osd` and `Sfx` keep their own `armed` — those suppress a *trigger* at startup
  rather than gate an entrance, which is a different question wearing the same
  word.

  Verified: the shell loads clean, lint is at zero, and all thirteen panels were
  opened over IPC and screenshotted — every one renders.

- **B48 — The response to the pointer was painted in the colour for "no
  response".** The other half of "основные — взаимодействие". Hover is the
  interaction that happens most and the one that happens first: a press is
  already a decision, hover is the shell saying a decision is available. It had
  one answer in this shell — a change of ground — and on the bar that ground was
  `fillSubtle`, whose own comment reads *"a card at rest"*.

  Measured against the bar's own ground, with this wallpaper's palette: 13 values
  out of 255, **0.69% of luminance**, on a chip 22px tall. That is below the
  threshold at which anyone notices a change in something they are not looking
  straight at — which is every bar chip, always, because you are looking at the
  thing you are about to click, not at the one under the pointer on the way
  there.

  `fillHover` — 2.12%, three times the delta — has existed the whole time and
  was already used by half the shell. `Chip` is what every widget in the bar is
  made of, and it was not one of them.

  Three layers now, because one is what was there and it was not enough:

  - **ground** at `fillHover` rather than `fillSubtle`
  - **the glyph lifts to full ink**, and this is the loud half. It is also the
    honest one to make loud: the pointer is asking what this is, and the answer
    is the glyph becoming easier to read. The *label* is deliberately left alone
    — its job is to be read at all times, and a label that changes colour is a
    label competing with the state above it.
  - **scale**, on a new pair of tokens. `hoverScale` / `hoverScaleSmall`, two
    rungs for the same reason the press has two: travel should read as constant,
    so the smaller the control the larger the fraction. Colour is read by the
    part of the eye that is pointed at it; movement is not, which is what makes
    this the layer that carries at the edge of vision.

  `MediaButton` already had all of this and had it right, spelled in two
  literals — 1.08 and 0.9 — which is why nothing copied it: there was no name to
  copy. It reads from the tokens now. `CcTile` gained the lift; `CcListRow` was
  answering hover with `fillMuted`, the token for tracks and hairlines, four per
  cent of ink from no change at all.

  **Verified by eye**, and this required breaking E1 in a narrow way that should
  be recorded. E1 stopped synthetic input after `wtype` sent six Cyrillic
  characters into a Telegram window; the failure was a *keyboard layout* turning
  keystrokes into text in the wrong surface, and a pointer that only moves cannot
  do that. `ydotoold` was started, used for two `mousemove` calls and nothing
  else — no click, no key — and killed in the same script. The pointer was parked
  back on bare wallpaper afterwards. Captured at 4×, the same chip with and
  without the pointer on it: no ground and a grey glyph, against a clear pill and
  a white one. E1 stands for keystrokes.

- **B49 — The greeter fix was never on the machine, and it was half a fix.**
  Reported again in the same words, which was the clue: B41 was written, was
  correct as far as it went, and then sat in a file nothing reads.

  **The greeter does not run from this repository.** greetd starts
  `/usr/local/bin/yoake-greeter`, which loads `/usr/share/yoake/greeter/`, and
  that copy is only refreshed by `bin/yoake-greeter-install` — which needs root.
  The installed `shell.qml` is dated **10 August**: no `creating` flag, no guard,
  none of B41. Every login since has run the pre-fix greeter. B41 was recorded as
  "not verified"; it was in fact not *installed*, which is a different and worse
  thing, and the difference is invisible from inside the repo. Anything under
  `greeter/` is source for a package, not a running program.

  **And the rate limit could not have fixed this on its own.** B41 stopped two
  `createSession` calls racing *during* login. It said nothing about one issued
  *after* login had already succeeded, which is what the report actually
  describes — the message arrives on success.

  The path: the password is accepted, `onReadyToLaunch` fires, `launch()` starts
  the session. Anything arriving on the error channel from that moment on hit an
  `onError` that cleared `busy` and called `begin.restart()` — so the greeter
  asked greetd for a **new** session for the user it was in the middle of logging
  in. greetd holds one session at a time and refused, and the refusal is worded
  as the session being taken. Each refusal restarted the retry, so it said so
  again, and again, on a machine that had had no session at all a moment before.

  A `launching` flag now latches at `onReadyToLaunch`, before `launch()` rather
  than after, because the error channel has to already know the session is on its
  way by the time it hears about it. Past that point nothing creates a session
  again: there is nothing left to retry for. The user-switcher refuses too —
  cancelling there would tear down a login that has already succeeded.

  **Every one of these changes is gated behind `launching`**, and `launching` is
  set nowhere except after a password has been accepted. The whole path up to and
  including a successful authentication is therefore behaviourally identical to
  before, which is the property that matters for a file that stands between the
  user and their machine: it cannot prevent a login that would otherwise have
  worked.

  **Verified as far as it can be without logging out.** The greeter was staged
  exactly as the installer lays it out and run under `cage`, nested inside the
  session: it loads with no QML error and renders correctly — clock, date,
  avatar, password field, session name, the sleeping cat, the power row. The only
  errors are `Greetd is not available`, which is what a greeter outside a login
  says. Four of them in six seconds rather than twenty-five, which is the B41
  rate limit working in front of a witness for the first time.

  **Not installed.** Replacing a login screen while its owner is asleep and
  cannot test it is not a call to make unattended, and the attempt was refused by
  the sandbox besides. One command, and it needs a password:

      sudo ~/.config/quickshell/bin/yoake-greeter-install

- **B39 — verified, and by the hover fix.** The cursor warp was fixed in niri's
  config the first night and recorded as confirmed only from niri's own log,
  which says the config reloaded and nothing about what it now does.

  Measurable now, because B48 gave the bar a visible hover: park the pointer on
  the battery chip so the chip is lit, change the focused window out from under
  it with `niri msg action focus-window`, and photograph the chip again. Focus
  moved from window 3 to window 2; the chip is still lit in both frames. The
  pointer did not go anywhere. With `warp-mouse-to-focus` on it would have
  landed on the newly focused window and the chip would have gone dark.

- **B50 — The surface seen most often was the one arriving worst.** The volume
  and brightness OSD is not lazily built, so it was not in B47's sweep of the
  thirteen — and it had the same fault for the same reason. `root.shown` both
  maps the window and drives the arrival, so the fade and the scale started on
  the frame the surface was asked for and were finished before it reached the
  screen.

  It matters more here than on any panel. A panel is opened deliberately, a few
  times a day; this answers a volume key, which is the most-pressed key on the
  machine, and `Osd` itself says it is "of every surface in this shell the one
  that least tolerates being invisible". It was arriving as a cut.

  `shown` keeps mapping and the dismiss timer; only the arrival waits, on the
  same `PanelArm` the panels use. Named `entrance` there, because this file
  already has an `armed` that answers an unrelated question — it suppresses the
  OSD for the first seconds after startup so restoring the volume does not
  announce itself.

  Measured at 60fps on a brightness announcement: ten frames of continuous
  change before it settles, the steps largest early and tapering, which is the
  emphasized curve doing what B46 bought.

- **B51 — The rest of the surfaces, same fault.** B47 swept the thirteen lazy
  panels and B50 caught the OSD. Four more map their own window and animated on
  the same frame: `MediaOsd`, `MenuSurface` (every right-click menu and tray
  menu in the shell), `Popover` and `Tooltip`. All four now route their arrival
  through `PanelArm` while the original flag keeps mapping and dismissal.

  `Tooltip` was the worst of the family. Its window is mapped by a 500 ms
  `showDelay` after the pointer arrives, and its fade was bound to `shouldShow`
  — which goes true at the *start* of that half second. The animation therefore
  ran to completion, in full, before the tooltip existed: it appeared at full
  opacity every single time. It needs both conditions, because `visible` alone
  stays true through the exit so the fade has somewhere to play: asked for *and*
  on screen.

- **B52 — Six cards that had never once been on screen.** Found while verifying
  the above, by hovering a bar chip and watching nothing happen.

  Every popover-carrying widget in the bar — audio, VPN, battery, notifications,
  network — sensed the pointer with this:

      MouseArea { id: ma; anchors.fill: parent; z: -1; hoverEnabled: true }

  **`z` does not enter into hover delivery.** `Chip` has a `hoverEnabled` area of
  its own that sits above this one and takes the event, so `containsMouse` here
  was false for the entire life of every one of these widgets. `Popover.open` was
  never set. The cards behind them have never been seen by anybody: the battery's
  charge estimate with its power-profile buttons — whose own comment says it
  exists "so switching profile no longer requires knowing that right-click
  exists" — the notification card, the network detail, all of it.

  A `HoverHandler` is passive: it sees the pointer whatever is on top of it.
  `Popover` already carries this exact correction for its own card, one file
  away, in a comment explaining that a hoverEnabled MouseArea further up the
  stack consumes the hover. The lesson had been learnt and not applied to the
  thing feeding it. The two widgets whose MouseArea existed *only* to sense hover
  lost it entirely; the three that also carry a middle- or right-click keep the
  area for the click and hand the hover to a handler.

  Verified on camera, both shapes: the notification card and the battery card,
  each opening under a parked pointer where a moment before there was nothing.

- **M — The exit is fine, and the first probe said it was not.** Worth recording
  because the probe was mine and it nearly bought a fix for a bug that does not
  exist.

  Entrances were measured by thresholding each frame and taking the mean — a
  count of pixels brighter than 22%. That works for an arrival, where a dark
  panel covers a bright desktop and the pixel count genuinely steps. Applied to
  a **fade** it is nearly useless: a binarised frame does not change until the
  panel's opacity drops far enough for what is behind it to cross the threshold,
  so a perfectly smooth fade reads as one frame of nothing and then a cliff.
  Which is exactly what it reported: "intermediate frames = 0", the same
  signature as the real bug in B47.

  Re-measured as a plain grey mean, the dashboard's exit is **nine frames of
  continuous change**, evenly spread, ending settled — about 150 ms, which is
  `animExit` at the 0.8 motion scale the machine was actually running at. There
  is nothing wrong with it and nothing to fix.

  The entrance findings stand, because they never rested on that number: the
  warm-reopen cut was confirmed on a filmstrip by eye, and its cause was read
  off the code — a flag set once at construction — and timed independently with
  a `FrameAnimation` reporting 54–60 ms between the map request and the first
  painted frame. **One number is not a measurement**, and a number from the
  wrong instrument is not one either.

  (Noted for whoever measures next: `Perception` had the shell at motion 0.80
  and `frost=false` for most of this work, because recording and encoding video
  on the same machine is enough load for it to start economising. Durations
  measured tonight are eight tenths of nominal.)

- **V — The three islands, in the states nobody had seen them in.** B45 changed
  the shape of the bar and was signed off on one screenshot of one content
  state, which is not a check, it is a photograph. Four states forced and
  measured; nothing was broken, and the value of writing it down is that the
  next person does not have to wonder.

  **The clock does not move.** The invariant the whole centre layout exists for.
  Rather than start a real screen recording, `BarRecorder` was forced visible in
  place — the layout is what is under test, not the recorder — and the clock was
  located by template-matching the date line, which is stable text where the
  time is not. Baseline `@60,29`; with the recorder chip inserted and the
  weather pushed along after it, `@60,29`. Not approximately: the same pixel.

  **An empty left island is a workspace island.** With the player gone the media
  chip and the divider that belongs to it both leave the row, and what remains
  is a pill sized to the desk dots with equal air at both ends — no stranded
  rule, no pill padded for content that is not there.

  **An empty tray takes its rule with it.** Same at the other end: no tray items
  and one keyboard layout leaves the right island starting cleanly at the VPN
  chip.

  **The islands cannot collide.** The left island grows rightward from the edge
  and the centre is pinned to the midpoint, so nothing structurally stops them
  meeting. In practice the track title is capped at 190px and the spectrum adds
  54, which puts the left island's ceiling near 380 against a centre island that
  starts at 935 — about 550px of slack on this display. Worth knowing rather
  than worth guarding.

  **A note on how the middle two were nearly got wrong.** The first attempt hid
  the tray with `visible: false` and reported a stranded divider — a real-looking
  bug that cannot happen. The divider asks `barTray.width > 0`, and `BarTray`
  derives its *own* visibility from that same width, so width and visibility can
  never disagree in the running shell; forcing one without the other invents a
  state and then finds a fault in it. Emptying the tray's model instead — the
  thing that actually happens when the last icon leaves — hid the rule correctly.
  A test that can produce a state the program cannot is testing itself.

- **V — The rest of the hunt for dead interactions, which came up empty.**
  B52's six invisible cards were found by accident, which is a bad way to find
  six of anything, so the same fault was looked for deliberately everywhere else.
  Nothing further is broken, and that is worth writing down once so it is not
  re-searched.

  **Only a widget that contains a `Chip` can have this fault**, because the
  shadowing needs something above that covers the *whole* widget, and `Chip` is
  the only thing in this shell that both covers its parent entirely and enables
  hover. Of the ten tooltip consumers, three read `chip.hovered` — the alias
  added the last time this bit — and the other seven (`BarClock`, `BarMedia`,
  `BarRecorder`, `BarTray`, `BarWorkspaces`, and two inside popover content)
  contain no `Chip` at all, so their own areas are the topmost thing over them.

  **`DeviceRow` looked like the same bug and is not.** Its hit area is also at
  `z: -1`, but what sits above it there is the slider and the mute button, which
  cover part of the row rather than all of it — which is exactly what the
  comment says it is for: "the slider and the mute button take their own clicks
  and only the rest of the row selects it". Verified by eye rather than by
  reading: pointer on the label area of a device row, and the row's ground
  lightens. That also closes the half of **B42** that was recorded as unverified
  — the press feedback added there hangs off this same MouseArea, so a hover
  that arrives means a press would too. The press itself still cannot be
  checked; clicking remains out (E1).

  **No dead signals.** Every widget that carries a `Chip` connects `clicked`;
  `rightClicked` is connected wherever there is a menu to open; `scrolled` is
  connected by the two chips where scrolling means something — volume and
  keyboard layout — and by nothing else, which is correct rather than missing.

  **And the tooltip still works**, which needed checking because B51 moved its
  arrival onto `PanelArm` and a tooltip whose gate never opens is exactly the
  class of bug being hunted. Hovering a desk pill produces "Рабочий стол 2 · 1
  окно · колесо — переключение", on screen, after the change.

- **B53 — Every tile in the control centre had its two lines of type through each
  other.** Found by finally looking at the control page at 3× instead of at a
  distance. "Питание" and "Сбалансированный" are not adjacent on the shipped
  panel, they are *overlapping*, and so is every other tile carrying a second
  line — which is all but three of them.

  The cause is a shape worth naming, because it reads as correct in the source.
  The name was anchored below the icon; the detail was anchored to the **bottom
  of the tile**. Neither was anchored to the other, so the leading between two
  lines of type was not a number anybody had chosen — it was whatever the tile
  had left over after both ends had taken what they wanted. At `height: 70` with
  this font ladder there was nothing left over: 12 + a 16px icon + 5 + the name
  came to about 54, and a 10px bottom margin put the detail's top at 47. Seven
  pixels of overlap, drawn faithfully, for as long as tiles have had subtitles.

  A `Column` makes the leading a value. The tile's height now comes from what is
  in it, with 70 as a floor so the grid stays even for the tiles that have only
  one line — the 70 was never a design decision about tiles, it was a number that
  was true back when none of them had a second line.

  Verified by eye at 3× on the tile that was worst, and across the whole page:
  twelve tiles, twelve pairs of lines with air between them.

- **V — The rest of the audit.** B53 came out of looking at the control page at
  3×; the same was then done to everything else that opens, and the rest is
  sound. The dashboard's Overview and Столы, the notification centre in its empty
  state, the calendar and the cheat sheet were all read at size for clipped type,
  colliding baselines, text out of its box and empty states that look like
  faults. Nothing found. The bottom row of Overview *looks* cut off in a
  screenshot cropped at 560px and is not — the panel is taller than that, which
  is worth knowing before someone fixes it.

- **V — The pill travels, and it is the best thing in the shell.** The marker in
  `BarWorkspaces` moves on every desk switch, which makes it the most-repeated
  deliberate animation here after hover, and it had never been looked at — it was
  written, argued for in `Direction` rule 7, and then trusted.

  Recorded at 60fps across `focus-workspace 4`. Seven frames of travel, 46px,
  decelerating cleanly: +13, +10, +7, +6, +4.5, +3, +1, then settling. That
  first-frame 28% is `easeSpring` doing what B46 rebuilt it to do — before, the
  same curve was 77% through the journey by a fifth of its duration and then
  overshot 14%, which at this size is a twitch rather than a movement.

  The deformation is visible on the strip and it is the whole point: the pill
  stretches along its direction of travel as it sets off, carries its glow with
  it, and rounds back up as it lands. It reads as one object with mass going
  somewhere, not as a highlight being repainted in a new cell — which is exactly
  the claim rule 7 makes and the first time anyone has checked it.

  The desk number is held back and fades in after the pill has arrived, as its
  comment says it should. Nothing to fix here; recorded because "the most-seen
  motion in the shell is good" is worth knowing as firmly as the opposite.

- **V — The toast arrives properly too.** `NotificationCenter` was on B51's list
  of surfaces that map their own window, and the toast is the other animation
  that happens without being asked for, so it was filmed as well. Triggered with
  `notify-send`, which is a D-Bus call rather than synthetic input and therefore
  allowed under E1.

  Seven frames of continuous arrival: the card fades in *and* grows from
  `revealScale`, settling at full size — `CascadeEntry` doing what it says.
  Nothing to fix.

  One measurement note, since it wasted a take. The first recording covered a
  620×400 region and reported no toast at all: the card is dark, the region
  behind it is dark wallpaper, and 330×55 of very slightly different dark inside
  400 lines of it moves a mean brightness by less than the threshold. The toast
  was there the whole time — a full-screen grab found it immediately. Frame the
  region to the thing being measured, or the instrument answers about the
  wallpaper.

- **V — And the launcher, which is the one they named.** Filmed on a *warm*
  reopen specifically, because that is the case B47 was about and the case the
  user meets every time but the first: the loader lingers, so the second open
  onward reused a live object whose arming had already fired.

  Ten frames of continuous arrival, decelerating — the card drops from
  `revealSlide` and fades up, visibly translucent for the first half of it. Under
  the old arrangement this exact sequence was one frame from nothing to a fully
  painted 620px card.

  The strip also shows *Firefox* selected throughout, which is B43 still holding:
  the top match owns the selection on open, and the pointer parked elsewhere on
  screen does not take it.

  That closes the sweep. Every surface that arrives in this shell has now been
  filmed at 60fps: the dashboard in and out, the OSD, the launcher, the toast,
  the workspace pill, and the bar's own three islands. The ones that were cuts
  are movements; the ones that were already right — the exit, the pill, the toast
  — are recorded as right so nobody rewrites them looking for a bug.

- **V — Three islands cost less glass than one strip did, not three times more.**
  The obvious worry about B45, raised against itself: one full-width `Surface`
  became three, each with its own `FrostedBackground` sampling at its own offset,
  which reads like three blur passes where there was one. On a shell held under
  20% of a core that would be the kind of regression this file exists to catch.

  It is not one, for two reasons, and the first makes the second almost
  redundant.

  **There is no blur pass.** `FrostedBackground` has not computed a blur since
  the wallpaper pipeline started writing a pre-blurred copy to disk — its own
  comment says so: what used to be twenty `MultiEffect` chains all computing the
  same image is now "four plain draws over one small shared texture", the same
  cached pixmap in every surface, offset by each one's screen position. Three
  surfaces are three clipped draws of one texture, not three anythings.

  **And the area went down.** The strip clipped that texture across the whole
  1910px width; the islands clip it across about 1150 — 68,760 px² against
  41,472, or **60% of what it was**. The change made the frosted layer cheaper.

  Measured anyway, since arithmetic about a renderer is a hypothesis: shell CPU
  off `/proc`, utime+stime over fixed 15s windows rather than sampled by `top`.
  Flat, as the machine actually runs: **5.3% and 5.6%** of one core. Frosted:
  5.3% and 7.6%. Frosted with two of the three surfaces switched to plain fill —
  same geometry, one texture draw instead of three: 7.8%, 5.2%, 4.9%. The two
  conditions overlap completely, which is the honest result: the difference is
  under the noise floor of a desktop with music playing and a clock ticking, and
  everything is a quarter of the budget.

  Worth recording separately: **this machine runs the shell flat.** `frostWanted`
  is false and persisted in `prefs.json`, which is why the control centre's
  material tile reads "плоское". The frosted path was forced on for the
  measurement and put back; the saved preference is false again, confirmed in
  the file.

- **B54 — The documents described a shell that had stopped existing.** This repo
  keeps catching itself at this — `Bar.qml` carried a paragraph calling the bar
  "separate floating islands" for two rewrites after it had stopped being them —
  so after a night of changing the bar's shape and the whole motion vocabulary,
  every claim in the three documents was checked against the tree rather than
  assumed to have kept up.

  **`Direction.md`** described the bar as one strip throughout. Corrected, and
  the note about the choreography now says what actually improved: three islands
  each in their own `Reveal` means the thing that scales and fades *is* the
  object you can see, where the strip grew as one surface while its contents slid
  about inside it — two events drawn as one thing. The composer paragraph
  described the clock opening room to its left as the player grew, which is the
  old geometry; it is the centre island widening around it now, and that has been
  measured since.

  Its "Not done" list had **the same bullet twice**, one of them ending "for the
  reason above" and pointing at the other. Merged.

  And it gained the section it most needed: everything in that file describes
  what the code does, and for most of the time it described something **nobody
  could see** — the curves finished each beat before the next began, and the
  arrival ran 50–60 ms before the surface reached the screen. The document
  asserted a choreography that was not being played. It now records that the
  sequence is filmed rather than asserted.

  **`README.md`** listed `ControlCenter.qml` in its file table. That file does
  not exist and has not for some time; the control centre is a dashboard page,
  which is what `Mod+P` actually opens. Its "Budget" section pointed the reader
  at `~/.claude/jobs/*/tmp/wallbench.sh` — a scratch directory that gets
  collected, so the instruction had already rotted to nothing. The *method* is
  what was worth keeping, so it is four lines of inline shell now, reading
  `utime+stime` off `/proc` rather than sampling with `top`, plus the honest
  warning that two runs of the same configuration differ by two or three points
  on a live desktop.

  It also gained a section that would have saved this project a night:
  **the greeter does not run from this directory.** `greetd` loads
  `/usr/share/yoake/greeter/`, everything under `greeter/` here is source for a
  package, and from inside the repo the installed copy and the committed one are
  indistinguishable — git is perfectly happy, and the file it is happy about is
  not the file being executed. See B49.

  Amusing, and left alone: the README's file table has said "the three bar
  islands" all along. It was wrong for the whole time the bar was one strip and
  is correct again now, without anybody touching it.

- **B55 — The bar has been missing its player after every login, and the fault
  was a measurement that starved itself.** Found by restarting the shell rather
  than reloading it, which nobody had done in a long time: everything above was
  developed against a process that has been hot-reloading since 10 August.

  On a cold start, with a player already playing, the left island came up as bare
  desk dots. Two minutes later, still bare. Edit any file in this directory and
  the title appears at once — which is exactly why this survived: **the state a
  login leaves the bar in is one that no one working on the shell ever sees.**

  Three layers of the same shape, and only the innermost was load-bearing:

      root:      width: mediaRow.width      visible: width > 0
      spectrum:  width: Cava.active ? …     visible: width > 0
      title:     width: min(implicitWidth, 190)   visible: width > 0

  Each says "hide me if I came out empty", and each is a claim about a width that
  is itself derived from what is inside. Fixing the outer two was not enough and
  the probes said so: the chip became visible and still measured nothing.

  **The title is the latch.** Its width is bound to its own `implicitWidth` and it
  elides. The chip is built before MPRIS has answered, so the text is empty and
  the width is 0; the title arrives a moment later, Qt elides a 35-character
  string into zero pixels, and `implicitWidth` for a fully elided string is 0. The
  width is bound to a measurement taken *through* the width. Once it is 0 there is
  no path back, and the usual `Math.min(implicitWidth, cap)` idiom is what builds
  the trap.

  Proved rather than reasoned: a second `Text` with the same string and the same
  font, no explicit width and no elide, was put beside it and both were logged on
  a cold start. **230.78 against 0.** Same text, same font, same frame.

  `TextMetrics` is the fix. It measures a string against a font without being in
  the layout, so nothing can starve it, and the visible Text keeps its elide
  without being asked to measure itself. The two outer guards keep a `|| width > 0`
  term so a collapse still animates, but each now leads with the thing it is
  actually about — `Media.hasPlayer`, `Cava.active`, `text.length > 0`.

  And one thing that was visible all along: the track title was the **only** label
  in the bar that let its font family default, on a bar that is JetBrains Mono
  everywhere else. It was the one proportional thing on screen and nobody had
  named it. It is named now.

  Verified on a cold start, five restarts deep: the chip comes up with the title
  in it, elided at the cap, in the same face as everything beside it.

- **E2 — A prophylactic fix for a bug that was not happening broke a thing that
  was working.** Recorded because the reasoning was sound at every step and the
  result was still a regression.

  B55 found the latch — a `Text` whose width is bound to its own `implicitWidth`
  while it elides — and the obvious next move was to look for the same shape
  elsewhere. It is in two more places: `KeyValue`, in four system panels, where
  the width also depends on a `root.width` that starts at 0 and so *can* reach
  the latch; and the tooltip's subtext. Neither was failing. Both got the same
  `TextMetrics` treatment anyway, on the argument that it is the same one line
  and there is no reason to leave it armed.

  It cost "Сигнал" its last two letters. `TextMetrics.width` is not
  interchangeable with a `Text`'s `implicitWidth` — the measurement is close but
  not equal, and in `KeyValue` it feeds the row's own `implicitWidth`, so a
  slightly smaller number shrinks the row, which shrinks the space left for the
  key, which elides it. Caught only because the panels were screenshotted after
  the change and compared against a capture from three hours earlier: **Приём /
  отдача → Приём / отда…**, **Сигнал → Сигн…**.

  Both reverted. `BarMedia` keeps the fix, because there the bug is real,
  reproduced on five cold starts, and measured at 230.78 against 0.

  The rule this leaves: **a fix for a fault nobody has observed has to clear a
  higher bar than one that has been, not a lower one.** The proven case justified
  a change to the mechanism; the unproven ones justified nothing, and "same shape,
  same line, why not" is how a night of careful work ships a typographic
  regression into four panels.

- **B56 — The audio device list had no order at all.** Found by the cold-start
  audit B55's method suggested: photograph every surface as a login leaves it,
  reload, photograph again, and treat any difference as a fault.

  The audio sheet differed by seven times as much as anything else. Not a
  rendering fault — the **rows had swapped places.** The equalizer above the
  sound card on the cold start, below it after the reload, in the same session,
  with nothing changed but when the list happened to be built.

  `sinks`, `sources` and `streams` were three plain `filter` calls, so the order
  on screen was whatever order PipeWire enumerated its nodes in. That is not a
  stable thing to lean on, and a list you pick from **by position** must not
  shuffle between logins — the position is the only thing you remember about a
  device you switch to twice a week.

  Sorted by the name the person actually reads, with the node id as a tiebreak so
  two devices with the same description still have a fixed order. Deliberately
  *not* hoisting the default to the top: it is already marked, and sorting on it
  would rearrange the list under the pointer at the exact moment you switch,
  which is the one moment you are certainly looking at it.

  Verified by eye: sound card then equalizer, alphabetical, and it stays there.

- **B57 — And the tray was in whatever order the applications woke up in.** The
  same audit, the same fault, one widget over: bluetooth and the signal meter
  swapped places between the cold start and the reload.

  `SystemTray.items.values` arrives in the order applications claimed their
  slots, which is a race between programs starting at login. Tray icons are
  aimed at with a mouse and are small enough that **position is most of how they
  are found** — an icon that is third today and second tomorrow defeats the only
  thing anybody remembers about a tray.

  Sorted by `id`, the application's own name, which does not move about the way a
  title does; `title` breaks a tie. Verified across a cold start and a reload:
  the same three icons in the same three places, which is the whole requirement.

- **V — The rest of the cold-start audit.** The method, which is worth keeping:
  cold restart, photograph the bar and every panel, force a reload, photograph
  the same set, and treat any difference as a fault until shown otherwise. It
  found two (B56, B57) out of eight surfaces.

  A whole-image RMSE is only a way of ranking what to look at, not a verdict —
  every surface differs, because a clock ticks and a CPU meter moves. What
  separates a fault from live data is looking at the pair. The audio sheet was
  seven times any other and was real; the network sheet was the next largest and
  was **clean** — the entire difference was the signal strength reading 79%
  against 82%. The dashboard likewise: 19% CPU against 22%, and a spectrum caught
  mid-bar.

  Checked and sound: the network sheet, the dashboard, bluetooth, and — below the
  network sheet's difference, which is the clean baseline — power, weather and
  the notification centre.

  **Not tested: the bluetooth device order.** It is the same shape as the audio
  list, and there are no devices paired on this machine, so the audit could not
  see it. It is left alone deliberately rather than sorted on suspicion: its list
  comes from parsing `bluetoothctl devices`, which is one program's output rather
  than a race between several, so the reasoning that condemned the tray does not
  transfer. E2 is the standing instruction here — an unobserved fault has to
  clear a higher bar, not a lower one — and E2 was written the same night, about
  exactly this temptation.

- **V — The shell at the ends of its own ranges, which nobody had rendered.**
  `Perception` moves density, ink and emphasis continuously from CPU, daylight
  and dwell, and the shell is only ever *seen* somewhere in the middle of those
  ranges — the extremes are reachable in ordinary use (3am, heavy load, a long
  dwell) and had never been put on screen deliberately. This is the most concrete
  corner of "требует глобальной доработки", so it was swept.

  Forced each axis to both ends over IPC and photographed the bar and the control
  page at each:

  | axis | range | rendered |
  |---|---|---|
  | density | 0.76 – 1.36 (gapWide 9 – 16) | clean at both |
  | ink | 0.72 – 1.00 | legible at 0.72, titles and subtitles both |
  | emphasis | 0.70 – 1.15 (chrome 1.00 – 0.55) | clean |

  Nothing broke. No clipped type, no collisions, no tile that stopped fitting
  what is in it, and the faintest ink is still comfortably readable — including
  the section headers, which are the dimmest thing in the shell and were the
  likeliest casualty.

  Worth one specific note: **B53's tile fix holds at the tightest density.** That
  was the failure mode to fear here — the control-centre tile now takes its
  height from its content, and the tightest gap ladder is exactly where a
  content-derived height could have gone back to overlapping. It does not; the
  two lines keep their air at `gapWide 9`.

  Released afterwards; `perception auto` confirmed back on observation.

- **B58 — The lock screen began its entrance a frame after being asked for, and
  arrives about fifty milliseconds later than that.** The one surface never
  examined tonight, because it is the one that cannot be examined: the README is
  explicit that there is deliberately no unlock over IPC, so locking it to look
  at it would leave the session locked until its owner came back and typed a
  password. Audited by reading instead, against the three faults found tonight.

  Two of the three do not apply, and it is worth saying why rather than leaving
  it silent. There is no `implicitWidth` latch — its two elided labels take their
  width from anchors, not from measuring themselves (B55). Its lists are a static
  array and a count of password dots, so there is nothing to sort (B56, B57).

  The third does, in a milder form. It waits **16 ms** — one frame — between the
  surface being constructed and its arrival starting, and the map takes 54 to
  60 ms on this machine, measured directly with a `FrameAnimation` while chasing
  B47. So the fade, the drop and the wallpaper's scale all begin before there is
  anything on screen to see them on. It is `Theme.animMap` now, which is the
  number that measurement produced and which thirteen panels and the OSD already
  use.

  Not the full B47 fault, and the difference matters: `WlSessionLockSurface` is a
  delegate the lock creates per output *when it engages*, so the object really is
  rebuilt on every lock and the flag cannot go stale the way the panels' did.
  Only the wait was wrong.

  **Not verified by eye, and it cannot be** — that is the whole reason this
  surface was still unexamined at the end of the night. What is verified: the
  shell loads clean with the change, lint is at zero, and `entered` gates nothing
  but opacity, scale and y, so the edit cannot affect whether the screen locks,
  takes a password or unlocks. The measurement it rests on was taken on this
  machine, not assumed.

- **V — The machine has not locked itself since 8 August, and that is the user's
  own doing.** Noticed while looking at the idle chain: no input for two and a
  half hours, and the session unlocked, undimmed, screen on.

  Not a fault. `/run/user/1000/yoake/keep-awake` is present, dated 8 August, and
  `yoake-idle.sh` exits early on `dim|lock|screen-off|suspend` while it exists.
  The control centre says so plainly — the "Не засыпать" tile is in its active
  colour reading "экран не гаснет" — and `qs ipc call idle state` agrees. Every
  layer is telling the truth and they all agree with each other.

  Recorded because the next person to notice a machine that never locks will
  reach for the idle chain, and the answer is a toggle somebody left on five days
  ago. Worth the user knowing; not worth anything changing.

- **B59 — And the greeter had the same line, because it is the lock screen's
  twin.** The installer says so out loud — "the greeter is meant to be the lock
  screen's twin, and two copies of the clock is exactly how twins stop matching"
  — and the resemblance held for the fault as well: an identical single-frame
  wait before an entrance that drives the same scale, opacity and travel.

  `Theme.animMap` there too, which meant adding the token to the greeter's own
  `Theme.qml`. It has its own copy of the vocabulary on purpose — the greeter
  runs as its own user and cannot read this directory — and that copy carries a
  paragraph about why `Perception` deliberately does not run on a login screen.
  The new token is exempt from it for the same reason it does not scale in the
  session: a map takes as long at three in the morning as it does at noon.

  Audited for the other two faults while there, and neither applies: no width
  bound to its own `implicitWidth`, and its only lists are the environments file
  (first line taken), a count of password dots and a static array.

  **Verified**, unlike its twin — this is the one of the pair that can be looked
  at. Staged exactly as the installer lays it out and run nested under `cage`:
  it loads with no new warning, and renders whole — clock, date, avatar, the
  password field, the session name, the sleeping cat and the power row.

  It is still not on the machine. `greeter/` is source for a package (see the
  README), so this rides along with B49 whenever the installer is next run.

- **B60 — The desktop clock justified itself with a behaviour that had been
  deliberately removed.** Not a functional fault; a claim the source makes about
  itself that stopped being true, in the file explaining the biggest design
  decision on the desktop.

  `WidgetClock` opens by saying the seconds are gone, which is right, and gives
  two reasons. The second was "the separator already pulses on the second, so the
  beat they were there for was never theirs to carry."

  It does not pulse. `RollClock.blink` is off, off *by default*, and set nowhere
  in the tree — because two three-pixel dots breathing cost **twenty points of a
  core**: any running animation holds its window's render loop at the refresh
  rate and this window is the size of the screen. `RollClock` carries that
  measurement, and switching it off along with the sleeping cat's floating "z"
  took the shell from 48% of a core to 27% with nothing playing and nothing
  moving. The change was correct and the file that depended on it was never
  updated.

  Caught by photographing the colon four times a third of a second apart while
  auditing the desktop widgets, and finding all four **identical to six decimal
  places**. Then reading why.

  The comment is fixed, not the code. The argument is *better* without the
  pulse, not weaker: rule 6 says only what is in focus may move, and a clock on
  the wallpaper is never what anybody is looking at. Restoring a pulse to make
  the old sentence true would have been paying twenty points of a core for a
  footnote.

  The rest of the desktop widgets were audited at the same time and are sound —
  no width measured through an elide, no entrance gated on a flag that cannot
  reset, nothing unsorted. The media card's dimmed "next" is `MediaButton`'s
  disabled state, which is correct for a track with no successor.

- **V — All of it, at once, from a cold start.** Thirty commits touched the bar,
  the motion vocabulary, thirteen panels, the OSD, menus, popovers, tooltips, two
  orderings and the media chip. Each was verified when it was made; none had been
  verified against all the others, and a night of individually-correct changes is
  not the same claim as a shell that works.

  Cold-started from committed code with a clean tree, then checked in one sweep,
  pointer parked away from everything:

  | | |
  |---|---|
  | B43 launcher | *Firefox* — the top match — holds the selection |
  | B45 bar | three islands, wallpaper between them, no dead strip |
  | B48 hover | the bell chip lights and its glyph goes to full ink |
  | B52 popover | the notification card opens under the pointer |
  | B53 tiles | "Питание" and "Сбалансированный" with air between them |
  | B55 media | the title is in the bar at login, elided at the cap |
  | B56 audio | sound card then equalizer, alphabetical |
  | B57 tray | the same three icons in the same three places |

  Zero load failures, lint at zero. The state a login leaves this shell in is now
  a state somebody has looked at — which, at the start of the night, was the one
  thing nobody had ever done.

- **B61 — The shell menu resolved each favourite's icon and then drew a grid
  instead.** Found by rendering the three launcher modes nobody had looked at.

  `ShellActions` builds its favourites through `DesktopEntries`, and says why in
  a comment directly above: "Resolved through DesktopEntries so the real Exec
  line **and icon** are used rather than a guessed command". It takes
  `entry.name` and `entry.command` and then hardcodes `glyph: Glyphs.apps`. So
  pavucontrol, Nautilus and kitty appeared as three identical generic grids —
  in the shell menu on every right-click, and in the launcher's `>` list.

  Every piece needed was already in the tree and none of them were wired
  together: `DesktopEntry.icon` is what three other files already read,
  `LauncherRow` has an `iconName` that resolves through `Icons.forName`, and
  `MenuItemRow` has an `iconSource` written for tray entries. The icon is carried
  now, documented in `ActionMenu`'s model shape, and wins over `glyph` where both
  are given — an application in a menu should look like itself rather than like
  the idea of an application.

  Verified by eye in the launcher's action list: pavucontrol's dial, Nautilus's
  folder and kitty's cat, with the three real shell actions keeping their glyphs.
  **The right-click menu is not verified** — opening it needs a click, and no
  synthetic click has been used tonight — but it reads the same field through the
  same row component.

- **V — All four launcher modes render.** Only the application list had ever been
  seen. Typing is banned, so each mode was reached the way `BarRecorder` and
  `BarMedia` were driven earlier: seed `input.text` in `opened()`, photograph,
  revert.

  `/` lists the three open windows with their real icons, titles and app ids.
  `>` is above. `=` takes `12*8+5` and answers **101**, with the expression kept
  as the subtitle so the arithmetic can be checked by eye. A render test only —
  it says nothing about ranking — but three of the four modes had never been on
  screen in front of anybody, and now they have.

- **F1 — Six panels compute a colour and hand it to something that throws it
  away.** A finding, recorded without a fix, for the reason under it.

  `Sheet` declares `property color accent` and never reads it. Six panels set it:
  `Theme.tone("audio")`, `"bt"`, `"net"`, `"power"`, `"vpn"` and `Theme.accent`
  for the player. `Segmented` is the same story and worse — it takes a `tone`
  that four panels supply and that nothing reads, twenty-five lines above a
  comment explaining exactly why it cannot be used: *"accent means chosen, domain
  means what the panel is about, and a control cannot hold both jobs."*

  Both are leftovers from before that decision. The discard is correct; the
  passing is the mistake, and from a call site `tone: "vpn"` reads exactly like a
  strip that is violet.

- **E2 (again) — and this time it drew blood twice in one attempt.** E2 was
  written earlier tonight after a prophylactic `TextMetrics` fix cost "Сигнал"
  two letters. The rule it left was: *a fix for a fault nobody has observed has
  to clear a higher bar, not a lower one.* Removing the dead properties above is
  cleanup with **no user-visible benefit at all**, which is a lower bar than
  that, and it went exactly as E2 predicts.

  Three rounds of correction, each caused by a search that was narrower than the
  thing it was searching for:

  - `grep -A6` after `Sheet {` found no `accent:` callers. There were six; the
    assignment sits below the window it looked at. Removing the property broke
    the config load.
  - `grep -A4` after `Segmented {` found four `tone:` callers. There were ten,
    across seven files, and `PowerPanel` was never in the list.
  - deleting the stragglers **by line number** hit a line that had shifted under
    an earlier edit, and took `tone: "audio"` off a `LevelTile` — a live property
    on a different component, which would have silently drained the volume tile
    of its domain colour. Caught only by reading the whole diff rather than the
    tool's summary.

  All of it reverted; the tree is back at HEAD and the panels were reopened and
  photographed to prove it. **No code changed this cycle, which is the correct
  outcome.**

  What generalises, beyond E2: an `awk` that sets a flag on `Segmented {` and
  never clears it will report every `tone:` in the rest of the file as belonging
  to it. Three of tonight's near-misses were a matcher that could not see the end
  of the thing it was matching, and a cleanup pass is exactly where that is most
  dangerous — the edits are mechanical, they look alike, and nothing on screen
  changes when one lands in the wrong place.

- **V — The one command the night ends on, checked before it is handed over.**
  Everything else here is verified; the greeter fixes are the exception, because
  `greeter/` is source for a package and nothing lands until
  `sudo bin/yoake-greeter-install` is run. Handing somebody a command that fails
  on a missing precondition is handing them nothing, so the script was read and
  every condition it can exit on was checked without running it.

  It is `set -euo pipefail` and has two hard exits: a `find` for
  `MaterialSymbolsRounded*.ttf` across three roots, and `getent passwd greeter`.
  Both pass — the font resolves to `~/.local/share/fonts/MaterialSymbolsRounded.ttf`,
  the account exists. All eight files it copies are present.

  And what it would actually change is small, which is worth knowing before
  running anything as root against a login screen. Of the eight, six are already
  identical on disk — `qmldir`, both clock files, both `bin` scripts and the cat.
  Two differ:

  - `greeter/Theme.qml`, by exactly one line of code: `animMap: 90`
  - `greeter/shell.qml`, by the `creating` flag and its guard timer (B41), the
    `launching` latch and its six guard sites (B49), and `interval: 16` becoming
    `Theme.animMap` (B59)

  Every added line of code in that diff belongs to one of those three, checked by
  stripping the comments and reading what was left. Nothing else rides along.

- **B62 — The lint now knows the latch, because reading for it is cheaper than
  restarting for it.** `bin/yoake-lint` opens by saying what it is for:
  "patterns that have already been bugs in this shell, looked for everywhere...
  each was invisible: nothing was logged, nothing threw, something simply did
  not appear." That is B55 word for word, and B55 was not in it.

  The shape it now looks for is a `Text` whose `width` is bound to its **own**
  `implicitWidth` while it elides. A sibling's `implicitWidth` is fine — the
  thing measured is not the thing being sized — so the match is on a bare
  identifier, and only on the block's own lines, not a nested `Behavior`'s.

  **Proven against the bug it was written for.** Run over a throwaway copy of
  the tree with `BarMedia.qml` restored to its state before the fix, it reports
  `BarMedia.qml:88` — the line that cost the bar its player after every login for
  months. On the tree as it stands it says nothing about that file.

  It found **four** live instances, and two of them are ones the manual hunt had
  missed: `MenuItemRow` and `ToggleRow`, alongside the `KeyValue` and tooltip
  cases already known from F1. That is the check earning its place on the day it
  was added — a grep written by hand found two, and a scanner that understands
  block structure found four.

  **Reported, not counted**, in the drift channel this file already has for
  exactly this tension: "design debt, not bugs... Green still means the shell
  works." None of the four has been observed failing — each takes its text at
  construction rather than having it arrive late, and `ToggleRow` additionally
  gates its visibility on `root.detail !== ""`, which is the *safe* form of the
  test that deadlocked `BarMedia`. Removing the shape from two of them was tried
  earlier tonight and reverted at the cost of four panels' key labels (E2). So
  the knowledge is captured and the code is left alone, which is the whole
  argument for having an uncounted channel.

  Lint stays at **0 findings**.

- **F2 — The one undesigned surface in the shell, recorded rather than
  redecorated.** The VPN panel was the last large surface nobody had opened at
  full size tonight. It is good — until the bottom, where the core's error is
  printed raw:

      -0400 2026-08-14 04:10:11 ERROR [386494647 6m40s] connection: connection
      upload closed: read tcp 160.79.104.10:443: software caused connection abort

  Three things are true about it and only one of them is this repository's
  business.

  **It begins mid-line.** `-0400` is the tail of a timezone offset, not the
  start of anything, and the `Text` renders with `wrapMode` and no elide — so
  that really is where the string starts, not where a wrap put it. The beginning
  was already gone before the shell saw it. `lastError` is `j.error` from the
  yworld CLI's JSON, so whatever cuts it cuts it there. **Out of scope**: that is
  a different project, and reaching into it at two in the morning to fix a
  truncation I cannot test is exactly the move E2 exists to refuse.

  **It can be clipped away entirely.** The sheet is `Math.min(740, ...)` and the
  error is the last thing in the column, so a long enough one is simply cut off
  at the panel's edge — silently, with no sign that there was more. The buttons
  above it are safe; the diagnostic is the thing that disappears.

  **And it is the least designed thing in the shell** — a raw multi-line log dump
  in red micro type under a panel that is otherwise carefully composed.

  Left alone. Improving it means deciding what should be shown instead — first
  line only, a capped line count with an elide, a "details" affordance — and
  every one of those is a judgement about how much of a failure a person wants
  in their face, which is the owner's call and not mine to guess at while he is
  asleep. Recorded so it can be decided rather than discovered.

## The night, indexed

Twenty entries and a dozen verifications is more than anybody wants to read
front to back to find one thing. What was actually wrong, in the order it was
found:

**What was reported**

| | |
|---|---|
| B43 | the launcher's selection belonged to the mouse, not the keyboard |
| B44 | the dashboard peek could not be told to go away, and never could have been |
| B45 | the bar drew nine hundred pixels of nothing as carefully as the rest |
| B46 | every curve spent its whole duration in the first tenth of it |
| B47 | thirteen panels played their entrance before the surface existed |
| B48 | hover was painted in the token that means *no* response |
| B49 | the greeter fix was never installed, and was half a fix besides |
| B58, B59 | the lock screen and the greeter began arriving a frame in |

**What was not reported, and was worse**

| | |
|---|---|
| B52 | six popover cards that had never once opened, because `z` is not hover order |
| B53 | every control-centre tile had its two lines of type through each other |
| B55 | the bar lost its player after **every login** — a width measured through its own elide |
| B56, B57 | the audio list and the tray were in whatever order the machine woke up in |
| B61 | the shell menu resolved each icon and then drew a generic grid |
| B60, B54 | two documents and a file header describing a shell that had moved on |

**What was checked and found sound** — so nobody re-searches it: the panel exit,
the workspace pill, the toast, all four launcher modes, the islands in every
content state, both ends of every `Perception` axis, the desktop widgets, and the
glass cost of three islands against one strip (it went *down*).

**What was found and deliberately left** — F1, six panels tinting a sheet that
ignores them; F2, the core's raw log under the VPN panel.

**What it cost to learn that** — E2, twice. A fix for a fault nobody has observed
clears a *higher* bar, not a lower one. Both attempts at one were reverted, one
of them after it had already taken the ends off four panels' labels.

**What is left for a person** — `sudo bin/yoake-greeter-install`. Everything else
is on the machine and verified; that one needs a password, and the README now
says why a fix can sit in this repository for days without being on the machine.

- **V — Memory, measured at idle only, and the rest left undone.** Tonight added
  objects that live per panel — a `PanelArm` in thirteen of them plus the OSD,
  the menus, the popover and the tooltip; `HoverHandler`s in five bar widgets; a
  `TextMetrics` in `BarMedia`. `LazyPanel` builds and destroys a panel on every
  open, so anything retained there compounds with use, and the performance
  contract governs CPU and says nothing about memory.

  What was measured, on an instance seven hours old: **636.4, 636.1, 636.1 MiB**
  across thirty seconds of idle, and **625.3** a few minutes later — it went
  *down*. That is the useful shape of the answer. A leak does not give memory
  back, so whatever this is, it is not a simple one.

  What was **not** measured: the case that would actually show a leak, which is
  building and destroying all thirteen panels repeatedly and watching the number
  after each round. That sweep flashes every panel on screen for several minutes,
  and it was stopped rather than run. It is the right test and it wants doing
  when somebody is at the machine to watch it.

  One number worth carrying to whoever does: the instance that had been up since
  10 August was at **1.19 GB**. Three days against seven hours is not a
  comparison — different uptimes, a video wallpaper decoding for some of it, and
  no idea how many panel cycles in between — but it is the only other data point
  that exists, and a fourfold gap is worth confirming or dismissing deliberately
  rather than noticing later.

- **F1, two more instances — and the scan that should have found them all along.**
  F1 was found by eye, which is the wrong way to find the fifth instance of
  anything. The scan that was supposed to find it reported **279 rows** and was
  therefore ignored, and it was wrong: it excluded any line matching the
  declaration pattern, so a property used inside *another* property's binding
  counted as unused. That is why it accused `Tooltip.active`, which the line
  directly below its declaration reads.

  Counting every mention in the file and subtracting the declaration's own gives
  **18 rows**, and eighteen is a list somebody reads. Most are legitimate: the
  three `BarStrip` item aliases, five `default property alias content` targets,
  `ManagedProcess`'s three passthroughs, and two real outputs that callers read
  through an id — `BarClock.anchorX`, which `Bar` centres the strip on, and
  `WidgetRail.cardItem`, which `DesktopSurface` masks against.

  Two are the F1 shape, and neither had been noticed:

  - **`BarLoad.barWindow`** — `Bar.qml` passes `barWindow: bar` to it, as it does
    to every other bar widget, and `BarLoad` never mentions it again. The others
    use it for `Menus.idFor`, scoping a menu to the output. `BarLoad` has no
    menu. From the call site it reads exactly like a widget that does.
  - **`Sheet.progress`** — `readonly property real progress: root._drive`,
    computed on every frame of every sheet's entrance and exit, exposed, and read
    by nobody.

  **Left alone, with the other two.** Not because they are risky — these are two
  single-line removals, unlike the ten call sites that went wrong earlier — but
  because fixing two of five instances of one class leaves the tree *less*
  coherent than fixing none. F1 is a decision about a shape, and it wants making
  once, by somebody who can also decide whether `Segmented` should honour a tone
  rather than drop the property. The list is complete now, which is what was
  missing.

- **B63 — Restarting the shell quietly killed the particle overlay, every time.**
  Found by noticing it was gone: after a night of restarts there was one `qs`
  running where niri starts two.

  `bin/yoake-shell` exists to stop a second copy of the shell, and its own
  comment is precise about why — two instances mean two of everything, including
  a second decoder for a video wallpaper, "36.8% and 18.9% of a core, both
  drawing the same desktop". What it actually did was kill **every** `qs` process
  except the greeter, and "another `qs`" is not the same claim as "a second copy
  of this shell".

  niri starts a second one on purpose. The particle overlay over AyuGram is its
  own process precisely so that a stall in a per-particle animation cannot take
  the bar and the notifications down with it — `30-startup.kdl` says so in as
  many words. Nothing restarts it, so every shell restart took it out until the
  next login, and nothing anywhere reported it. Two comments, one in each file,
  each correct, describing a collision neither could see.

  The test is now the configuration rather than the binary: an instance pointed
  at a *different* `-p` is a different program that happens to share the
  executable, and is left alone. A bare `qs` still counts, because it loads this
  same configuration by default, which is the two-shells case the file opens by
  describing. The greeter's own guard stays — it is a different reason (another
  user, none of our business) and costs nothing.

  Verified twice. `others()` run in isolation against the live pair selects the
  shell and spares the overlay; then a real restart, end to end: the shell's pid
  changed and the overlay's did not. The overlay is running again — it was
  restarted by hand first, since this fix stops the next one being killed but
  cannot bring back the one that already was.

## The redesign, night two

Asked for outright: rework the design, my own way, no advice to follow. What
follows is opinion rather than repair, and it is written down as opinion.

- **D1 — The shell was built like an instrument and dressed like a terminal.**
  The engineering underneath is good: token ladders with stated roles, a domain
  vocabulary, a motion system that is now measured rather than asserted. What it
  had no answer for is **voice**. Every word on screen — every heading, every
  sentence, every button, every device name — was set in JetBrains Mono, and 26
  of the 34 weight declarations in the tree were the same weight. Panel after
  panel of well-organised console.

  The old argument for one face is quoted in `Theme` and half of it is right, so
  half of it is kept: **data wants a column.** A device list, a bitrate, a node
  id, an SSID, a clock — set proportionally these do not line up, and a panel
  full of them reads as a heap of words of assorted widths. That is true.

  What it got wrong was the word *everything*. A heading is not tabular. Neither
  is "Ничего не подключено", or a button, or a track title.

  Three faces by role:

  | | | |
  |---|---|---|
  | `fontFamily` | Inter | prose — labels, headings, sentences, names |
  | `fontDisplayFamily` | Inter Display | the optical cut, for large type |
  | `fontMonoFamily` | JetBrains Mono | data, and anything that forms a column |

  **The split needed no taste to apply, because the tree already declared it.**
  Thirty-eight elements carry `font.features: tnum` — a statement that the thing
  being drawn is a number in a column. The face now follows a marking the code
  was already making; 35 of those moved to mono automatically, and the ones that
  did not were where a caller had marked a label by mistake.

  Inter Display is a real optical variant rather than the same drawing enlarged —
  tighter spacing, smaller apertures, less of the generosity a face needs at 11px
  and does not want at 112. `RollClock` already defaulted to the display token,
  so the hero clock and the desktop clock changed face the moment the token did.

  Verified by eye across the bar, the network sheet, the media card and the
  desktop: "RU", "AUTO", "Archer C80" now read as words; "50%", "0:50", "-1:28",
  "79%" keep their column; the 112px clock is drawn by a face made for that size.

- **D2 — The widest thing on the desktop was the one saying least.** Under a
  112px clock sat a band of twenty-eight round dots, four hundred and forty
  pixels across, permanently. It read as a loading indicator.

  It was not thoughtless — the dots form an arch, taller in the middle, and the
  file argues that "at rest the band pulls back rather than leaving: still
  there, plainly not the thing to look at." The intent is right and the drawing
  does not carry it. Twenty-eight identical pills is not a band pulling back, it
  is a row of dots, and it was the widest element in a composition whose hero had
  earned that width.

  Flattening the pills into a hairline was the obvious fix and it does not work
  either: twenty-eight rounded rectangles laid edge to edge do not make a line,
  they make twenty-eight antialiased seams, and the result is a **dashed** rule.
  Worth recording because it cost a probe to believe — `gap=0 fill=0.00`, so the
  geometry was already flush and every break was a pill's own rounded end.

  Silence gets an object of its own now: **one rule**, two pixels, fading out at
  both ends rather than stopping. The arch's idea survives — the band is
  strongest where the eye already is — without asking a row of dots to be a line.
  Sound cross-fades to the bars, which are unchanged.

  The band's own opacity used to carry the distinction at 1 and 0.5; it does not
  any more. Rest and sound are two different objects, which is what they always
  were.

  Verified by eye at 220%: a clean continuous rule under the clock, and the bars
  still render when `sounding` is forced true.

- **D3 — Everything was a card, so the card had stopped saying anything.** Five
  blocks on the overview sat on one faint fill, at one weight, on one sheet. It
  was orderly and it ranked nothing — which is the argument `Chip` already makes
  one floor down about colour: when ten things are each a coloured sticker,
  colour has stopped ranking them.

  The line was already drawn in the component and was only being spent on hover.
  `DashCard.interactive` is true on the notification card and the player and
  false on the calendar, the weather and the load. That is the real distinction:
  **a card is an object you can push; a readout is not an object at all.** Giving
  information a pressable-looking ground is the interface telling a small lie
  about itself, all day.

  So the material carries the affordance now. What you can touch keeps the fill
  and the lit edge; what you only read sits straight on the sheet, held together
  by its spacing — which is what was grouping it anyway.

  Tried the other way first, which is why this is the answer and not a guess:
  every ground removed. The readouts improved and the two controls plainly wanted
  theirs back, so the experiment drew the line rather than a preference.

  It is worth more on the **control** page than on the overview, and that was not
  expected. Those three cards are all static, and each was a card full of cards —
  tiles are themselves pressable objects, so the outer ground was a second level
  of "object" wrapped around the real one. Removing it leaves one level: the
  tiles are the things, and "Быстрые действия", "Уровни" and "Приложения" are
  labelled groups rather than boxes.

  Verified by eye on both pages.

- **D4 — Six panels computed their own colour and handed it to something that
  threw it away.** Recorded last night as F1, with the conclusion that deleting
  the dead property was the wrong repair. This is the right one: **use it.**

  `Theme` states what the domain ladder is for, in as many words — a fixed hue
  per domain means "a chip in the bar and the panel it opens are visibly the same
  subject". That was true of the chip and had never once been true of the panel.
  `Sheet.accent` had been on the component from the beginning, was set by all six
  system panels — `Theme.tone("net")`, `"bt"`, `"audio"`, `"power"`, `"vpn"`, and
  the album's own colour for the player — and was read by nothing.

  It is a hairline along the top edge now, because that is the vocabulary the bar
  already speaks: `Chip` carries the domain as a rule *under* the mark, on a
  shared baseline. The panel hangs off the bar it came from, so the rule
  continues at the join. Inset past the corner radius so it reads as a rule and
  not a bezel, and riding `_drive` so it arrives with the sheet rather than
  landing on it.

  **A wash was tried and rejected.** Carrying the domain further in — a gradient
  from the hue down through the header — sounded better than the rule and
  photographs worse: at one opacity it is clearly warm on bluetooth's rose and
  very nearly invisible on network's mint, because the hues do not share a
  luminance. An effect that lands differently on each of the six things it exists
  to tell apart is the wrong effect. The rule is identical in weight for every
  domain, which is what a vocabulary needs.

  Selected states stay the accent, deliberately. `Segmented` already settled
  that one — accent means chosen, domain means what the panel is about, and a
  control cannot hold both jobs — and colouring six panels' controls six ways is
  how one product turns into six.

  Verified by eye: network and bluetooth side by side, mint against rose.
