import QtQuick

// Track position as a waveform.
//
// A flat line tells you one thing: how far in you are. A waveform tells you the
// same thing and gives the track a face — you learn where the drop is, and the
// bar for a quiet intro looks nothing like the bar for a wall of noise.
//
// There is no way to read a decoded waveform here: MPRIS hands over a title and
// a length and nothing else, and decoding the audio would mean finding the file,
// which for a browser tab does not exist. So the shape is derived from the track
// itself — the same title always draws the same figure, which is what makes it
// read as a property of the song rather than as decoration. The bar under the
// playhead is live, driven by the spectrum, so the part being played now is the
// part that actually moves.
Item {
    id: root

    property real dragValue: -1
    readonly property real shown: root.dragValue >= 0 ? root.dragValue : Media.progress

    property int barCount: 64
    property real barGap: 2

    implicitHeight: 34
    height: implicitHeight

    readonly property bool active: ma.containsMouse || ma.pressed

    function fractionAt(mouseX) {
        return Math.max(0, Math.min(1, mouseX / width));
    }

    // A small, stable hash of the track. Deterministic so the same song is the
    // same picture every time it comes round, and cheap enough to run once per
    // track rather than per bar per frame.
    readonly property var shape: {
        const seed = Media.trackId || "";
        const out = [];
        // xorshift, seeded from the string. Any decent scrambler would do; the
        // requirement is only that it is stable and not obviously periodic.
        let state = 2166136261;
        for (let i = 0; i < seed.length; i++) {
            state ^= seed.charCodeAt(i);
            state = Math.imul(state, 16777619) >>> 0;
        }
        if (state === 0) state = 123456789;
        for (let i = 0; i < root.barCount; i++) {
            state ^= state << 13; state >>>= 0;
            state ^= state >> 17;
            state ^= state << 5; state >>>= 0;
            const noise = (state % 1000) / 1000;
            // An envelope, so a track opens quietly, fills out and tails off
            // instead of being a uniform hedge.
            const t = i / (root.barCount - 1);
            const envelope = 0.35 + 0.65 * Math.sin(Math.PI * Math.pow(t, 0.8));
            out.push(0.18 + noise * 0.82 * envelope);
        }
        return out;
    }

    Row {
        anchors.fill: parent
        spacing: root.barGap

        Repeater {
            model: root.barCount

            delegate: Item {
                id: bar
                required property int index

                readonly property real position: (bar.index + 0.5) / root.barCount
                readonly property bool played: bar.position <= root.shown
                // The bar the playhead is on takes the live level, so the point
                // being played is the only thing moving.
                readonly property bool atHead:
                    Math.abs(bar.position - root.shown) < (0.5 / root.barCount)
                readonly property real level: {
                    const base = root.shape[bar.index] || 0.3;
                    if (bar.atHead && Cava.active) return Math.max(base, 0.35 + Cava.bass * 0.65);
                    return base;
                }

                width: (root.width - root.barGap * (root.barCount - 1)) / root.barCount
                height: root.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Math.max(2, bar.level * root.height)
                    radius: width / 2
                    color: bar.played ? MediaTint.accent : Qt.alpha(Theme.text, Theme.fillActive)
                    opacity: bar.atHead ? 1 : (bar.played ? 0.92 : 1)

                    Behavior on height {
                        NumberAnimation { duration: bar.atHead ? 90 : 260; easing.type: Easing.OutQuad }
                    }
                    Behavior on color { ColorAnimation { duration: 220 } }
                }
            }
        }
    }

    // The playhead, shown only while the bar is being used — the colour split
    // already says where the position is the rest of the time.
    Rectangle {
        width: 2
        height: parent.height + 6
        radius: 1
        color: Theme.text
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(root.width - width, root.width * root.shown - width / 2))
        opacity: root.active && Media.length > 0 ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        // Generous vertically: the wave is twenty-two pixels tall in the
        // compact card, and a target that small is one people miss and then
        // conclude the control does not work.
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        hoverEnabled: true
        enabled: Media.player !== null && Media.player.canSeek && Media.length > 0
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: mouse => root.dragValue = root.fractionAt(mouse.x)
        onPositionChanged: mouse => {
            if (pressed) root.dragValue = root.fractionAt(mouse.x);
        }
        onReleased: mouse => {
            root.pendingSeek = root.fractionAt(mouse.x);
            root.dragValue = root.pendingSeek;
            Media.seek(root.pendingSeek);
            settle.restart();
        }
    }

    // What was asked for, held on screen until the player agrees.
    //
    // This used to be a flat 500ms, and the position poll only runs once a
    // second: the bar dropped back to the pre-seek position, sat there, and
    // then jumped -- which looks exactly like a seek that was ignored, and is
    // why it seemed to work only sometimes. Now the drag value is held until
    // the player reports somewhere near where it was sent, and released on a
    // deadline only if it never does.
    property real pendingSeek: -1

    Timer {
        id: settle
        interval: 60
        repeat: true
        property int ticks: 0
        onTriggered: {
            settle.ticks++;
            const close = root.pendingSeek >= 0
                && Math.abs(Media.progress - root.pendingSeek) < 0.015;
            if (close || settle.ticks > 40) {
                root.dragValue = -1;
                root.pendingSeek = -1;
                settle.stop();
                settle.ticks = 0;
            }
        }
        onRunningChanged: if (running) settle.ticks = 0
    }
}
