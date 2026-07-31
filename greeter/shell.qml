//@ pragma UseQApplication
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// The login screen.
//
// Built to be the lock screen's twin, because they are the same moment seen
// from two sides — same blurred wallpaper, same rolling clock, same field. A
// machine that greets you one way at boot and another way after a lock is a
// machine assembled out of parts.
//
// It runs inside cage, which is a kiosk compositor with no layer shell, so
// this is an ordinary toplevel that cage fullscreens rather than a panel.
ShellRoot {
    id: root

    // Filled from /etc/passwd. Hardcoding the account would make the greeter
    // wrong on the first machine it is copied to, and the file is the only
    // thing that actually knows.
    property var users: []
    property int userIndex: 0
    readonly property string currentUser:
        root.userIndex < root.users.length ? root.users[root.userIndex].name : ""
    readonly property string currentLabel:
        root.userIndex < root.users.length ? root.users[root.userIndex].label : ""

    property string session: "niri-session"

    property string entry: ""
    property string message: ""
    property bool busy: false
    // Set between createSession and the password prompt arriving. Typing into
    // a field greetd has not asked to fill yet loses the keystrokes.
    property bool ready: false

    signal shake()

    FileView {
        path: "/etc/passwd"
        onLoaded: {
            const found = [];
            for (const line of text().split("\n")) {
                const f = line.split(":");
                if (f.length < 7) continue;
                const uid = parseInt(f[2]);
                // Real people only: the system accounts below 1000, nobody at
                // the top of the range, and anything parked on a nologin shell
                // are all things you cannot log in as.
                if (!(uid >= 1000 && uid < 60000)) continue;
                if (f[6].indexOf("nologin") >= 0 || f[6].indexOf("/false") >= 0) continue;
                if (f[0] === "greeter") continue;
                // GECOS carries a full name on machines that were set up with
                // one; the account name is the fallback, not the label.
                const gecos = (f[4] || "").split(",")[0].trim();
                found.push({ name: f[0], label: gecos !== "" ? gecos : f[0] });
            }
            root.users = found;
        }
    }

    FileView {
        path: "/etc/greetd/environments"
        onLoaded: {
            const first = text().split("\n").map(s => s.trim()).filter(s => s !== "")[0];
            if (first) root.session = first;
        }
    }

    function begin() {
        if (root.currentUser === "") return;
        root.ready = false;
        Greetd.createSession(root.currentUser);
    }

    function submit() {
        if (root.busy || !root.ready || root.entry === "") return;
        root.busy = true;
        root.message = "";
        Greetd.respond(root.entry);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (error) {
                root.message = message;
                return;
            }
            if (responseRequired) {
                root.ready = true;
                root.busy = false;
            } else {
                // PAM messages that want no answer still have to be answered,
                // or the conversation stalls with the screen looking idle.
                Greetd.respond("");
            }
        }

        function onAuthFailure(message) {
            root.busy = false;
            root.ready = false;
            root.entry = "";
            root.message = message || "Неверный пароль";
            root.shake();
            // greetd discards the session on failure, so the next attempt needs
            // a fresh one rather than another respond().
            begin.restart();
        }

        function onReadyToLaunch() {
            root.busy = true;
            root.message = "";
            Greetd.launch([root.session]);
        }

        function onError(err) {
            root.busy = false;
            root.message = err;
            begin.restart();
        }
    }

    // Nothing starts until the account list has been read -- and then it keeps
    // asking. Greetd.available is a constant property read once at startup, and
    // the socket connects asynchronously: a single attempt fired the instant
    // /etc/passwd parsed found `available` still false and gave up silently,
    // which is a login screen that never asks for a password.
    onUsersChanged: if (root.users.length > 0) begin.restart();

    Timer {
        id: begin
        interval: 200
        repeat: true
        property int tries: 0
        onTriggered: {
            if (root.ready || root.busy) {
                begin.stop();
                begin.tries = 0;
                return;
            }
            root.begin();
            begin.tries++;
            if (begin.tries > 25) begin.stop();
        }
    }

    Process {
        id: power
        running: false
    }

    // Nothing is built until a screen exists.
    //
    // cage brings its output up after the client connects, and Qt logged "There
    // are no outputs - creating placeholder screen": the window was made
    // against a screen that was not the display, which is why the login screen
    // did not work on the real machine while it rendered fine nested inside a
    // session that already had one.
    // Latched: once a screen has appeared the window stays, whatever happens to
    // the output afterwards. Switching to another VT and back takes cage's
    // output away and brings it back, and a Loader bound straight to the screen
    // count tore the whole login screen down on the way out -- which is how a
    // greeter that was working ended up handing over to the fallback.
    property bool sawScreen: false
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (Quickshell.screens.length > 0) root.sawScreen = true;
        }
    }
    Component.onCompleted: if (Quickshell.screens.length > 0) root.sawScreen = true;

    Loader {
        active: root.sawScreen
        sourceComponent: greeterWindow
    }

    Component {
    id: greeterWindow
    FloatingWindow {
        id: win
        color: "black"
        visible: true

        // Entrance is bound to this rather than to visibility, because the
        // window is created already shown and an animation bound to that would
        // have nothing to animate from.
        property bool entered: false
        Component.onCompleted: enterTick.start()
        Timer {
            id: enterTick
            interval: 16
            onTriggered: win.entered = true
        }

        // The wallpaper snapshot, already blurred by yshell-greeter-sync. Doing
        // it here needed a MultiEffect over a hidden source, which rendered
        // nothing and left the login screen a flat void -- and the picture only
        // changes when the sync runs, so there was never a reason to redo the
        // work at every login.
        Image {
            anchors.fill: parent
            source: "file://" + Theme.assetDir + "/wallpaper.jpg"
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: true

            // Slow drift, so a still image does not read as a frozen screen.
            scale: win.entered ? 1.04 : 1.10
            Behavior on scale {
                NumberAnimation { duration: 1800; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Theme.crust, 0.42) }
                GradientStop { position: 0.55; color: Qt.alpha(Theme.crust, 0.62) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, 0.86) }
            }
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
            enabled: true
        }

        // ── Hero clock ──
        Column {
            id: hero
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.20
            spacing: 2
            opacity: win.entered ? 1 : 0
            transform: Translate { y: win.entered ? 0 : 26 }
            Behavior on opacity { NumberAnimation { duration: 620; easing.type: Easing.OutCubic } }

            RollClock {
                anchors.horizontalCenter: parent.horizontalCenter
                hours: clock.date.getHours()
                minutes: clock.date.getMinutes()
                pixelSize: 132
                weight: Font.Medium
                tracking: -6
                groupGap: 10
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const d = clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM");
                    return d.charAt(0).toUpperCase() + d.slice(1);
                }
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Medium
                font.letterSpacing: 0.4
            }
        }

        // ── Authentication ──
        Column {
            id: auth
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: hero.bottom
            anchors.topMargin: 52
            spacing: 14
            opacity: win.entered ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 140 }
                    NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                id: avatar
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72
                height: 72
                radius: 36
                color: Qt.alpha(Theme.text, 0.08)
                border.width: 2
                border.color: Qt.alpha(Theme.accent, root.busy ? 0.9 : 0.35)
                Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

                Text {
                    anchors.centerIn: parent
                    text: (root.currentLabel || "y").charAt(0).toUpperCase()
                    color: Theme.accent
                    font.family: Theme.fontDisplayFamily
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }

                // Sweeps while PAM is thinking. The only moving thing on screen
                // then, so it carries the whole "working" signal.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -6
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    opacity: root.busy ? 0.55 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    RotationAnimation on rotation {
                        running: root.busy
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1500
                    }
                }

                // Cycles accounts where there is more than one. Hidden on a
                // single-user machine, which is every machine this will ever
                // run on until it isn't.
                MouseArea {
                    anchors.fill: parent
                    enabled: root.users.length > 1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.userIndex = (root.userIndex + 1) % root.users.length;
                        root.entry = "";
                        root.message = "";
                        if (Greetd.available) Greetd.cancelSession();
                        root.begin();
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.currentLabel
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLead
                font.weight: Font.Medium
            }

            // ── Password field ──
            Item {
                id: fieldHost
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                height: 46

                property real shakeOffset: 0
                transform: Translate { x: fieldHost.shakeOffset }

                SequentialAnimation {
                    id: shakeAnim
                    loops: 2
                    NumberAnimation { target: fieldHost; property: "shakeOffset"; to: -9; duration: 55 }
                    NumberAnimation { target: fieldHost; property: "shakeOffset"; to: 9; duration: 55 }
                    NumberAnimation { target: fieldHost; property: "shakeOffset"; to: 0; duration: 55 }
                }

                Connections {
                    target: root
                    function onShake() { shakeAnim.restart(); }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.alpha(Theme.crust, 0.55)
                    border.width: 1.5
                    border.color: root.message !== ""
                        ? Theme.red
                        : (input.activeFocus ? Qt.alpha(Theme.accent, 0.85) : Qt.alpha(Theme.text, 0.18))
                    Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

                    // Dots, drawn rather than echoed: a TextInput in password
                    // mode uses the font's bullet, which at this size sits low
                    // and unevenly spaced.
                    Row {
                        anchors.centerIn: parent
                        spacing: 9
                        visible: root.entry.length > 0

                        Repeater {
                            model: Math.min(root.entry.length, 16)
                            delegate: Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: Theme.text
                                opacity: 0.9
                                Component.onCompleted: popIn.start()
                                NumberAnimation {
                                    id: popIn
                                    target: parent
                                    property: "scale"
                                    from: 0.2
                                    to: 1
                                    duration: 180
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.entry.length === 0
                        text: "Пароль"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }

                    // Invisible, and the only thing with focus: it exists to
                    // collect keystrokes, never to draw.
                    TextInput {
                        id: input
                        anchors.fill: parent
                        opacity: 0
                        focus: true
                        enabled: !root.busy
                        echoMode: TextInput.Password
                        onTextChanged: root.entry = text
                        onAccepted: root.submit()

                        Connections {
                            target: root
                            function onEntryChanged() {
                                if (input.text !== root.entry) input.text = root.entry;
                            }
                        }

                        Component.onCompleted: {
                            input.forceActiveFocus();
                            focusRetry.restart();
                        }

                        // Asked again until it sticks. Focus requested before
                        // the compositor has handed the window a keyboard goes
                        // nowhere, and a login screen that ignores typing is
                        // the worst failure this file has.
                        Timer {
                            id: focusRetry
                            interval: 60
                            repeat: true
                            property int tries: 0
                            onTriggered: {
                                input.forceActiveFocus();
                                focusRetry.tries++;
                                if (input.activeFocus || focusRetry.tries > 25) {
                                    focusRetry.stop();
                                    focusRetry.tries = 0;
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 16
                text: root.message
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                opacity: root.message !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            }
        }

        // ── Session ──
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: auth.bottom
            anchors.topMargin: 10
            text: root.session
            color: Qt.alpha(Theme.subtext0, 0.8)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.letterSpacing: 1.6
            opacity: win.entered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 900 } }
        }

        // ── Power ──
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 28
            spacing: 10
            opacity: win.entered ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 280 }
                    NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
                }
            }

            Repeater {
                model: [
                    // Nerd Font: power, restart, sleep.
                    { glyph: "\u{F0425}", args: ["systemctl", "poweroff"] },
                    { glyph: "\u{F0709}", args: ["systemctl", "reboot"] },
                    { glyph: "\u{F04B2}", args: ["systemctl", "suspend"] }
                ]

                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    width: 40
                    height: 40
                    radius: 20
                    color: btnHover.containsMouse
                        ? Qt.alpha(Theme.text, 0.14)
                        : Qt.alpha(Theme.text, 0.06)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    scale: btnHover.pressed ? 0.92 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: btn.modelData.glyph
                        font.family: Theme.fontIconFamily
                        font.pixelSize: 15
                        color: Theme.subtext1
                    }

                    MouseArea {
                        id: btnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            power.command = btn.modelData.args;
                            power.running = true;
                        }
                    }
                }
            }
        }

        // Asleep in the corner until somebody logs in. The screen is a clock
        // and a box for a password; this is the one thing on it that is not
        // asking you for something.
        Image {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 34
            anchors.bottomMargin: 30
            source: "file://" + Theme.assetDir + "/bongo-sleeping.png"
            sourceSize.width: 256
            sourceSize.height: 256
            width: 132
            height: 132
            fillMode: Image.PreserveAspectFit
            opacity: win.entered ? 0.5 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 420 }
                    NumberAnimation { duration: 900; easing.type: Easing.OutCubic }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 14
                text: "z"
                color: Qt.alpha(Theme.text, 0.7)
                font.family: Theme.fontFamily
                font.pixelSize: 14

                SequentialAnimation on y {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { from: 22; to: 2; duration: 2400; easing.type: Easing.InOutQuad }
                    PauseAnimation { duration: 500 }
                }
            }
        }

        // Wordmark, quiet, bottom centre.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26
            text: "yshell"
            color: Qt.alpha(Theme.text, 0.28)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.weight: Font.Medium
            font.letterSpacing: 3
            opacity: win.entered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 900 } }
        }

        // Visible only where greetd is not: running this file from a normal
        // session to check the layout is a thing that should say so rather than
        // silently look like a login screen that ignores the keyboard.
        Text {
            visible: !Greetd.available
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 52
            text: "greetd недоступен — предпросмотр"
            color: Theme.red
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
        }
    }
    }

}
