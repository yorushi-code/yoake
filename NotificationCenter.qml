import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root

    // Toasts carry their own `leaving` flag rather than being dropped from the
    // model on expiry: a Repeater destroys the delegate the instant its entry
    // disappears, which is why toasts used to vanish mid-air with no exit
    // animation at all.
    property var activeToasts: []

    // Critical notifications linger far longer than the rest, since the spec
    // treats them as needing acknowledgement — but never forever. An infinite
    // timeout meant that if the sending application closed the notification
    // out from under us, the toast had no timer to remove it and sat on screen
    // permanently, showing nothing (the underlying object was gone, so summary
    // and body read back empty).
    function timeoutFor(notification) {
        if (notification.urgency === NotificationUrgency.Critical) return 30000;
        if (notification.urgency === NotificationUrgency.Low) return 3000;
        return 6000;
    }

    function accentFor(urgency) {
        if (urgency === NotificationUrgency.Critical) return Theme.red;
        if (urgency === NotificationUrgency.Low) return Theme.subtext0;
        return Theme.accent;
    }

    // The text is snapshotted rather than read live from the notification.
    // The object is destroyed as soon as it stops being retained — by the
    // sending application, or by a dismissal from the history — and a toast
    // still holding that reference rendered as a blank card with a close
    // button and nothing in it.
    function appendToast(notification) {
        const entry = {
            notification: notification,
            summary: notification.summary || "",
            body: notification.body || "",
            urgency: notification.urgency,
            leaving: false
        };
        // Nothing to show and nothing to say — an application sending an empty
        // notification should not leave a blank card on screen.
        if (entry.summary === "" && entry.body === "") return;

        activeToasts = [...activeToasts, entry];
        const timer = toastTimerComponent.createObject(root, {
            notification, interval: root.timeoutFor(notification)
        });
        timer.start();
    }

    // Two steps: flag it so the delegate can play its exit, then drop it once
    // the animation has had time to run.
    function dismissToast(notification) {
        root.activeToasts = root.activeToasts.map(t =>
            t.notification === notification
                ? { notification: t.notification, summary: t.summary, body: t.body,
                    urgency: t.urgency, leaving: true }
                : t);
        const reaper = toastReaperComponent.createObject(root, { notification });
        reaper.start();
    }

    Component {
        id: toastTimerComponent
        Timer {
            property var notification
            onTriggered: {
                root.dismissToast(notification);
                destroy();
            }
        }
    }

    Component {
        id: toastReaperComponent
        Timer {
            property var notification
            interval: Theme.animExit + 60
            onTriggered: {
                root.activeToasts = root.activeToasts.filter(t => t.notification !== notification);
                destroy();
            }
        }
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: notification => {
            notification.tracked = true;
            // Retire the toast the moment the notification goes away, whoever
            // closed it. Without this the card outlives its own content.
            notification.closed.connect(() => root.dismissToast(notification));
            // Do-not-disturb suppresses the popup only; the notification is
            // still tracked, so nothing is lost from the history.
            if (!Notifs.dnd) root.appendToast(notification);
            Notifs.arrived();
        }
    }

    // Pushed on every change rather than only on arrival — assigning it just in
    // onNotification left the bar's badge counting up forever as items were
    // dismissed.
    Connections {
        target: server.trackedNotifications
        function onValuesChanged() {
            Notifs.count = server.trackedNotifications.values.length;
        }
    }

    Connections {
        target: Notifs
        function onClearAllRequested() {
            for (const n of [...server.trackedNotifications.values]) n.dismiss();
            root.activeToasts = [];
        }
    }

    // ── Toast popups: top-right, auto-dismiss, slide+fade in ──
    PanelWindow {
        anchors {
            top: true
            right: true
        }
        margins {
            top: Theme.barHeight + Theme.barMargin * 2
            right: Theme.barMargin
        }
        implicitWidth: 340
        implicitHeight: Math.max(1, toastColumn.height)
        color: "transparent"
        exclusiveZone: 0
        focusable: false
        visible: root.activeToasts.length > 0

        Column {
            id: toastColumn
            width: parent.width
            spacing: 8

            Repeater {
                model: root.activeToasts
                delegate: Item {
                    id: toastDelegate
                    required property var modelData
                    required property int index

                    readonly property var notification: modelData.notification
                    readonly property bool leaving: modelData.leaving
                    readonly property string summary: modelData.summary
                    readonly property string body: modelData.body
                    readonly property int urgency: modelData.urgency

                    width: toastColumn.width
                    height: toastChrome.height

                    // Animates in on creation (Repeater delegates start
                    // already-parented, so this fires once on entry) with a
                    // slight overshoot for a "tactile" pop rather than a
                    // plain slide, staggered when several land at once.
                    opacity: 0
                    x: 40
                    scale: 0.92
                    Component.onCompleted: entryAnim.start()
                    ParallelAnimation {
                        id: entryAnim
                        SequentialAnimation {
                            PauseAnimation { duration: Math.max(0, toastDelegate.index) * 50 }
                            NumberAnimation {
                                target: toastDelegate; property: "opacity"; to: 1
                                duration: Theme.animNormal
                                easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized
                            }
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: Math.max(0, toastDelegate.index) * 50 }
                            NumberAnimation {
                                target: toastDelegate; property: "x"; to: 0
                                duration: Theme.animSlow
                                easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig
                            }
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: Math.max(0, toastDelegate.index) * 50 }
                            NumberAnimation {
                                target: toastDelegate; property: "scale"; to: 1
                                duration: Theme.animSlow
                                easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig
                            }
                        }
                    }

                    // Leaves the way it came, accelerating out, instead of
                    // being destroyed on the spot.
                    ParallelAnimation {
                        id: exitAnim
                        NumberAnimation {
                            target: toastDelegate; property: "opacity"; to: 0
                            duration: Theme.animExit
                            easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeExit
                        }
                        NumberAnimation {
                            target: toastDelegate; property: "x"; to: 60
                            duration: Theme.animExit
                            easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeExit
                        }
                    }
                    onLeavingChanged: if (leaving) exitAnim.start()

                    PanelChrome {
                        id: toastChrome
                        width: parent.width
                        height: toastContent.height + 22
                        screenX: Screen.width - Theme.barMargin - toastColumn.width
                        screenY: Theme.barHeight + Theme.barMargin * 2 + toastDelegate.y
                        onCloseRequested: root.dismissToast(toastDelegate.notification)

                        // Urgency stripe: the only always-visible cue telling a
                        // critical alert apart from a routine one.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            width: 3
                            radius: 1.5
                            color: root.accentFor(toastDelegate.urgency)
                        }

                        // Clicking the body dismisses, matching every other
                        // notification daemon; sits below the content so the
                        // action buttons still get their clicks.
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: root.dismissToast(toastDelegate.notification)
                        }

                        Row {
                            id: toastContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 22
                            anchors.rightMargin: 12
                            anchors.topMargin: 11
                            spacing: 10

                            // The server advertises image support, so anything
                            // an application sends has to actually be drawn —
                            // previously it was accepted and silently dropped.
                            NotificationIcon {
                                notification: toastDelegate.notification
                                accent: root.accentFor(toastDelegate.urgency)
                            }

                            Column {
                                width: toastContent.width - 32 - toastContent.spacing - 12
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: toastDelegate.summary
                                    color: root.accentFor(toastDelegate.urgency)
                                    font.pixelSize: 13
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    width: parent.width
                                    visible: toastDelegate.body.length > 0
                                    text: toastDelegate.body
                                    textFormat: Text.StyledText
                                    color: Theme.text
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }

                                NotificationActions {
                                    width: parent.width
                                    notification: toastDelegate.notification
                                    onInvoked: root.dismissToast(toastDelegate.notification)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── History panel: toggled from Toggles.notifCenterOpen ──
    PanelWindow {
        id: win
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
        focusable: Toggles.notifCenterOpen

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
            focus: Toggles.notifCenterOpen
            Keys.onEscapePressed: Toggles.notifCenterOpen = false

            PanelChrome {
                id: chrome
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
                anchors.rightMargin: Theme.barMargin
                width: 340
                height: 500
                screenX: Screen.width - Theme.barMargin - width
                screenY: Theme.barHeight + Theme.barMargin * 2
                opacity: Toggles.notifCenterOpen ? 1 : 0
                scale: Toggles.notifCenterOpen ? 1 : 0.9
                transformOrigin: Item.TopRight
                // See ControlCenter: open punches in, exit accelerates.
                Behavior on opacity {
                    NumberAnimation {
                        duration: Toggles.notifCenterOpen ? Theme.animSlow : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Toggles.notifCenterOpen ? Theme.easeEmphasized : Theme.easeExit
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Toggles.notifCenterOpen ? Theme.animSlow : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Toggles.notifCenterOpen ? Theme.easeSpringBig : Theme.easeExit
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
                        text: server.trackedNotifications.values.length === 0
                            ? "Нет уведомлений" : "Уведомления"
                        color: Theme.subtext1
                        font.pixelSize: 12
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: server.trackedNotifications.values.length > 0
                        width: clearText.implicitWidth + 16
                        height: 20
                        radius: 10
                        color: clearMa.containsMouse ? Qt.alpha(Theme.red, 0.3) : Qt.alpha(Theme.text, 0.08)
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "Очистить"
                            color: Theme.text
                            font.pixelSize: 10
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
                        radius: 10
                        color: Notifs.dnd ? Theme.accent
                            : (dndMa.containsMouse ? Qt.alpha(Theme.text, 0.16) : Qt.alpha(Theme.text, 0.08))
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            id: dndText
                            anchors.centerIn: parent
                            text: "Не беспокоить"
                            color: Notifs.dnd ? Theme.crust : Theme.text
                            font.pixelSize: 10
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
                        spacing: 6

                        Repeater {
                            model: server.trackedNotifications
                            delegate: Rectangle {
                                id: histDelegate
                                required property var modelData
                                required property int index
                                width: historyColumn.width
                                height: histContent.height + 18
                                radius: 16
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
                                    color: root.accentFor(modelData.urgency)
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
                                    spacing: 9

                                    NotificationIcon {
                                        size: 24
                                        notification: modelData
                                        accent: root.accentFor(modelData.urgency)
                                    }

                                    Column {
                                        width: histContent.width - 24 - 18 - 9 - 10
                                        spacing: 2
                                        Text {
                                            width: parent.width
                                            text: modelData.summary
                                            color: Theme.text
                                            font.pixelSize: 12
                                            font.bold: true
                                            wrapMode: Text.WordWrap
                                        }
                                        Text {
                                            width: parent.width
                                            visible: modelData.body.length > 0
                                            text: modelData.body
                                            textFormat: Text.StyledText
                                            color: Theme.subtext0
                                            font.pixelSize: 11
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
}
