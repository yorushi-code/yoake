pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// How the space should be perceived, given what the machine reports.
//
// Context answers "what is going on". This answers "what should that feel
// like", and the two are not the same question: `cpu=0.82, hour=01:40,
// focus=foot` are facts, and no surface can draw a fact. Between them there
// used to be nothing, which is why for a long time Context changed nothing at
// all -- two files read it, `partOfDay` was computed, emitted on the bus, and
// listened to by no one.
//
// ── Invariant 1: Context.mode is a summary, not an input ──
//
// `mode` is an ordered if-chain and therefore lossy by construction: coding,
// at night, on battery, with music on collapses to the single string "music"
// and three quarters of the state is discarded before anything can draw it.
// It is the right shape for a readout and for Notifs, which genuinely wants
// one word. It MUST NOT appear in this file, and no rendering decision
// anywhere may derive from it. Everything here reads raw context directly.
//
// ── Invariant 2: no memory of its own decisions ──
//
// This never reads back what it emitted. Filtering an *input* is allowed and
// necessary -- unsmoothed CPU driving blur makes the surface shimmer on an
// idle machine -- but a value here is never a function of a previous value
// here, so there is no feedback path and no way for the shell to settle into
// a state it talked itself into. Formally: a function of input history, never
// of output history. Grep-checkable, which is the point of writing it down.
//
// Smoothing lives here rather than in the collectors on purpose. A time
// constant is a perceptual decision, not a measurement one: SysInfo cannot
// know whether its number is about to drive a shadow or a log line, so a
// collector that pre-smooths either picks one constant that is wrong for
// every consumer or publishes five differently-damped copies of `cpu`, which
// is this file's policy leaking downward.
//
// ── Invariant 3: no layer invents what it did not receive ──
//
// Aggregate, filter, compress. Never guess. `cpu -> EMA` is fine. `focus ->
// dwell` is fine, because dwell is named for what it measures. `musicPlaying
// -> userIsRelaxed` is not: that is a hypothesis wearing an observation's
// clothes, and it is the same thing Context.qml already refuses when it
// declines to derive a `gaming` mode from a flag niri does not report.
//
// ── Invariant 4: axes are partitioned by what they touch ──
//
// Four axes, distinct because their *output sets are disjoint*, not because
// their names sound different. If two ever write the same token, they were
// one axis.
Singleton {
    id: root

    // ── Filtered inputs ──

    // An EMA, not the raw sample. Faster on the way up than down: the shell
    // should notice a build starting within a second or two, and should not
    // un-notice it between two compiler invocations.
    property real _cpu: 0
    Connections {
        target: SysInfo
        function onCpuChanged() {
            const a = SysInfo.cpu > root._cpu ? 0.35 : 0.12;
            root._cpu = root._cpu + (SysInfo.cpu - root._cpu) * a;
        }
    }

    // The hour as a continuous curve rather than four named blocks. Named
    // blocks put a cliff at 05:00, 11:00, 18:00 and 23:00, and a shell that
    // visibly reshapes itself the instant a clock rolls over is a shell with a
    // bug in it as far as anyone watching is concerned. Trough at 04:00, peak
    // at 16:00, no discontinuity anywhere including across midnight.
    readonly property real _daylight:
        0.5 - 0.5 * Math.cos((Context.hour + clock.date.getMinutes() / 60 - 4) / 24 * 2 * Math.PI)

    // How settled the current window is. Focus that has not moved for a while
    // is the only observable proxy for someone being deep in one thing --
    // niri reports the focused window and nothing about attention -- so it is
    // named for what it measures rather than for what it is taken to mean.
    property real _dwell: 0
    Connections {
        target: Niri
        function onFocusedWindowChanged() { root._dwell = 0; }
    }
    Timer {
        running: true
        repeat: true
        interval: 2000
        onTriggered: root._dwell = Math.min(1, root._dwell + 0.05)
    }

    // ── The axes ──
    //
    // The first cut of these sat at 0.5 and added deltas of ±0.15, which was
    // arithmetically valid and visually nothing: measured live, `spatial` was
    // 0.44 and `densityScale` came out 1.02, so a 12px gap became a 12px gap.
    // A semantic layer whose whole travel is inside the noise floor is the
    // same failure as a token nobody reads, one storey up. The coefficients
    // below are sized so that idle, night and loaded are three visibly
    // different rooms.

    // Spatial: geometry only. Gaps, padding, margins. Nothing else.
    readonly property real spatial: root._ax(
        0.55 + (1 - root._daylight) * 0.30 - root._cpu * 1.20, root._forceSpatial)

    // Temporal: duration only. Behaviors, springs, damping. No colour here.
    //
    // Two forces pulling opposite ways, which is why this is a number and not
    // a mode: the small hours want a slower shell because nothing is urgent,
    // and a loaded machine wants a faster one because the frames are already
    // spoken for -- a longer tween while someone waits on a build is the one
    // moment where slow motion reads as the shell being the problem.
    readonly property real temporal: root._ax(
        0.50 + (1 - root._daylight) * 0.35 - root._cpu * 1.30, root._forceTemporal)

    // Optical: light only. Contrast, glass, shadow, opacity.
    //
    // Load is deliberately *not* an input here, and finding that out was the
    // ownership rule earning its keep. Optical owned both `inkScale` and
    // `frost`, and the two want opposite things from a busy machine: frost
    // should go (it is the most expensive thing the shell draws) while ink
    // should stay full (that is the moment someone is reading). Driving both
    // from one axis made one of them wrong at all times.
    //
    // The resolution is that dropping frost under load was never a perceptual
    // decision at all. It is the budget talking -- see PerformanceContract.md
    // -- so it is a veto applied to the axis, not a term inside it. Optical
    // stays what it says it is: how soft the light should be.
    //
    // There is now a second veto, and it is not this file's opinion either.
    // Frosted glass is a *material*, and which material the shell is made of is
    // taste, not perception -- so it is the user's switch, and this file only
    // says whether the machine can currently afford the one they picked.
    // Read once and written back explicitly rather than bound, because a
    // binding onto Prefs plus a write-back handler is a loop.
    readonly property real optical: root._ax(
        0.15 + root._daylight * 0.80 - (Context.capturing ? 0.15 : 0), root._forceOptical)

    // Hierarchy: emphasis distribution only. Accent strength, secondary
    // opacity, icon weight.
    //
    // This is where attention lands, and it may redistribute emphasis across
    // the shell's own chrome and nothing else. It may never reach the
    // notification stack: Context.qml already sets the rule that a heuristic
    // may affect what the shell shows and never what it silences, and dimming
    // a message because the pointer is elsewhere is exactly that silencing.
    readonly property real hierarchy: root._ax(
        0.35 + root._dwell * 0.45 + (Context.coding ? 0.20 : 0), root._forceHierarchy)

    // The budget veto. Not an axis and not perception: the shell would like
    // the glass at every hour, and under load it cannot afford it.
    readonly property bool _affordable: root._cpu < 0.55

    // ── Preview ──
    //
    // Judging this by waiting for 3am or for a build is not judging it, and
    // the first honest reaction to the layer was "I cannot see that anything
    // changed" -- which was true, and unanswerable without a way to look.
    //
    // An override is an input, not remembered output, so Invariant 2 holds:
    // these are read by the axes and never written by them.
    //
    //   qs ipc call perception force temporal 1     -- slowest the shell gets
    //   qs ipc call perception force spatial 0      -- tightest
    //   qs ipc call perception auto                 -- back to observation
    property real _forceSpatial: -1
    property real _forceTemporal: -1
    property real _forceOptical: -1
    property real _forceHierarchy: -1

    function _ax(value, override) {
        if (override >= 0) return override;
        return value < 0 ? 0 : (value > 1 ? 1 : value);
    }

    function _lerp(a, b, t) {
        return a + (b - a) * t;
    }

    // How finely a decision is published.
    //
    // This is the most expensive line in the shell, and it was not here.
    //
    // The axes below are continuous and they never stop moving: a two-second
    // tick nudged `hierarchy` by 0.02 and `spatial` by 0.002, forever. Every
    // one of those nudges started a 1400ms Behavior in Theme on a token that
    // every size, gap, alpha and duration in the shell is derived from -- so
    // the whole design system was interpolating for 1.4 seconds out of every 2,
    // across every window, awake or not, visible or not. Measured on an idle
    // desktop with nothing playing: the shell never stopped rendering.
    //
    // Nothing in that was visible. `emphasis` moving from 0.999 to 1.009 scales
    // a glow by one part in a hundred. So the value is published on a grid
    // coarse enough that crossing a line means something -- a step is about
    // half a pixel of gap, four milliseconds of duration -- and the drift
    // between lines costs nothing at all.
    //
    // Quantising is a decision about what to say, not about how to show it, so
    // it belongs on this side of the line. The smoothing stays in Theme.
    readonly property real _grain: 0.04

    function _step(v) {
        return Math.round(v / root._grain) * root._grain;
    }

    // ── Driving Theme ──
    //
    // Written to Theme rather than read from it, so Theme keeps depending on
    // nothing: Context reaches Notifs, Notifs reads Theme, and a Theme that
    // reached back here would close that ring while the singletons are still
    // being constructed.
    //
    // Bindings rather than assignments in a handler, because these follow
    // continuous inputs and an assignment would only land when something
    // discrete changed. Smoothing the result is Theme's job, not this file's
    // -- deciding and presenting are different, and a Behavior here would be
    // exactly the output-side memory Invariant 2 forbids.
    property list<Binding> _drive: [
        Binding { target: Theme; property: "densityScale"; value: root._step(root._lerp(0.75, 1.35, root.spatial)) },
        Binding { target: Theme; property: "motionScale"; value: root._step(root._lerp(0.55, 1.60, root.temporal)) },
        Binding { target: Theme; property: "inkScale"; value: root._step(root._lerp(0.72, 1.00, root.optical)) },
        Binding { target: Theme; property: "frost"; value: root._affordable && root.frostWanted },
        Binding { target: Theme; property: "emphasis"; value: root._step(root._lerp(0.70, 1.15, root.hierarchy)) }
    ]

    // Taste, not perception: whether the shell is made of glass at all.
    //
    // Off by default. Frost was the shell's material because it is the material
    // a screenshot flatters, and a screenshot is not where anyone spends the
    // day: over a terminal it reads as smudged, over a bright frame it stops
    // separating the shell from the desktop at all, and it is the one effect
    // here expensive enough that the machine takes it away by itself under
    // load. Painted surfaces mixed from the wallpaper's own palette belong to
    // the picture by colour rather than by transparency, which is the cheap way
    // to do the same job and the one that holds at every brightness.
    property bool frostWanted: false

    Component.onCompleted: if (Prefs.loaded) root.frostWanted = Prefs.get("look.frost", false)

    property Connections _prefsReady: Connections {
        target: Prefs
        function onLoadedChanged() {
            if (Prefs.loaded) root.frostWanted = Prefs.get("look.frost", false);
        }
    }

    onFrostWantedChanged: if (Prefs.loaded) Prefs.set("look.frost", root.frostWanted)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Same reason Context and Idle have one: a derived state that cannot be
    // read back is one nobody can debug at the moment it makes the shell look
    // wrong. Reports the resulting token values too, because the axis alone
    // does not say whether the shell actually moved.
    property IpcHandler handler: IpcHandler {
        target: "perception"

        function state(): string {
            return "spatial=" + root.spatial.toFixed(3) + "   density=" + Theme.densityScale.toFixed(3) + "  (gapWide " + Theme.gapWide + ", gapSection " + Theme.gapSection + ")\n"
                + "temporal=" + root.temporal.toFixed(3) + "  motion=" + Theme.motionScale.toFixed(3) + "  (animNormal " + Theme.animNormal + "ms)\n"
                + "optical=" + root.optical.toFixed(3) + "   ink=" + Theme.inkScale.toFixed(3) + "  frost=" + Theme.frost + "\n"
                + "hierarchy=" + root.hierarchy.toFixed(3) + " emphasis=" + Theme.emphasis.toFixed(3) + "  chrome=" + Theme.chromeEmphasis.toFixed(3) + "\n"
                + "inputs: cpu=" + root._cpu.toFixed(3)
                + " daylight=" + root._daylight.toFixed(3)
                + " dwell=" + root._dwell.toFixed(2)
                + " capturing=" + Context.capturing
                + " coding=" + Context.coding;
        }

        function force(axis: string, value: string): string {
            const v = parseFloat(value);
            if (isNaN(v) || v < 0 || v > 1) return "value must be 0..1";
            switch (axis) {
            case "spatial": root._forceSpatial = v; break;
            case "temporal": root._forceTemporal = v; break;
            case "optical": root._forceOptical = v; break;
            case "hierarchy": root._forceHierarchy = v; break;
            default: return "axis must be spatial|temporal|optical|hierarchy";
            }
            return axis + " forced to " + v.toFixed(2) + " (qs ipc call perception auto to release)";
        }

        // The material switch, so the two looks can be put side by side
        // rather than argued about.
        function frost(): string {
            root.frostWanted = !root.frostWanted;
            return root.frostWanted ? "frosted" : "flat";
        }

        function auto(): string {
            root._forceSpatial = -1;
            root._forceTemporal = -1;
            root._forceOptical = -1;
            root._forceHierarchy = -1;
            return "released, back to observation";
        }
    }
}
