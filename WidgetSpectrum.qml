import QtQuick

// Audio spectrum, mirrored around the vertical centre so the shape reads as a
// waveform rather than a bar chart.
//
// It sat on a flat four-pixel floor, which meant that between two loud passages
// it collapsed into a dotted line across the wallpaper — the thing on screen
// stopped looking like an instrument at rest and started looking like a
// rendering fault. The floor is an arc now: at silence the row still has a
// shape, and the shape is the one the music will grow out of.
Item {
    id: root

    // Drawn whenever the desktop is, sounding or not.
    //
    // It used to fade out with the audio, which left a 64px hole between the
    // clock and the player every time the music stopped — the rail's one
    // connective element, absent exactly as often as it was present. The floor
    // arc below was written to be the shape at rest and had never once been
    // seen. Now it is the rest state: a dotted rule tying the two blocks
    // together, that the music grows out of and settles back into.
    //
    // Costs nothing while silent. Cava stops publishing, so every delegate's
    // level binding holds its last value and is never re-evaluated; what the
    // old gate was really buying was dropping the delegates while the desktop
    // is covered, and that half is kept.
    readonly property bool live: Wallpaper.desktopVisible
    readonly property bool sounding: Cava.active && root.live

    // Set to the rail's measure. Sized to fill it rather than to its own idea
    // of a bar width: this band is what ties the time block to the player, and
    // a row that stops short of both their edges ties nothing to anything.
    property int railWidth: 440

    // The gap closes when there is nothing to show, and that is the whole of
    // the resting state. See the floor below.
    readonly property int barGap: root.sounding ? 5 : 0
    // Integral, so the pills never land on a half pixel and shimmer; the
    // remainder goes into the spacing instead, where a fraction is invisible.
    readonly property int barWidth: Math.max(2, Math.floor(
        (root.railWidth - (Cava.barCount - 1) * root.barGap) / Cava.barCount))
    // The flooring remainder is spread back into the spacing so the row fills
    // the rail exactly — and at rest that remainder is what kept the line
    // dashed, a hairline in thirty-two pieces. Silence takes the spacing to
    // zero and lets the row fall a couple of pixels short of the rail instead,
    // which nobody can see and which a broken line plainly was.
    readonly property real fillGap: (root.sounding && Cava.barCount > 1)
        ? (root.railWidth - Cava.barCount * root.barWidth) / (Cava.barCount - 1)
        : 0
    // A band rather than a block: at the full 96 it competed with the clock for
    // the eye, and the rail only has one hero.
    readonly property int span: 64

    implicitWidth: root.railWidth
    implicitHeight: root.span

    // Only the desktop being hidden takes the whole band away now. The rest /
    // sounding distinction is drawn by the two children below, which are two
    // different objects rather than one object at two opacities.
    opacity: root.live ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animSlow
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasized
        }
    }

    // ── At rest: one rule, not twenty-eight pills ──
    //
    // The band used to spend silence as a row of round dots — an arch of them,
    // taller in the middle, which is a better idea than it looked and still read
    // as a loading indicator. This is the widest element on the desktop, sitting
    // directly under a clock that has earned that width, and it was the one
    // saying least.
    //
    // Flattening the pills into a hairline was the first attempt and it does not
    // work either: twenty-eight rounded rectangles laid edge to edge do not make
    // a line, they make twenty-eight antialiased seams, and at rest that is a
    // dashed rule. Measured before believing it — `gap=0 fill=0.00`, so the
    // geometry was already flush and the breaks were the pills' own ends.
    //
    // So silence gets an object of its own: one rule, fading out at both ends
    // rather than stopping, which keeps the arch's idea — the band is strongest
    // where the eye already is — without pretending a row of dots is a line.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: root.railWidth
        height: 2
        radius: height / 2
        opacity: root.sounding ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: Theme.animSlow; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
        }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.22; color: Qt.alpha(Theme.deskInk, Theme.inkFaint) }
            GradientStop { position: 0.78; color: Qt.alpha(Theme.deskInk, Theme.inkFaint) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.fillGap
        // The bars are the sounding state now; the rule above is the other one.
        opacity: root.sounding ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animSlow; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
        }

        Repeater {
            // Zero rows, not just an invisible Row: occlusion does not stop Qt
            // from re-evaluating bindings, so twenty-eight delegates kept
            // recomputing their heights off every cava frame behind an opaque
            // window — about half the shell's idle CPU, spent on something
            // nobody could see. Dropping the delegates is what actually stops
            // the work.
            model: root.live ? Cava.barCount : 0

            delegate: Item {
                id: bar
                required property int index

                readonly property real level: Cava.values[index] || 0
                readonly property real peak: Cava.peaks[index] || 0
                // 0 at the ends, 1 in the middle.
                readonly property real arch:
                    Math.sin(Math.PI * (bar.index + 0.5) / Cava.barCount)
                // At rest this is a **line**, not a row of dots.
                //
                // It was a row of dots — an arch of them, taller in the middle,
                // which is a more considered idea than it looked and still did
                // not work. Thirty-two round pills in a row read as a loading
                // indicator or as dead pixels, and this band is the widest thing
                // on the desktop: the element saying least was taking the most
                // width, directly under a clock that had earned it.
                //
                // So silence closes the gaps and flattens the pills, and the
                // thirty-two of them fuse into one continuous rule — slightly
                // lens-shaped, because the arch is kept and is legible at this
                // height where it was not at twelve. Sound breaks that line back
                // into bars. The rule is the shell's own idiom: `Chip` already
                // says a hairline on a shared baseline is what a row of readouts
                // should be scanned along.
                //
                // Sounding, the floor stays what it was: never below the bar's
                // own width, so a quiet passage is round dots rather than
                // clipped slots.
                readonly property real floorHeight: root.sounding
                    ? Math.max(root.barWidth, 4 + bar.arch * 12)
                    : Math.max(2, 2 + bar.arch * 2)

                // Hue walks along the row rather than up each bar. A vertical
                // ramp is invisible on a bar four pixels tall; a horizontal one
                // is legible whatever the music is doing, and it makes the low
                // end and the high end tell themselves apart at a glance.
                readonly property color tint: Qt.tint(
                    Theme.deskAccent,
                    Qt.alpha(Theme.blue, (bar.index + 0.5) / Cava.barCount))

                width: root.barWidth
                height: root.span

                // Scales with the band's own level, so loud bands bloom and
                // quiet ones stay clean.
                Glow {
                    anchors.fill: barRect
                    radius: barRect.radius
                    tint: bar.tint
                    reach: 20
                    // Gated by Glow's own floor: below it the bloom is under
                    // two per cent and indistinguishable from nothing, but all
                    // twenty-eight were still being drawn every frame.
                    amount: bar.level > 0.25 ? bar.level * Theme.veilDense : 0
                }

                Rectangle {
                    id: barRect
                    width: parent.width
                    height: Math.max(bar.floorHeight, bar.level * root.span)
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: bar.tint
                    // Brightens as it grows, so the loud bands are lighter as
                    // well as taller and the shape survives a busy wallpaper.
                    opacity: 0.55 + bar.level * 0.45
                    // See BarMedia: the fall is smoothed in Cava now.
                }

                // Peak-hold: a transient that would be gone by the next frame
                // leaves a marker that sinks back down, which is what makes a
                // fast track read as loud rather than just busy.
                //
                // In the band's own colour, not white. A white dash hanging in
                // the air above a short bar reads as debris on the wallpaper;
                // the same mark in the same hue reads as part of the bar it
                // came off.
                Rectangle {
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: bar.tint
                    opacity: bar.peak > bar.level + 0.04 ? 0.7 : 0
                    y: (parent.height - Math.max(bar.floorHeight, bar.peak * root.span)) / 2
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                }
            }
        }
    }
}
