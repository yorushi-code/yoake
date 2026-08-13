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
