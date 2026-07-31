import QtQuick
import QtQuick.Effects

// The cat.
//
// It was drawn here out of primitives, which kept the shell free of assets and
// looked exactly like a cat drawn out of primitives. The frames are the real
// bongo cat now — assets/bongo, from wayland-bongocat, MIT, see the LICENSE
// beside them.
//
// Left the colour it was drawn in. A MultiEffect colourise pass over the frame
// stack made the cat disappear between strikes -- the effect had no texture to
// sample in the instant one child became visible and the next did not -- and a
// white bongo cat on dark glass is the shape everybody already knows. It is
// tied to the record through the surface it drums on instead.
//
// The paws are driven by the bass rather than by a timer: a timer would tap at
// its own tempo and be wrong for every track, where the bass is the beat by
// definition. Hands alternate, because a cat hitting both at once every time is
// a cat falling over — both together is reserved for a hit hard enough to
// deserve it.
Item {
    id: root

    implicitWidth: 208
    implicitHeight: 164

    readonly property bool live: Cava.active && Media.playing
    readonly property real beat: root.live ? Cava.bass : 0

    // A hit is a rising edge, not the level itself: holding the paw down for as
    // long as the bass is loud makes the cat lean, not drum.
    //
    // Measured against a decaying peak rather than a fixed number. A constant
    // threshold is a guess about how loud the music is, and it was wrong -- at
    // 0.34 the cat sat still through a whole track whose bass never reached it,
    // and a louder track would have had it hammering continuously. Against the
    // recent peak, the same beat is found in a quiet mix and a loud one.
    property real _peak: 0
    readonly property real _floor: 0.06

    // "" idle, "left", "right", "both"
    property string strike: ""
    property int _side: 0

    onBeatChanged: {
        // Rises instantly and falls slowly, so one loud passage does not deafen
        // the detector for the rest of the track.
        root._peak = root.beat > root._peak
            ? root.beat
            : root._peak * 0.985;

        if (!root.live) return;

        const gate = Math.max(root._floor, root._peak * 0.62);
        if (root.beat > gate && !hold.running) {
            if (root.beat > Math.max(root._floor * 2, root._peak * 0.92)) {
                root.strike = "both";
            } else {
                root._side = 1 - root._side;
                root.strike = root._side === 0 ? "left" : "right";
            }
            hold.restart();
        }
    }

    Timer {
        id: hold
        // Long enough to be seen, short enough that a fast track still reads as
        // separate hits rather than a blur.
        interval: 110
        onTriggered: root.strike = ""
    }

    // Asleep rather than merely still. A paused player showing an alert cat
    // waiting for a beat that is not coming is the widget lying about the state
    // of the machine.
    readonly property bool asleep: !root.live

    readonly property string frame: {
        if (root.asleep) return "sleeping";
        switch (root.strike) {
        case "left": return "left-down";
        case "right": return "right-down";
        case "both": return "both-down";
        }
        return "both-up";
    }

    // The drawing is square with the cat in its lower half, so the item is
    // square too and hangs below the box: fitting a square picture into an
    // oblong slot wastes the height on empty sky above the ears.
    Item {
        id: art
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -14
        width: Math.min(root.width, root.height * 1.32)
        height: width


        // Every frame is loaded and kept, and only one is shown. Swapping one
        // Image's source at drumming speed means rasterising an SVG on the
        // beat: the first hit of every track arrives late and the cat stutters
        // exactly when the music is busiest.
        Repeater {
            model: ["both-up", "left-down", "right-down", "both-down", "sleeping"]

            delegate: Image {
                required property string modelData

                anchors.fill: parent
                source: Qt.resolvedUrl("assets/bongo/bongo-" + modelData + ".png")
                fillMode: Image.PreserveAspectFit
                // Rasterised from the SVGs at install time rather than loaded
                // as SVG: Qt's own renderer draws these files wrong -- the cat
                // comes out cropped and its transparent field opaque -- and a
                // 512px sprite is smaller than arguing with it.
                sourceSize.width: 512
                sourceSize.height: 512
                asynchronous: true
                cache: true
                visible: root.frame === modelData
            }
        }
    }

    // Drops on the beat. The frames carry the paws; this is the weight behind
    // them, and it is what stops four still pictures reading as a slideshow.
    y: root.strike !== "" ? 3 : 0
    Behavior on y {
        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
    }

    scale: root.asleep ? 1 : 1 + root.beat * 0.03
    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad }
    }

    // ── Table ──
    // The paws have to land on something or they are just waving.
    Rectangle {
        id: table
        // Placed off the art, not the item: the drawing hangs below its box,
        // and a line on the box's edge floats well under the paws.
        anchors.horizontalCenter: art.horizontalCenter
        width: art.width * 0.72
        anchors.bottom: art.bottom
        anchors.bottomMargin: art.height * 0.295
        height: 3
        radius: 1.5
        z: -1
        // Lights up under the paws on the beat, in the record's colour. The cat
        // stays the colour it was drawn; what belongs to the track is the
        // surface it is hitting.
        //
        // Reached through the id, not through `parent`: inside a GradientStop
        // `parent` is the Gradient, which has no such property, and an
        // undefined colour resolves to opaque black -- a dark bar under the cat
        // in every frame.
        readonly property color lit: root.strike !== ""
            ? MediaTint.accent
            : Qt.alpha(Theme.text, 0.20)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.22; color: table.lit }
            GradientStop { position: 0.78; color: table.lit }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // The strike itself, as light rather than as a second drawing. Sized off
    // the bass so a heavy beat throws more of it.
    //
    // A RectangularShadow rather than a blurred layer: a MultiEffect blur over
    // a layer renders its transparent field opaque, and what landed under the
    // cat was a dark smudge instead of a glow.
    RectangularShadow {
        anchors.horizontalCenter: art.horizontalCenter
        anchors.bottom: art.bottom
        anchors.bottomMargin: art.height * 0.295 - height / 2 + 1.5
        width: art.width * (0.30 + root.beat * 0.28)
        height: 8
        radius: 4
        z: -2
        color: MediaTint.accent
        blur: 26
        spread: 2
        offset: Qt.vector2d(0, 0)
        opacity: root.strike !== "" ? 0.55 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    }

    // ── Sleeping ──
    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 10
        text: "z"
        color: Qt.alpha(Theme.subtext0, 0.8)
        font.family: Theme.fontFamily
        font.pixelSize: 13
        opacity: root.asleep ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

        SequentialAnimation on y {
            running: root.asleep
            loops: Animation.Infinite
            NumberAnimation { from: 8; to: -6; duration: 2200; easing.type: Easing.InOutQuad }
            PauseAnimation { duration: 400 }
        }
    }
}
