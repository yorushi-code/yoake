import QtQuick

// One tile in the control centre's grid.
//
// Two columns of these replace the stack of full-width rows the panel used to
// be. The row layout meant scrolling past sliders to reach Bluetooth, and every
// control looked equally important because they were all the same shape.
//
// Tapping the body toggles; tapping the chevron opens the tile's page (see
// CcPager). Splitting the two is what lets "turn Wi-Fi off" and "pick a
// network" live in one tile without either being a guess.
Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property string detail: ""
    property bool active: false
    property bool expandable: false
    // Some tiles are actions, not states — the wallpaper picker has nothing to
    // be "on".
    property bool stateful: true

    signal toggled()
    signal pageRequested()

    height: 70
    radius: Theme.radius + 4
    color: root.active && root.stateful
        ? Theme.accent
        : (body.containsMouse || chevronArea.containsMouse
            ? Qt.alpha(Theme.text, Theme.fillHover) : Qt.alpha(Theme.text, Theme.fillSubtle))
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    // The ground already answers the pointer here; the lift is what makes the
    // tile read as sitting above the page rather than as a rectangle that got
    // brighter. `hoverScale` rather than the small rung — this is 70px tall,
    // and the travel should read the same as on a chip a third the size.
    scale: body.pressed ? Theme.pressScale
                        : ((body.containsMouse || chevronArea.containsMouse)
                           ? Theme.hoverScale : 1)
    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
    }

    readonly property color contentColor: root.active && root.stateful ? Theme.crust : Theme.text

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    // The icon fills when the tile is on.
    //
    // The tile already said so twice -- an accent ground and a dark label --
    // and the icon said it not at all, because a Nerd Font has no way to. It is
    // the same shape solidifying now rather than a second picture appearing,
    // which is the difference between a state and a swap.
    MaterialSymbol {
        id: mark
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 12
        icon: root.glyph
        size: Theme.fontIcon
        fill: root.active && root.stateful ? 1 : 0
        color: root.contentColor
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: mark.bottom
        anchors.topMargin: 5
        text: root.label
        color: root.contentColor
        font.pixelSize: Theme.fontBody
        font.bold: true
        elide: Text.ElideRight
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        visible: root.detail !== ""
        text: root.detail
        color: root.active && root.stateful ? Qt.alpha(Theme.crust, Theme.veilDense) : Theme.subtext0
        font.pixelSize: Theme.fontLabel
        elide: Text.ElideRight
    }

    // Its own hit area, and a visible one: the chevron is the difference
    // between switching a radio off and choosing what it connects to.
    Rectangle {
        id: chevron
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        width: 24
        height: 24
        radius: Theme.radiusChip
        visible: root.expandable
        color: chevronArea.containsMouse
            ? Qt.alpha(root.contentColor, 0.18) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        MaterialSymbol {
            anchors.centerIn: parent
            icon: Glyphs.chevronRight
            size: Theme.fontIconSmall
            color: root.active && root.stateful ? Theme.crust : Theme.subtext1
        }

        MouseArea {
            id: chevronArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pageRequested()
        }
    }
}
