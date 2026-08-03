import QtQuick
import Quickshell
import Quickshell.Wayland
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

    // The text is snapshotted rather than read live from the notification.
    // The object is destroyed as soon as it stops being retained — by the
    // sending application, or by a dismissal from the history — and a toast
    // still holding that reference rendered as a blank card with a close
    // button and nothing in it.
    function appendToast(notification) {
        const entry = {
            // Stable key for the ScriptModel below; without one the list
            // cannot be diffed and every toast is rebuilt on any change.
            id: notification.id,
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
                ? { id: t.id, notification: t.notification, summary: t.summary,
                    body: t.body, urgency: t.urgency, leaving: true }
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
            if (!Notifs.dnd && !Media.announcesTrack(notification)) root.appendToast(notification);
            Notifs.arrived();
        }
    }

    // Pushed on every change rather than only on arrival — assigning it just in
    // onNotification left the bar's badge counting up forever as items were
    // dismissed.
    Connections {
        target: server.trackedNotifications
        function onValuesChanged() {
            const values = server.trackedNotifications.values;
            Notifs.count = values.length;
            // A copy: the model's own values array is mutated in place, so
            // assigning it directly hands out a reference that compares equal
            // to itself after every change and never redraws.
            Notifs.tracked = values.slice();
            Media._adoptNotificationArt(values);
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
        // Overlay, not the default Top: niri draws a fullscreen window above
        // the Top layer, so a panel the user just asked for would open behind
        // the video they were watching and read as a dead keystroke.
        WlrLayershell.layer: WlrLayer.Overlay

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
        // Nothing to pop up about while the list is open: the toast landed on
        // top of the very same notification in the centre underneath it, so the
        // one arrival was shown twice and each copy hid half of the other.
        visible: root.activeToasts.length > 0 && !Toggles.notifCenterOpen

        Column {
            id: toastColumn
            width: parent.width
            spacing: 8

            Repeater {
                // ScriptModel, not the array. dismissToast() rebuilds the
                // array, and a Repeater bound to one destroys every delegate
                // when its identity changes. That replayed the entry animation
                // on all the surviving toasts, and — worse — the recreated
                // delegate for the leaving toast was born with `leaving`
                // already true, so onLeavingChanged never fired and the exit
                // animation had never once played.
                model: ScriptModel {
                    values: root.activeToasts
                    objectProp: "id"
                }
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
                    // A toast can be created already leaving if it is
                    // dismissed within a frame of arriving; onLeavingChanged
                    // does not fire for a value present at construction.
                    Component.onCompleted: {
                        if (toastDelegate.leaving) exitAnim.start();
                        else entryAnim.start();
                    }
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
                            color: Notifs.accentFor(toastDelegate.urgency)
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
                                accent: Notifs.accentFor(toastDelegate.urgency)
                            }

                            Column {
                                width: toastContent.width - 32 - toastContent.spacing - 12
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: toastDelegate.summary
                                    color: Notifs.accentFor(toastDelegate.urgency)
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
}
