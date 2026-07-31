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
        if (!enabled) return Qt.alpha(Theme.text, 0.06);
        if (accented) return ma.containsMouse ? Qt.lighter(MediaTint.accent, 1.2) : MediaTint.accent;
        return ma.containsMouse ? Qt.alpha(Theme.text, 0.16) : Qt.alpha(Theme.text, 0.08);
    }
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    scale: ma.pressed ? 0.9 : (ma.containsMouse ? 1.08 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: "Symbols Nerd Font"
        font.pixelSize: root.size * 0.5
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
