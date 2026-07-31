import QtQuick

// The cat.
//
// It drums on the beat. Every part of it is a shape drawn here — no image, no
// sprite sheet, nothing downloaded — so it recolours with the wallpaper like
// everything else and there is no asset to lose.
//
// The paws are driven by the bass rather than by a timer: a timer would tap at
// its own tempo and be wrong for every track, where the bass is the beat by
// definition. They alternate, because a cat hitting both at once is a cat
// falling over.
Item {
    id: root

    implicitWidth: 132
    implicitHeight: 104

    readonly property bool live: Cava.active && Media.playing
    readonly property real beat: root.live ? Cava.bass : 0

    // A hit is a rising edge over the threshold, not the level itself: holding
    // the paw down for as long as the bass is loud makes it lean, not drum.
    property bool leftDown: false
    property int _side: 0
    readonly property real _threshold: 0.34

    onBeatChanged: {
        if (root.beat > root._threshold && !hold.running) {
            root._side = 1 - root._side;
            root.leftDown = root._side === 0;
            hold.restart();
        }
    }

    Timer {
        id: hold
        // Long enough to be seen, short enough that a fast track still reads as
        // separate hits rather than a blur.
        interval: 110
        onTriggered: {}
    }

    readonly property bool striking: hold.running

    // ── Table ──
    Rectangle {
        // Inset, and only as wide as the cat needs: run to the full width and
        // it stops reading as the surface the paws land on and starts reading
        // as an underline somebody left behind.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        height: 3
        radius: 1.5
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.2; color: Qt.alpha(Theme.text, 0.18) }
            GradientStop { position: 0.8; color: Qt.alpha(Theme.text, 0.18) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ── Body ──
    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        width: 58
        height: 44
        radius: 22
        color: Qt.alpha(Theme.text, 0.9)
        // Settles a little on each hit, the way something that just struck a
        // surface does.
        scale: root.striking ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
    }

    // ── Head ──
    Item {
        id: head
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: body.top
        anchors.bottomMargin: -12
        width: 54
        height: 44
        // Bobs with the beat, a touch behind the paws.
        y: body.y - height + 12 - root.beat * 3

        Rectangle {
            anchors.fill: parent
            radius: 21
            color: Qt.alpha(Theme.text, 0.9)
        }

        // Ears: rotated squares, which read as triangles once the head covers
        // their lower halves.
        Repeater {
            model: [-1, 1]

            delegate: Rectangle {
                required property var modelData
                width: 15
                height: 15
                radius: 3
                rotation: 45
                color: Qt.alpha(Theme.text, 0.9)
                x: parent.width / 2 + modelData * 16 - width / 2
                y: -3
                z: -1
            }
        }

        // Eyes. They shut on the strike, which is most of the character.
        Repeater {
            model: [-1, 1]

            delegate: Rectangle {
                required property var modelData
                width: 5
                height: root.striking ? 1.5 : 5
                radius: width / 2
                color: Theme.crust
                x: parent.width / 2 + modelData * 11 - width / 2
                y: 18 + (root.striking ? 1.8 : 0)
                Behavior on height { NumberAnimation { duration: 70 } }
                Behavior on y { NumberAnimation { duration: 70 } }
            }
        }

        // Nose and whiskers.
        Rectangle {
            width: 5
            height: 3.5
            radius: 1.75
            color: Qt.alpha(MediaTint.accent, 0.85)
            anchors.horizontalCenter: parent.horizontalCenter
            y: 27
        }

        Repeater {
            model: [
                { side: -1, y: 26 }, { side: -1, y: 30 },
                { side: 1, y: 26 }, { side: 1, y: 30 }
            ]

            delegate: Rectangle {
                required property var modelData
                width: 13
                height: 1
                color: Qt.alpha(Theme.crust, 0.55)
                x: modelData.side < 0 ? -6 : parent.width - 7
                y: modelData.y
                rotation: modelData.side * (modelData.y > 28 ? 8 : -6)
            }
        }
    }

    // ── Paws ──
    Repeater {
        model: [-1, 1]

        delegate: Rectangle {
            id: paw
            required property var modelData
            required property int index

            readonly property bool down: root.striking
                && (paw.index === 0 ? root.leftDown : !root.leftDown)

            width: 20
            height: 13
            radius: 6.5
            color: Qt.alpha(Theme.text, 0.95)
            x: root.width / 2 + paw.modelData * 30 - width / 2
            y: paw.down ? root.height - 14 : root.height - 30
            rotation: paw.modelData * (paw.down ? 0 : 14)

            Behavior on y {
                NumberAnimation {
                    duration: paw.down ? 55 : 130
                    easing.type: paw.down ? Easing.InQuad : Easing.OutBack
                }
            }
            Behavior on rotation { NumberAnimation { duration: 100 } }

            // The knock: a ring that flashes out where the paw lands.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 1
                width: paw.down ? 22 : 6
                height: 2
                radius: 1
                color: MediaTint.accent
                opacity: paw.down ? 0.75 : 0
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }

    // Asleep when nothing is playing: the eyes are already shut by `striking`
    // being false, so all that is left is to stop it looking expectant.
    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: "z"
        color: Qt.alpha(Theme.subtext0, 0.7)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        opacity: root.live ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

        SequentialAnimation on y {
            running: !root.live
            loops: Animation.Infinite
            NumberAnimation { from: 8; to: 0; duration: 1400; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0; to: 8; duration: 1400; easing.type: Easing.InOutQuad }
        }
    }
}
