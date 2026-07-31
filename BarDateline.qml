import QtQuick
import Quickshell

// The dateline: the day, set as a masthead sets one.
//
// Uppercase, widely tracked, small — the typographic device that says "this is
// the record for today" without needing a box or a colour to do it. It is the
// only thing in the centre of row one, so the composition has a middle.
Item {
    id: root

    property var barWindow: null

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: true
    }

    Text {
        id: label
        anchors.centerIn: parent
        // The session runs under en_US, so the default locale would set an
        // English dateline over an interface that is Russian throughout.
        text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "ddd d MMMM").toUpperCase()
        color: area.containsMouse ? Theme.text : Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
        font.weight: Font.Medium
        font.letterSpacing: 2.4
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Menus.closeAll();
            Toggles.calendarOpen = !Toggles.calendarOpen;
        }
    }

    Tooltip {
        anchorItem: root
        active: area.containsMouse
        text: "Календарь"
    }
}
