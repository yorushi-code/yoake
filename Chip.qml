import QtQuick

// The bar's one widget.
//
// Every mark in the bar used to be a glyph, sometimes with a number beside it,
// all in the same ink. That bar tells you a network exists. It does not tell
// you *which* network, and the difference between those two sentences is the
// whole of what makes an interface usable by someone who did not build it.
//
// A chip names the thing. It also carries a colour that says what kind of thing
// it is, so the eye sorts the row before reading any of it -- and the colour is
// the ground rather than a tint, because at this size a colour that is not the
// ground does not register at all.
//
// `live` is the other half: a coloured chip is a value that is *doing*
// something, a neutral one is a thing that merely exists. More than about five
// coloured chips at once means the distinction has stopped being made.
Rectangle {
    id: root

    // A key from Theme.domainHue, or "media" / "neutral".
    property string tone: "neutral"
    property string glyph: ""
    property string label: ""
    property string value: ""
    property bool live: true
    property bool alert: false
    // Long strings -- an SSID, a device name -- get a ceiling rather than the
    // bar getting wider. Zero means no ceiling.
    property real labelCap: 0

    signal clicked()
    signal rightClicked()
    signal scrolled(int delta)

    readonly property color ground: root.alert ? Theme.tone("alert")
        : (root.live ? Theme.tone(root.tone) : Qt.alpha(Theme.text, Theme.fillSubtle))
    readonly property color ink: root.alert ? Theme.onTone("alert")
        : (root.live ? Theme.onTone(root.tone) : Theme.subtext1)

    implicitWidth: row.implicitWidth + Theme.chipPadH * 2
    implicitHeight: Theme.chipHeight
    radius: Theme.pill(height)

    color: hit.containsMouse ? Qt.lighter(root.ground, 1.12) : root.ground
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    scale: hit.pressed ? 0.94 : 1
    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gapTight + 2

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            icon: root.glyph
            size: Theme.fontIconMicro
            // Filled on a coloured ground and outlined on a neutral one: a
            // solid glyph needs the contrast a live chip has and looks like a
            // blot without it.
            fill: root.live ? 1 : 0
            color: root.ink
        }

        Text {
            id: labelText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: root.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.weight: Font.Medium
            elide: Text.ElideRight
            width: root.labelCap > 0
                ? Math.min(implicitWidth, root.labelCap)
                : implicitWidth
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.value !== ""
            text: root.value
            color: root.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        anchors.margins: -2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.rightClicked();
            else root.clicked();
        }
        onWheel: wheel => root.scrolled(wheel.angleDelta.y)
    }
}
