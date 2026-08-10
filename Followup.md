# Follow-up

Ordered work list, on disk on purpose: the schedule that drives it lives only
inside a Claude session, so this file is the part that survives.

The rule this list exists to satisfy is in `Rework.md` §3.2 rule 0 and it is the
one the rework pass broke most often: **read the whole implementation first,
never trade working architecture for smaller code, and never call compilation
success.** Everything below is either verifying that, or repairing where it was
not done.

Do the items in order. Mark one done only when its acceptance line is true.
Commit each item separately.

---

## Safety, at night, unattended

- **Do not restart the shell** (`bin/yoake-shell`). Hot reload on save is enough
  and cannot leave the desktop without a bar.
- **Do not touch the network, the VPN or audio routing.** Read as much as you
  like; `connect`, `disconnect`, `forget`, `setDefaultSink`, `Mihomo.start/stop`
  are all off limits without a person present.
- **Do not run the greeter installer.** It needs root and a logout to verify.
- Panels may be opened and closed for screenshots — the screen should be free.
- If the shell ever fails to load, `git log` the last commit, revert that file,
  confirm `Configuration Loaded`, and write what happened here.

---

## 1. VpnPanel lost behaviour  ← start here

`VpnPanel.qml` went from 812 lines to about 280 in one commit
(`943d18b`), and less than a hundred of the original were read first. The
logic in `Mihomo` was not touched, but the panel almost certainly dropped
*surfaces* that had no equivalent in the new one.

    git show 943d18b^:VpnPanel.qml > /tmp/vpn-old.qml

Read it in full. Build a list of every capability it offered. Then check each
against the current file. Known suspects, none of them verified:

- adding a subscription (`Mihomo.addSubscription`) and the editor behind it
  (`VpnSubscriptionEditor.qml` — is it still reachable from anywhere?)
- removing a subscription (`Mihomo.removeSubscription`)
- switching a subscription's core (`Mihomo.setCore`) — mihomo / sing-box / xray
- the rival-core conflict UI (`Mihomo.conflict`, `conflictCanStop`,
  `stopRival()`) — this one matters, it is how the user gets out of a jam
- egress IP
- routing mode (rule / global / direct)
- `VpnNodeRow.qml` and `VpnSubscriptionRow.qml` are now unreferenced — either
  bring them back or delete them, but do not leave orphans in the tree

**Acceptance:** every capability of the old panel is either present in the new
one or written down here with a reason it was dropped. `bin/yoake-lint` clean,
no unreferenced files left behind.

## 2. The three surfaces nobody has seen

Built, loading without errors, never looked at. Screenshot each, read the
image, fix what is wrong.

- `qs ipc call toggles panel media` — the player and the equaliser. Check: the
  vinyl spins only while playing, the marquee does not stutter, the seek bar is
  mint, the equaliser's bands are where `Eq.bands` says, and clicking a preset
  runs the light across the row with each band leaving as it is reached.
- `qs ipc call toggles dashboard` — three tabs now. Check nothing references a
  removed tab, Overview still has the load card, and the tab marker travels.
- `qs ipc call toggles vpn` — after item 1.

Close everything afterwards: `qs ipc call toggles close`.

**Acceptance:** a screenshot of each, read and judged, and any defect either
fixed or listed here.

## 3. The other wholesale rewrites

Same treatment as item 1, smaller scope. For each, diff against the commit
before it and confirm nothing real was dropped:

- `BarClock.qml` (`0aaa67c`) — the old one had two hit areas and a menu; check
  the tooltip, the copy-time and copy-date actions, and that the optical centre
  still lands on the clock and not the zone.
- `LauncherRow.qml` (`bcde047`) — the old one drew a selection rail per row;
  confirm the Traveller covers every case the rail did, including the first
  frame after a query change.
- `NotificationCenter.qml` toast delegate — grouping was added in `21665a6`.
  Confirm the throw, the hover hold and the drain still work on a *grouped*
  card, not just a fresh one.

**Acceptance:** each diff read, findings written here.

## 4. Equaliser, end to end

The backend is verified from a terminal; the UI has never been driven.

- `bin/yoake-eq get` before and after clicking a preset — the numbers must
  match `Eq.bands`.
- Confirm the sweep animation actually stops: no permanently running animation
  left behind. Measure CPU with the panel open and the equaliser idle; 20% is
  the ceiling and it should be far under.
- The routing chip is the only thing that may change the default sink, and only
  by a click. Leave routing **off** when finished.

**Acceptance:** gains round-trip, CPU measured and written here.

## 5. Whole-shell pass

Only after 1-4.

- `bin/yoake-lint` — zero findings.
- Fresh log, no `ERROR`, no `Unable to assign`, no binding loops.
- CPU over 25 s on an idle desktop, and again with music playing. Contract is
  under 20% idle.
- Every chip in the bar against the six-point checklist in `Rework.md` §2.7.

---

## Log

Append findings here, newest last. One line per item, plus anything a person
should know in the morning.

- **1a.** Audited `VpnPanel` against `943d18b^`. The rewrite was a reduction,
  not a re-skin: it dropped the rival-core conflict banner and its stop button,
  the egress IP check, adding and removing subscriptions, per-subscription core
  switching, and group switching (the new panel hardcodes PROXY). It also
  orphaned `VpnNodeRow.qml` and `VpnSubscriptionRow.qml`.
- **1b.** Restored the conflict banner and the egress row. Both were the cases
  where the tunnel looks healthy and the traffic is not in it -- the one failure
  the shell exists to name. Lint clean, config loads. **Still missing: add /
  remove subscription, `setCore`, group switching, and the two orphan files.**
  Next wake-up starts there.

