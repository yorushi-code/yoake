import QtQuick

// One mark in the bar.
//
// What it has to do has not changed and is worth restating, because the form
// below is the second attempt at it: a mark must **name its subject in words**,
// and the row must be **sortable by colour before it is read** — you should be
// able to find the network without reading anything.
//
// The first attempt did both by making every mark a saturated pill with dark
// ink on it. That works, and it was lifted almost whole from the shell this one
// was measured against, and it has a real fault of its own: when ten things are
// each a coloured sticker, colour has stopped ranking anything. Everything is
// accent, so nothing is.
//
// ── The form this uses instead ──
//
// **The ground is never coloured.** The strip is one surface and the marks sit
// on it; nothing in the normal state of the machine is a separate coloured
// object. What carries the domain is a hairline **under** the mark, on a
// baseline shared by the whole row. A row of coloured ticks at one constant y
// is easier to scan than ten pills at ten different widths — the eye follows a
// line, not a set of shapes.
//
// **Colour as ground is reserved for alert**, and that is the whole reason it
// stays loud. A filled mark never appears while the machine is fine, so when
// one appears it is the only filled thing on the bar and needs no size, no
// motion and no badge to be found.
//
// So there are three classes and they are structurally different rather than
// differently coloured:
//
//   passive   neutral ink, no rule          — a thing that merely exists
//   live      tinted glyph, neutral label,  — a value that is doing something
//             domain rule beneath
//   alert     filled ground, dark ink       — something is wrong
Item {
    id: root

    // A key from Theme.domainHue, or "media" / "neutral".
    property string tone: "neutral"
    property string glyph: ""
    property string label: ""
    property string value: ""
    // A chip is passive unless it says otherwise.
    //
    // This defaulted to `true`, which put the loudest of the three classes on
    // any widget that never thought about the question — and one had not: the
    // battery has carried a permanent power-coloured rule under it since the
    // classes were written, because a rule under a percentage looks deliberate
    // and nobody caught it. That is the argument. `Reveal` defaults the other
    // way on purpose, so a surface that forgot to declare itself looks
    // overdressed and gets noticed; the same reasoning fails here, because it
    // *was* overdressed for weeks and went unnoticed.
    //
    // The deeper reason is that the two defaults are not the same kind of
    // thing. Narrative-or-instant is how a surface arrives, and both are
    // honest. Live-or-passive is a claim about the data: the rule says this
    // subsystem is doing something. Asserting that on behalf of a widget that
    // never described its subject is a lie told by a default.
    property bool live: false
    property bool alert: false
    // Long strings -- an SSID, a device name -- get a ceiling rather than the
    // bar getting wider. Zero means no ceiling.
    property real labelCap: 0

    signal clicked()
    signal rightClicked()
    signal scrolled(int delta)

    implicitWidth: row.implicitWidth + Theme.chipPadH * 2
    implicitHeight: Theme.chipHeight

    readonly property color domain: Theme.tone(root.tone)

    // The label is the same ink in every class. Its job is to be read, and a
    // label that changes colour with state is a label competing with the state.
    readonly property color labelInk: root.alert
        ? Theme.onTone("alert")
        : (root.live ? Theme.text : Theme.subtext0)

    // The glyph is where the domain lives when the mark is live. Passive marks
    // keep it neutral, because a passive thing has no domain worth ranking.
    readonly property color glyphInk: root.alert
        ? Theme.onTone("alert")
        : (root.live ? root.domain : Theme.subtext0)

    // ── Ground ──
    //
    // Present only under the pointer, and filled only in alert. Hover is a
    // response to the pointer rather than a state of the machine, so it is the
    // faintest thing here and it does not survive the pointer leaving.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusChip
        color: root.alert
            ? Theme.tone("alert")
            : (hit.containsMouse ? Qt.alpha(Theme.text, Theme.fillSubtle) : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        // Half a step tighter than the ladder's smallest gap: a glyph and the
        // word it belongs to are one mark, and at label size the ladder's gap
        // reads as two.
        spacing: Theme.gapTight + 2

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            icon: root.glyph
            size: Theme.fontIconMicro
            // Solid when the mark is live, outlined when it is not. The fill
            // axis is doing the same job as the rule below -- saying this one
            // is *running* -- at a size where the rule alone would be thin.
            fill: root.live || root.alert ? 1 : 0
            color: root.glyphInk
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            id: labelText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: root.labelInk
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.weight: Font.Medium
            elide: Text.ElideRight
            width: root.labelCap > 0
                ? Math.min(implicitWidth, root.labelCap)
                : implicitWidth
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.value !== ""
            text: root.value
            color: root.labelInk
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            // A number is the thing being reported, so it outranks the noun in
            // front of it. This is the only weight step in the mark.
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    // ── The rule ──
    //
    // Inset to the content rather than the hit area, so the line is the width
    // of what it underlines and the row of them reads as a set of measurements
    // rather than as a set of boxes.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        width: root.alert ? 0 : row.implicitWidth
        height: 2
        radius: height / 2
        color: root.domain
        opacity: root.live && !root.alert ? 1 : 0

        // Grows from the middle when a mark comes alive rather than fading in:
        // the rule is a measurement, and a measurement that appears at full
        // length has not been taken.
        Behavior on width {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasized
            }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    scale: hit.pressed ? Theme.pressScaleSmall : 1
    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
    }

    // Whether the pointer is on it. Exposed because a chip is the whole of most
    // bar widgets, and the three that carry a tooltip had no way to ask: they
    // were left bound to a literal `false`, which is a tooltip that can never
    // appear and looks exactly like one that simply has nothing to say.
    readonly property alias hovered: hit.containsMouse

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
