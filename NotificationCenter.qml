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
            leaving: false,
            // Carried on the entry so the card can show the time it has left.
            // A toast that disappears on a schedule nobody can see reads as the
            // shell losing it, and the one question anyone actually has while
            // reading one is how long they have.
            timeout: root.timeoutFor(notification),
            appName: notification.appName || "",
            // How many from this application are standing behind this card.
            stacked: 1
        };
        // Nothing to show and nothing to say — an application sending an empty
        // notification should not leave a blank card on screen.
        if (entry.summary === "" && entry.body === "") return;

        // One card per application, not per message.
        //
        // A chat that says nine things in a minute used to put nine cards on
        // screen, which is the shell repeating what the application already
        // did badly. The live card takes over the newest message and counts
        // the rest: the newest is the one anyone reads, and the count is the
        // only thing the older ones still contribute.
        //
        // The entry keeps its id, so the ScriptModel below diffs it as the
        // same row and the delegate survives -- the card is re-read, not
        // rebuilt, and its own timer and gestures carry on.
        if (entry.appName !== "") {
            for (const existing of root.activeToasts) {
                if (existing.leaving || existing.appName !== entry.appName) continue;
                if (existing.timer) existing.timer.restart();
                root.activeToasts = root.activeToasts.map(t => t === existing
                    ? Object.assign({}, t, {
                        notification: notification,
                        summary: entry.summary,
                        body: entry.body,
                        urgency: entry.urgency,
                        stacked: (t.stacked || 1) + 1
                    })
                    : t);
                return;
            }
        }

        const timer = toastTimerComponent.createObject(root, {
            key: entry.id, interval: entry.timeout
        });
        // Handed to the card so hovering can hold it. Stopping only the drawn
        // countdown while the real one ran underneath would make the card lie
        // about its own life and then vanish under the cursor mid-sentence.
        entry.timer = timer;
        activeToasts = [...activeToasts, entry];
        timer.start();
    }

    // Two steps: flag it so the delegate can play its exit, then drop it once
    // the animation has had time to run.
    //
    // Copied rather than rebuilt field by field: a literal here silently drops
    // whatever was added to the entry since it was written, and the field it
    // would drop is always the newest one, so the bug arrives with the feature.
    function dismissToast(notification) {
        for (const t of root.activeToasts) {
            if (t.notification === notification) {
                root.dismissKey(t.id);
                return;
            }
        }
    }

    // Dismissal is by card, and the countdown fires this rather than the one
    // above. Grouping is why: a card takes over the newest message, so the
    // notification a timer was created with stops being the one the card is
    // showing after the second message arrives -- and a timer that dismisses
    // "its" notification then matches no card at all. The symptom was a
    // grouped toast that never went away, with nothing in the log to say so.
    function dismissKey(key) {
        root.activeToasts = root.activeToasts.map(t => {
            if (t.id !== key) return t;
            // The countdown only destroyed itself when it fired. Every toast
            // dismissed by hand -- which is most of them -- left a stopped
            // Timer parented to this object for the life of the session.
            if (t.timer) {
                t.timer.stop();
                t.timer.destroy();
            }
            return Object.assign({}, t, { leaving: true, timer: null });
        });
        const reaper = toastReaperComponent.createObject(root, { key: key });
        reaper.start();
    }

    Component {
        id: toastTimerComponent
        Timer {
            // `var`, not `string`: the entry's id comes from the notification
            // and is a number, and declaring this a string converted it, so
            // `t.id !== key` compared 109 against "109" and matched nothing.
            // The countdown fired on time every time and dismissed a card that
            // did not exist, which is why the log was clean and the toast
            // stayed on screen forever.
            property var key
            // No destroy() here: dismissKey owns the countdown's lifetime now,
            // and it is reached on this path too.
            onTriggered: root.dismissKey(key)
        }
    }

    Component {
        id: toastReaperComponent
        Timer {
            // By card, for the same reason the countdown is: after grouping,
            // the notification an entry was created with is no longer the one
            // it is showing, and a reaper that filters by it removes nothing.
            property var key
            interval: Theme.animExit + 60
            onTriggered: {
                root.activeToasts = root.activeToasts.filter(t => t.id !== key);
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
        // Declared, or applications never offer it. A chat client asks the
        // server what it can do and sends a plain notification if the answer is
        // no, so this one line is the difference between a reply field existing
        // and the feature being invisible on both sides.
        inlineReplySupported: true

        onNotification: notification => {
            notification.tracked = true;
            // Retire the toast the moment the notification goes away, whoever
            // closed it. Without this the card outlives its own content.
            notification.closed.connect(() => root.dismissToast(notification));
            // Do-not-disturb suppresses the popup only; the notification is
            // still tracked, so nothing is lost from the history.
            if (!Notifs.quiet && !Media.announcesTrack(notification)) root.appendToast(notification);
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

    // ── Toasts: under the bell they belong to ──
    //
    // They were centred, and the comment that used to be here defended it: the
    // desktop rail had taken the right-hand edge, so a notification landed
    // across a 112px clock. That solved a collision by moving into the one
    // column that is never free -- the centre is where content is, and a toast
    // over the middle of the screen interrupts whatever is being read.
    //
    // A toast now arrives where its chip is, which is the rule every sheet in
    // this shell already follows: the bell sits at the right end of the strip,
    // so its cards come down under the right end of the strip.
    //
    // The rail can still be under them, and that is left alone deliberately.
    // The rail is a widget the user drags and its position is theirs; a toast
    // that dodged it would be guessing at a layout nobody asked it to know,
    // and the shell would be reaching across two unrelated surfaces to do it.
    // On a bare desktop a toast may cross the clock for six seconds. That is a
    // smaller cost than covering the middle of the screen every time.
    PanelWindow {
        // Overlay, not the default Top: niri draws a fullscreen window above
        // the Top layer, so a toast would otherwise appear behind whatever is
        // being watched and be an interruption nobody was shown.
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
        // On demand, not never and not exclusively.
        //
        // A reply field needs a keyboard, and a window that cannot be focused
        // has an unusable one -- but a toast that *takes* the keyboard on
        // arrival would eat the sentence you were typing when it appeared,
        // which is the worst thing a notification can do. On-demand focus is
        // exactly the middle: nothing happens until the field is clicked.
        focusable: true
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        // Nothing to pop up about while the list is open: the toast landed on
        // top of the very same notification in the centre underneath it, so the
        // one arrival was shown twice and each copy hid half of the other.
        visible: root.activeToasts.length > 0 && !Toggles.notifCenterOpen

        Column {
            id: toastColumn
            width: parent.width
            spacing: Theme.spacing

            // The stack closes ranks rather than snapping shut. Without it,
            // dismissing the top toast teleports every one below it up by a
            // card's height, which reads as the whole stack flickering.
            move: MotionMove {}

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
                    readonly property int stacked: modelData.stacked || 1
                    readonly property bool canReply: toastDelegate.notification
                        && toastDelegate.notification.hasInlineReply === true

                    width: toastColumn.width
                    height: toastChrome.height

                    // ── Time left, and swiping it away ──

                    // 1 when it arrives, 0 when it is due to go. Drawn by the
                    // urgency stripe, which is the one part of the card that
                    // already stands for this notification and nothing else —
                    // a second bar underneath would be a new element saying
                    // something the card can already say.
                    property real life: 1
                    NumberAnimation {
                        id: drain
                        target: toastDelegate
                        property: "life"
                        from: 1
                        to: 0
                        // Linear on purpose. This is the only thing in the
                        // shell that is a clock rather than a movement, and an
                        // eased clock is a lie about how much time is left.
                        duration: toastDelegate.modelData.timeout
                    }

                    // Reading takes as long as it takes. Hovering stops the
                    // clock, and leaving gives the notification its full life
                    // back rather than the remainder — a card you have just
                    // finished reading and moved away from is the one you are
                    // least likely to want two hundred milliseconds of.
                    property bool held: false
                    onHeldChanged: {
                        if (toastDelegate.held) {
                            drain.stop();
                            toastDelegate.life = 1;
                            if (toastDelegate.lifeTimer) toastDelegate.lifeTimer.stop();
                        } else if (!toastDelegate.leaving) {
                            drain.restart();
                            if (toastDelegate.lifeTimer) toastDelegate.lifeTimer.restart();
                        }
                    }
                    readonly property var lifeTimer: modelData.timer

                    // Thrown off the edge rather than dismissed in place. The
                    // exit animation below plays the other way — up, the way it
                    // came — and running both would be two departures.
                    property bool thrown: false
                    readonly property real swipe: Math.abs(toastDelegate.x) / toastDelegate.width
                    // Far enough that it cannot be reached by the wobble of a
                    // click, near enough that the gesture never feels like work.
                    readonly property real swipeCommit: 0.28

                    // Fixed at the moment of release. Left as a live expression
                    // on the animation's own `to`, it would keep re-reading the
                    // position it is currently animating.
                    property real throwTo: 0

                    ParallelAnimation {
                        id: throwOff
                        NumberAnimation {
                            target: toastDelegate; property: "x"
                            to: toastDelegate.throwTo
                            duration: Theme.animExit
                            easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeExit
                        }
                        NumberAnimation {
                            target: toastChrome; property: "opacity"; to: 0
                            duration: Theme.animExit
                        }
                        onFinished: root.dismissToast(toastDelegate.notification)
                    }

                    NumberAnimation {
                        id: settle
                        target: toastDelegate; property: "x"; to: 0
                        duration: Theme.animNormal
                        easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig
                    }

                    // Animates in on creation (Repeater delegates start
                    // already-parented, so this fires once on entry) with a
                    // slight overshoot for a "tactile" pop rather than a
                    // plain slide, staggered when several land at once.
                    opacity: 0
                    scale: Theme.revealScale
                    // Down from under the bar, now that they come from there —
                    // through a transform rather than through `y`, because the
                    // Column owns `y` and an animation writing it would be
                    // overwritten by the next layout pass. `x` was safe to
                    // animate for the same reason it is now wrong: a Column
                    // does not set it.
                    transform: Translate { id: drop; y: -28 }
                    // A toast can be created already leaving if it is
                    // dismissed within a frame of arriving; onLeavingChanged
                    // does not fire for a value present at construction.
                    Component.onCompleted: {
                        if (toastDelegate.leaving) {
                            exitAnim.start();
                        } else {
                            entryAnim.start();
                            drain.start();
                        }
                    }
                    // The travel is declared here rather than in `CascadeEntry`
                    // because only this list has one: a toast comes down from
                    // under the bar it belongs to. It runs inside the shared
                    // arrival, after the one wait, so the drop and the fade
                    // cannot come apart.
                    CascadeEntry {
                        id: entryAnim
                        item: toastDelegate
                        index: toastDelegate.index

                        NumberAnimation {
                            target: drop; property: "y"; to: 0
                            duration: Theme.animSlow
                            easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig
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
                            target: drop; property: "y"; to: -40
                            duration: Theme.animExit
                            easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeExit
                        }
                    }
                    onLeavingChanged: {
                        if (!toastDelegate.leaving) return;
                        drain.stop();
                        if (!toastDelegate.thrown) exitAnim.start();
                    }

                    PanelChrome {
                        id: toastChrome
                        width: parent.width
                        height: toastContent.height + 22
                        screenX: Screen.width - Theme.barMargin - toastColumn.width
                        screenY: Theme.barHeight + Theme.barMargin * 2 + toastDelegate.y
                        onCloseRequested: root.dismissToast(toastDelegate.notification)

                        // Fades as it is swiped, so the card is visibly on its
                        // way out before the gesture commits. Applied here
                        // rather than on the delegate, whose own opacity is
                        // driven by the entry and exit animations — a binding
                        // and an animation on one property is a binding that
                        // survives until the first frame of the animation.
                        opacity: 1 - Math.min(1, toastDelegate.swipe * 1.4)

                        // Urgency stripe: the only always-visible cue telling a
                        // critical alert apart from a routine one, and now also
                        // the clock. It drains from the bottom, so what is left
                        // is what is left.
                        Rectangle {
                            id: stripeTrack
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            width: 3
                            radius: width / 2
                            color: Qt.alpha(Notifs.accentFor(toastDelegate.urgency), Theme.fillActive)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: parent.height * toastDelegate.life
                                radius: parent.radius
                                color: Notifs.accentFor(toastDelegate.urgency)
                            }
                        }

                        // Click dismisses, drag throws. Both live on one hit
                        // area: a separate DragHandler would have to agree with
                        // this one about what counts as a click, and the two
                        // definitions drift.
                        MouseArea {
                            id: toastGrab
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor
                            drag.target: toastDelegate
                            drag.axis: Drag.XAxis
                            drag.threshold: 6
                            // The Column owns `y`; a horizontal drag is the only
                            // one that can be given to the layout's own item
                            // without the next layout pass undoing it.
                            drag.minimumX: -toastDelegate.width
                            drag.maximumX: toastDelegate.width

                            onEntered: toastDelegate.held = true
                            onExited: toastDelegate.held = false

                            onPressed: {
                                settle.stop();
                                toastDelegate.held = true;
                            }

                            onReleased: {
                                if (toastDelegate.swipe >= toastDelegate.swipeCommit) {
                                    toastDelegate.thrown = true;
                                    toastDelegate.throwTo = (toastDelegate.x >= 0 ? 1 : -1) * toastDelegate.width * 1.2;
                                    throwOff.restart();
                                } else if (toastDelegate.x !== 0) {
                                    settle.restart();
                                } else {
                                    // Never moved: an ordinary click, which
                                    // dismisses, as every other notification
                                    // daemon does.
                                    root.dismissToast(toastDelegate.notification);
                                }
                            }
                        }

                        Row {
                            id: toastContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 22
                            anchors.rightMargin: 12
                            anchors.topMargin: 11
                            spacing: Theme.gapWide

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

                                Row {
                                    // Short of the close button, which lives in
                                    // the card's own corner: a count tucked
                                    // under an X is a count nobody can read and
                                    // a button nobody can hit.
                                    width: parent.width - (counter.visible ? 24 : 0)
                                    spacing: Theme.spacing

                                    Text {
                                        width: parent.width - (counter.visible
                                            ? counter.width + Theme.spacing : 0)
                                        text: toastDelegate.summary
                                        color: Notifs.accentFor(toastDelegate.urgency)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontLead
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                    }

                                    // Beside the summary rather than in a
                                    // corner: the count is part of the sentence
                                    // "nine of these", and a badge somewhere
                                    // else is a second thing to find.
                                    Rectangle {
                                        id: counter
                                        anchors.top: parent.top
                                        visible: toastDelegate.stacked > 1
                                        width: Math.max(18, countText.implicitWidth + Theme.spacing)
                                        height: 18
                                        radius: Theme.pill(height)
                                        color: Qt.alpha(Notifs.accentFor(toastDelegate.urgency),
                                                        Theme.tintActive)

                                        Text {
                                            id: countText
                                            anchors.centerIn: parent
                                            text: "+" + (toastDelegate.stacked - 1)
                                            color: Notifs.accentFor(toastDelegate.urgency)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontMicro
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                                Text {
                                    width: parent.width
                                    visible: toastDelegate.body.length > 0
                                    text: toastDelegate.body
                                    textFormat: Text.StyledText
                                    color: Theme.text
                                    font.pixelSize: Theme.fontBody
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }

                                NotificationActions {
                                    width: parent.width
                                    notification: toastDelegate.notification
                                    onInvoked: root.dismissToast(toastDelegate.notification)
                                }

                                // Answering where you were asked.
                                //
                                // The alternative is raising the application,
                                // finding the conversation and typing there --
                                // which is most of a minute for a sentence, and
                                // the reason a reply field on a toast is the one
                                // notification feature people miss by name.
                                Rectangle {
                                    id: replyBox
                                    width: parent.width
                                    visible: toastDelegate.canReply
                                    height: visible ? 32 : 0
                                    radius: Theme.radiusChip
                                    color: Qt.alpha(Theme.text, Theme.fillMuted)

                                    TextInput {
                                        id: reply
                                        anchors.left: parent.left
                                        anchors.right: sendButton.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: Theme.rowPad
                                        anchors.rightMargin: Theme.spacing
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSmall
                                        clip: true

                                        function send() {
                                            if (reply.text === "") return;
                                            toastDelegate.notification.sendInlineReply(reply.text);
                                            reply.text = "";
                                            root.dismissToast(toastDelegate.notification);
                                        }

                                        onAccepted: reply.send()
                                        // Typing is reading: the countdown must
                                        // not run out mid-sentence, and the
                                        // hover hold does not cover a keyboard.
                                        onActiveFocusChanged: toastDelegate.held = reply.activeFocus

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: reply.text === ""
                                            text: toastDelegate.notification
                                                && toastDelegate.notification.inlineReplyPlaceholder
                                                ? toastDelegate.notification.inlineReplyPlaceholder
                                                : "Ответить"
                                            color: Theme.subtext0
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSmall
                                        }
                                    }

                                    Rectangle {
                                        id: sendButton
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.rightMargin: Theme.gapTight
                                        width: 24
                                        height: 24
                                        radius: Theme.pill(height)
                                        color: reply.text !== ""
                                            ? Notifs.accentFor(toastDelegate.urgency)
                                            : Qt.alpha(Theme.text, Theme.fillMuted)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            icon: Glyphs.upload
                                            size: Theme.fontIconMicro
                                            fill: 1
                                            color: reply.text !== "" ? Theme.crust : Theme.subtext0
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: reply.send()
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

