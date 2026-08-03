import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Notification history, split out of NotificationCenter so it can be created
// only while it is on screen. The toast stack has to exist from startup —
// it is what shows a notification in the first place — but this panel is
// several hundred lines of list that most sessions never open.
PanelWindow {
    id: win

    // Animations bind to this, not to the toggle. The panel is created lazily,
    // so it is born with the toggle already true — an entry animation bound
    // straight to the toggle has nothing to animate from and the panel simply
    // appears at its final size. `armed` turns on a frame later, so opening is
    // always a transition.
    readonly property bool open: Toggles.notifCenterOpen && win.armed
    property bool armed: false
    property Timer _armTick: Timer {
        id: armTick
        interval: 16
        running: true
        onTriggered: win.armed = true
    }
    // See ControlCenter.qml: mapping is an explicit bool so the exit
    // animation isn't cut off by a visible-binding race.
    property bool mapped: false
    visible: mapped
    // Full-screen so a click anywhere outside the card can close it. The
    // card itself is placed by anchors within this.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusiveZone: 0
    // Bound to the toggle, not to `open`. `open` waits a frame for `armed`
    // so the entrance has something to animate from, and a surface mapped
    // asking for no keyboard never gets offered one afterwards -- which is
    // a panel that ignores Escape and every key in it.
    focusable: Toggles.notifCenterOpen
    // Exclusive, not merely focusable. `focusable` alone asks for
    // on-demand interactivity, which means the compositor hands over the
    // keyboard when the surface is clicked -- so a panel opened from a
    // keybind ignored Escape until you had clicked it first.
    WlrLayershell.keyboardFocus: Toggles.notifCenterOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    // Escape closes it, from anywhere inside.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Toggles.notifCenterOpen = false;
                event.accepted = true;
            }
        }
    }

    Timer {
        id: hideDelay
        interval: Theme.animExit + 40
        onTriggered: win.mapped = false
    }
    Connections {
        target: Toggles
        function onNotifCenterOpenChanged() {
            if (Toggles.notifCenterOpen) {
                hideDelay.stop();
                win.mapped = true;
            } else {
                hideDelay.restart();
            }
        }
    }
    Component.onCompleted: win.mapped = Toggles.notifCenterOpen

    // Click-outside-to-close, which this panel never had: the only ways to
    // dismiss it were the ✕ and the keybind that opened it.
    MouseArea {
        anchors.fill: parent
        onClicked: Toggles.notifCenterOpen = false
    }

    Item {
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Toggles.notifCenterOpen = false

        PanelChrome {
            id: chrome
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
            anchors.rightMargin: Theme.barMargin
            width: 340
            // As tall as it needs to be. A fixed 500 meant one notification sat
            // at the top of a panel with four fifths of nothing under it, which
            // reads as a list that failed to load rather than a quiet day. The
            // floor leaves room for the cat when there is nothing at all.
            height: Notifs.tracked.length === 0
                ? 260
                : Math.min(500, header.height + historyColumn.height + 26)
            screenX: Screen.width - Theme.barMargin - width
            screenY: Theme.barHeight + Theme.barMargin * 2
            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : 0.9
            transformOrigin: Item.TopRight
            // See ControlCenter: open punches in, exit accelerates.
            Behavior on opacity {
                NumberAnimation {
                    duration: win.open ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: win.open ? Theme.easeEmphasized : Theme.easeExit
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: win.open ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: win.open ? Theme.easeSpringBig : Theme.easeExit
                }
            }
            onCloseRequested: Toggles.notifCenterOpen = false

            // Swallows clicks so the backdrop doesn't treat a click on the
            // panel itself as "outside".
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Row {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 14
                anchors.leftMargin: 16
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.tracked.length === 0
                        ? "Нет уведомлений" : "Уведомления"
                    color: Theme.subtext1
                    font.pixelSize: Theme.fontBody
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.tracked.length > 0
                    width: clearText.implicitWidth + 16
                    height: 20
                    radius: Theme.radiusChip
                    color: clearMa.containsMouse ? Qt.alpha(Theme.red, 0.3) : Qt.alpha(Theme.text, Theme.fillSubtle)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "Очистить"
                        color: Theme.text
                        font.pixelSize: Theme.fontLabel
                    }
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.clearAll()
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: dndText.implicitWidth + 16
                    height: 20
                    radius: Theme.radiusChip
                    color: Notifs.dnd ? Theme.accent
                        : (dndMa.containsMouse ? Qt.alpha(Theme.text, 0.16) : Qt.alpha(Theme.text, 0.08))
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: dndText
                        anchors.centerIn: parent
                        text: "Не беспокоить"
                        color: Notifs.dnd ? Theme.crust : Theme.text
                        font.pixelSize: Theme.fontLabel
                    }
                    MouseArea {
                        id: dndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: Notifs.tracked.length === 0
                text: "Тихо"
                catSize: 118
            }

            Flickable {
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                anchors.topMargin: 8
                contentHeight: historyColumn.height
                clip: true

                Column {
                    id: historyColumn
                    width: parent.width
                    spacing: Theme.spacing

                    Repeater {
                        model: Notifs.newestFirst
                        delegate: Rectangle {
                            id: histDelegate
                            required property var modelData
                            required property int index
                            width: historyColumn.width
                            height: histContent.height + 18
                            radius: Theme.radiusCard
                            color: Theme.surface0

                            // Same pop-in language as the toasts, capped
                            // so a long history doesn't queue a visibly
                            // slow cascade on first open.
                            opacity: 0
                            scale: 0.92
                            transformOrigin: Item.Top
                            Component.onCompleted: histEntryAnim.start()
                            ParallelAnimation {
                                id: histEntryAnim
                                SequentialAnimation {
                                    PauseAnimation { duration: Math.max(0, Math.min(histDelegate.index, 6)) * 30 }
                                    NumberAnimation {
                                        target: histDelegate; property: "opacity"; to: 1
                                        duration: Theme.animNormal
                                        easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized
                                    }
                                }
                                SequentialAnimation {
                                    PauseAnimation { duration: Math.max(0, Math.min(histDelegate.index, 6)) * 30 }
                                    NumberAnimation {
                                        target: histDelegate; property: "scale"; to: 1
                                        duration: Theme.animNormal
                                        easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring
                                    }
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                width: 3
                                radius: 1.5
                                color: Notifs.accentFor(modelData.urgency)
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: modelData.dismiss()
                            }

                            Row {
                                id: histContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 18
                                anchors.rightMargin: 10
                                anchors.topMargin: 9
                                spacing: Theme.gapWide

                                NotificationIcon {
                                    size: 24
                                    notification: modelData
                                    accent: Notifs.accentFor(modelData.urgency)
                                }

                                Column {
                                    width: histContent.width - 24 - 18 - 9 - 10
                                    spacing: 2
                                    Text {
                                        width: parent.width
                                        text: modelData.summary
                                        color: Theme.text
                                        font.pixelSize: Theme.fontBody
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        width: parent.width
                                        visible: modelData.body.length > 0
                                        text: modelData.body
                                        textFormat: Text.StyledText
                                        color: Theme.subtext0
                                        font.pixelSize: Theme.fontSmall
                                        wrapMode: Text.WordWrap
                                    }
                                    NotificationActions {
                                        width: parent.width
                                        notification: modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
