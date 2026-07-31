import QtQuick
import Quickshell

// Screen-recording indicator. Only present while recording; the width collapses
// to zero when idle so the island shrinks back.
Item {
    id: root

    property var barWindow: null
    // Scoped to the output so the same widget on a second monitor
    // does not share one open-menu key with this one.
    readonly property string menuId: Menus.idFor(root.barWindow, "recorder")

    visible: Recorder.recording
        // implicitWidth off the row's *implicit* width, and the row anchored
    // rather than centred: reading .width here while the row centres itself
    // in that same width is a cycle, and Qt resolves it in no fixed order.
    // Whenever the content changed width -- VPN going from "вкл" to a speed,
    // volume from 50%% to 100%% -- the row sat off-centre inside the old width
    // for a frame, which is the clipped percentage at the island's edge.
    implicitWidth: Recorder.recording ? recRow.implicitWidth : 0
    width: implicitWidth
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Row {
        id: recRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
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
                Menus.toggle(root.menuId);
                return;
            }
            Recorder.stop();
        }
    }

    ActionMenu {
        id: menu
        menuId: root.menuId
        anchorItem: root
        open: Menus.isOpen(root.menuId)
        model: Menus.isOpen(root.menuId) ? [
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
        active: ma.containsMouse && !Menus.isOpen(root.menuId)
        text: "Идёт запись — " + Recorder.elapsedText
        subtext: "ЛКМ — остановить · ПКМ — меню"
    }
}
