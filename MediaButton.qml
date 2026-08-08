import QtQuick

// Round transport button, shared by the media OSD and the desktop card so
// both sets of controls stay identical.
Rectangle {
    id: root

    property string glyph: ""
    property int size: 32
    // The play/pause button carries the accent fill; skip buttons stay quiet
    // so the primary action is obvious at a glance.
    property bool accented: false
    signal activated()

    width: size
    height: size
    radius: size / 2
    opacity: enabled ? 1 : 0.35

    color: {
        if (!enabled) return Qt.alpha(Theme.text, Theme.fillSubtle);
        if (accented) return ma.containsMouse ? Qt.lighter(MediaTint.accent, 1.2) : MediaTint.accent;
        return ma.containsMouse ? Qt.alpha(Theme.text, Theme.fillHover) : Qt.alpha(Theme.text, Theme.fillSubtle);
    }
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    scale: ma.pressed ? 0.9 : (ma.containsMouse ? 1.08 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
    }

    // Solid, not outlined. A transport control is a button rather than a
    // status, and an outlined play arrow at fourteen pixels is a hairline
    // triangle nobody can hit with their eye.
    MaterialSymbol {
        anchors.centerIn: parent
        icon: root.glyph
        size: root.size * 0.5
        fill: 1
        color: root.accented ? Theme.crust : Theme.text
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
