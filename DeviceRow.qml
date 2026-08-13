import QtQuick

// One real thing in a list of real things: a sink, a network, a paired device.
//
// Four states, and all four are drawn, which is the difference between a list
// and a list you can use. Resting shows what it is. Hovered says it can be
// clicked. Active is a solid domain ground with dark ink and *no control of its
// own*, because the thing that is active is controlled by the panel's header.
// Muted or unavailable keeps its control but drains the colour out of it, so
// the row still reads as present and plainly not doing anything.
//
// The subtitle is the technical name -- a node id, a MAC, an interface. Nobody
// needs it most days and everybody needs it the day something has two of the
// same name.
Rectangle {
    id: root

    property string glyph: ""
    property string name: ""
    property string subtitle: ""
    property string tone: "audio"
    property bool active: false
    property bool muted: false
    // Set false for the active row: its value belongs to the header.
    property bool hasControl: true
    // A row that *does* something rather than one that is a setting. It has no
    // active state to show -- the panel is gone a moment after it is clicked --
    // and the one that ends the session says so under the pointer rather than
    // permanently: a row that is red before anyone has reached for it is a row
    // that shouts at a person for opening a panel.
    property bool danger: false
    property real value: 0
    property string trailing: ""

    signal activated()
    signal toggledMute()
    signal moved(real value)
    signal committed(real value)
    signal rightClicked()

    implicitWidth: 200
    implicitHeight: body.implicitHeight + Theme.rowPad * 2 - (root.hasControl ? 0 : Theme.gapTight)
    radius: Theme.radiusRow

    // ── Why the selected row is the accent and not the domain ──
    //
    // A filled selected row is universal -- every list on every desktop does
    // it -- so it stays. What does not stay is filling it with the *domain's*
    // hue, which was the same borrowed move the bar has already been taken off:
    // it made each panel a differently-coloured product rather than one of six
    // relatives, and it spent a colour on the one row in the list that is
    // already unmistakable by position.
    //
    // So the accent fills, and the accent is the shell's own -- derived from
    // the wallpaper, shared by every panel. The domain survives where it does
    // real work: tinting the glyph of a row that is *not* selected, which is
    // what tells you at a glance that this list is about networks rather than
    // about sinks.
    color: root.active
        ? Theme.accent
        : (hit.containsMouse
            ? (root.danger ? Qt.alpha(Theme.tone("alert"), Theme.tintActive)
                           : Qt.alpha(Theme.text, Theme.fillHover))
            : Qt.alpha(Theme.text, Theme.fillSubtle))
    Behavior on color { ColorAnimation { duration: Theme.animNormal } }

    // It gives under the finger.
    //
    // Every row of every system panel is one of these, and pressing one used to
    // produce nothing at all: the colour has a hover Behavior, but a press said
    // nothing until the *result* arrived — which for a Wi-Fi network is a
    // round trip, and for a row that is already selected is never. A control
    // that does not answer the press reads as a control that did not hear it,
    // and that is most of what "the interaction feels bad" means.
    //
    // The same language `Chip` and `CcTile` already speak, on the shell's own
    // acknowledgement timing: instant, because a press is answered rather than
    // narrated.
    scale: hit.pressed ? Theme.pressScale : 1
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeSpringBig
        }
    }

    readonly property color ink: root.active ? Theme.crust : Theme.text
    readonly property color subInk: root.active
        ? Qt.alpha(Theme.crust, Theme.inkSoft)
        : Theme.subtext0

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.rowPad
        anchors.rightMargin: Theme.rowPad
        spacing: Theme.spacing

        Row {
            width: parent.width
            spacing: Theme.gapWide

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.glyph !== ""
                icon: root.glyph
                size: Theme.fontIcon
                fill: root.active ? 1 : 0
                // The domain lives here, on the rows that are not selected --
                // the same place it lives in the bar, and for the same reason:
                // a tint ranks a list without turning every row into a sticker.
                color: root.active ? root.ink
                    : (root.danger && hit.containsMouse ? Theme.tone("alert")
                                                        : Theme.tone(root.tone))
            }

            Column {
                width: parent.width - (root.glyph !== "" ? Theme.fontIcon + Theme.gapWide : 0)
                    - (trailingText.visible ? trailingText.width + Theme.gapWide : 0)
                spacing: Theme.gapPair

                Text {
                    width: parent.width
                    text: root.name
                    color: root.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.weight: root.active ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    color: root.subInk
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMicro
                    elide: Text.ElideRight
                }
            }

            Text {
                id: trailingText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.trailing !== ""
                text: root.trailing
                color: root.subInk
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.features: ({ "tnum": 1 })
            }
        }

        Row {
            width: parent.width
            visible: root.hasControl && !root.active
            spacing: Theme.gapWide

            Rectangle {
                id: muteButton
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: Theme.pill(height)
                color: muteHit.containsMouse
                    ? Qt.alpha(Theme.text, Theme.fillHover)
                    : Qt.alpha(Theme.text, Theme.fillMuted)
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    icon: root.muted ? Glyphs.volumeMute : Glyphs.volumeHigh
                    size: Theme.fontIconMicro
                    fill: 1
                    color: root.muted ? Theme.subtext0 : Theme.text
                }

                MouseArea {
                    id: muteHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggledMute()
                }
            }

            HSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - muteButton.width - valueText.width - Theme.gapWide * 2
                value: root.value
                muted: root.muted
                tint: Theme.tone(root.tone)
                onMoved: v => root.moved(v)
                onCommitted: v => root.committed(v)
            }

            Text {
                id: valueText
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(root.value * 100) + "%"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.features: ({ "tnum": 1 })
            }
        }
    }

    // Under the controls, so the slider and the mute button take their own
    // clicks and only the rest of the row selects it.
    MouseArea {
        id: hit
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.rightClicked();
            else root.activated();
        }
    }
}
