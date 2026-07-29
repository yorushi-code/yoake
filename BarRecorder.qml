import QtQuick
import Quickshell

// Screen-recording indicator. Only present while recording; the width collapses
// to zero when idle so the island shrinks back.
Item {
    id: root

    property var barWindow: null

    visible: Recorder.recording
    width: Recorder.recording ? recRow.width : 0
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Row {
        id: recRow
        anchors.centerIn: parent
        spacing: 5

        Rectangle {
            width: 9
            height: 9
            radius: 4.5
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.red
            // Slow blink so the recording state is unmistakable at a glance
            // without being distracting.
            SequentialAnimation on opacity {
                running: Recorder.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Recorder.elapsedText
            color: Theme.text
            font.pixelSize: 11
            font.bold: true
        }
        // Mic glyph only while the mic is armed, so the recording audio source
        // is visible at a glance.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Recorder.micEnabled
            text: Glyphs.microphone
            font.family: "Symbols Nerd Font"
            font.pixelSize: 12
            color: Theme.red
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (Menus.isOpen(menu)) Menus.closeAll();
                else Menus.open(menu);
                return;
            }
            Recorder.stop();
        }
    }

    ActionMenu {
        id: menu
        anchorItem: root
        open: Menus.isOpen(menu)
        model: Menus.isOpen(menu) ? [
            {
                text: "Остановить запись",
                glyph: Glyphs.stop,
                destructive: true,
                action: () => Recorder.stop()
            },
            {
                text: "Микрофон в записи",
                glyph: Recorder.micEnabled ? Glyphs.microphone : Glyphs.microphoneOff,
                checkable: true,
                checked: Recorder.micEnabled,
                action: () => Recorder.toggleMic()
            },
            { separator: true },
            {
                text: "Папка с записями",
                glyph: Glyphs.folder,
                action: () => Quickshell.execDetached(["xdg-open", Recorder.outputDir])
            }
        ] : []
    }

    Tooltip {
        anchorItem: root
        active: ma.containsMouse && !Menus.isOpen(menu)
        text: "Идёт запись — " + Recorder.elapsedText
        subtext: "ЛКМ — остановить · ПКМ — меню"
    }
}
