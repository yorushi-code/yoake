import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower

// The session lock.
//
// One surface per output, all driven by the single conversation in LockState.
// Nothing here talks to PAM: a lock that authenticated per surface would start
// one conversation per monitor and count a wrong password twice.
WlSessionLock {
    id: lock
    locked: LockState.locked

    WlSessionLockSurface {
        id: surface
        color: "black"

        // Entrance is bound to this rather than to `locked`, because the
        // surface is created with the lock already engaged and an animation
        // bound to the toggle would have nothing to animate from.
        property bool entered: false
        Component.onCompleted: enterTick.start()
        Timer {
            id: enterTick
            interval: 16
            onTriggered: surface.entered = true
        }

        // The sharp wallpaper, softened here rather than on disk. The panels'
        // pre-blurred copy is tuned for frosted glass — heavy enough that
        // nothing of the picture survives — which is right behind a bar island
        // and wrong across a whole screen, where the wallpaper should still be
        // recognisably itself.
        //
        // Affordable because this surface only exists while the session is
        // locked and nothing on it animates: Qt caches the layer and re-blurs
        // only when the minute changes.
        Image {
            id: canvas
            anchors.fill: parent
            source: Wallpaper.isVideo ? Wallpaper.stillPath : Wallpaper.path
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: surface.width
            sourceSize.height: surface.height
            cache: false
            asynchronous: true
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: canvas
            blurEnabled: true
            blur: 1.0
            blurMax: 40
            blurMultiplier: 0.6
            saturation: -0.12
            // Slow drift, so a still image does not read as a frozen screen.
            scale: surface.entered ? 1.05 : 1.12
            Behavior on scale {
                NumberAnimation { duration: Theme.animDrift; easing.type: Easing.OutCubic }
            }
        }

        // Darkened towards the bottom, where the type sits.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Theme.crust, Theme.veilSoft) }
                GradientStop { position: 0.55; color: Qt.alpha(Theme.crust, Theme.veilFirm) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, Theme.veilSolid) }
            }
        }

        // ── Hero clock ──
        SystemClock {
            id: clock
            // Minutes, not seconds: only HH:mm is drawn, and a per-second tick
            // would re-render the blurred backdrop sixty times for every change
            // anybody could see.
            precision: SystemClock.Minutes
            enabled: true
        }

        Column {
            id: hero
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            // Optical centring: the clock and the auth column together read as
            // one block, so the block is centred rather than the clock. At 0.18
            // the screen was top-heavy with a third of it empty underneath.
            anchors.topMargin: parent.height * 0.24
            spacing: 2
            opacity: surface.entered ? 1 : 0
            transform: Translate { y: surface.entered ? 0 : 26 }
            Behavior on opacity { NumberAnimation { duration: Theme.animEnter; easing.type: Easing.OutCubic } }

            RollClock {
                anchors.horizontalCenter: parent.horizontalCenter
                hours: clock.date.getHours()
                minutes: clock.date.getMinutes()
                pixelSize: 132
                weight: Font.Medium
                tracking: -6
                groupGap: 10
                // The minute arriving is the only thing that happens on a lock
                // screen. Rolling it is the difference between a screen that
                // shows the time and one that is keeping it.
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                // Through Lang, like every other date in the shell. This was
                // the first place the locale had to be passed by hand, and
                // passing it by hand is how the bar came to disagree with it.
                text: Lang.dateCapitalised(clock.date, "dddd, d MMMM")
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
            spacing: Theme.gapCard
            opacity: surface.entered ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: Theme.animFast }
                    NumberAnimation { duration: Theme.animEnter; easing.type: Easing.OutCubic }
                }
            }

            // Avatar. A glyph rather than a photo: there is no account picture
            // on this machine and a missing-image box would be worse than none.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72
                height: 72
                radius: Theme.pill(height)
                color: Qt.alpha(Theme.text, Theme.fillSubtle)
                border.width: 2
                border.color: Qt.alpha(Theme.accent, LockState.busy ? 0.9 : 0.35)
                Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

                Text {
                    anchors.centerIn: parent
                    text: (Quickshell.env("USER") || "y").charAt(0).toUpperCase()
                    color: Theme.accent
                    font.family: Theme.fontDisplayFamily
                    font.pixelSize: Theme.fontHeadline
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
                    opacity: LockState.busy ? 0.55 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    RotationAnimation on rotation {
                        running: LockState.busy
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: Theme.animDrift
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Quickshell.env("USER") || ""
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
                    NumberAnimation { target: fieldHost; property: "shakeOffset"; to: -9; duration: Theme.animTick }
                    NumberAnimation { target: fieldHost; property: "shakeOffset"; to: 9; duration: Theme.animTick }
                    NumberAnimation { target: fieldHost; property: "shakeOffset"; to: 0; duration: Theme.animTick }
                }

                Connections {
                    target: LockState
                    function onShake() { shakeAnim.restart(); }
                }

                Rectangle {
                    id: field
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.alpha(Theme.crust, Theme.veilFirm)
                    border.width: 1.5
                    border.color: LockState.failed
                        ? Theme.red
                        : (input.activeFocus ? Qt.alpha(Theme.accent, Theme.veilSolid) : Qt.alpha(Theme.text, Theme.strokeFirm))
                    Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

                    // Dots, drawn rather than echoed: a TextInput in password
                    // mode uses the font's bullet, which at this size sits low
                    // and unevenly spaced.
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.gapWide
                        visible: LockState.entry.length > 0

                        Repeater {
                            model: Math.min(LockState.entry.length, 16)
                            delegate: Rectangle {
                                width: 8
                                height: 8
                                radius: Theme.radiusPip
                                color: Theme.text
                                opacity: 0.9
                                scale: 1
                                Component.onCompleted: popIn.start()
                                NumberAnimation {
                                    id: popIn
                                    target: parent
                                    property: "scale"
                                    from: 0.2
                                    to: 1
                                    duration: Theme.animNormal
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: LockState.entry.length === 0
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
                        enabled: !LockState.busy
                        echoMode: TextInput.Password
                        onTextChanged: LockState.entry = text
                        onAccepted: LockState.submit()

                        Connections {
                            target: LockState
                            function onEntryChanged() {
                                if (input.text !== LockState.entry) input.text = LockState.entry;
                            }
                            // Focus is lost whenever the surface is rebuilt, and
                            // a lock screen that ignores the keyboard is the
                            // worst failure this file has.
                            function onLockedChanged() {
                                if (LockState.locked) input.forceActiveFocus();
                            }
                        }

                        Component.onCompleted: input.forceActiveFocus()
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 16
                text: LockState.message
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                opacity: LockState.message !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            }
        }

        // Asleep where the player would be, when there is no player.
        //
        // The greeter has one and this screen is meant to be its twin; having
        // it on one and not the other was a difference with no reason behind
        // it. It takes the corner the media card leaves empty rather than
        // sitting beside it, so neither surface ever shows a hole.
        Image {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 34
            anchors.bottomMargin: 26
            visible: !Media.hasPlayer
            source: Qt.resolvedUrl("assets/bongo/bongo-sleeping.png")
            sourceSize.width: 256
            sourceSize.height: 256
            width: 128
            height: 128
            fillMode: Image.PreserveAspectFit
            opacity: surface.entered ? 0.45 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: Theme.animSlow }
                    NumberAnimation { duration: Theme.animArrive; easing.type: Easing.OutCubic }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 12
                text: "z"
                color: Qt.alpha(Theme.text, Theme.inkSoft)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLead

                SequentialAnimation on y {
                    running: parent.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 22; to: 2; duration: Theme.animDoze; easing.type: Easing.InOutQuad }
                    PauseAnimation { duration: Theme.animBusy }
                }
            }
        }

        // ── Now playing ──
        Rectangle {
            id: mediaCard
            visible: Media.hasPlayer
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 32
            width: 300
            height: 72
            radius: Theme.radiusCard
            color: Qt.alpha(Theme.crust, Theme.veilSoft)
            border.width: 1
            border.color: Qt.alpha(Theme.text, Theme.fillMuted)
            opacity: surface.entered ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: Theme.animNormal }
                    NumberAnimation { duration: Theme.animEnter; easing.type: Easing.OutCubic }
                }
            }

            AlbumArt {
                id: art
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                width: 52
                height: 52
            }

            Column {
                anchors.left: art.right
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: Media.title || "—"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Media.artist || ""
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    elide: Text.ElideRight
                }
            }
        }

        // ── Status ──
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 32
            spacing: Theme.gapSection
            opacity: surface.entered ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: Theme.animNormal }
                    NumberAnimation { duration: Theme.animEnter; easing.type: Easing.OutCubic }
                }
            }

            Repeater {
                model: [
                    { glyph: Glyphs.bell, text: Notifs.count > 0 ? String(Notifs.count) : "",
                      show: Notifs.count > 0 },
                    { glyph: Glyphs.batteryFor(UPower.displayDevice.percentage,
                                               UPower.displayDevice.state === UPowerDeviceState.Charging),
                      text: Math.round(UPower.displayDevice.percentage * 100) + "%",
                      show: UPower.displayDevice.isLaptopBattery }
                ]

                delegate: Row {
                    id: chip
                    required property var modelData
                    visible: chip.modelData.show
                    spacing: Theme.spacing

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.glyph
                        font.family: Theme.fontIconFamily
                        font.pixelSize: Theme.fontIconSmall
                        color: Theme.subtext1
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.text
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }

        // Wordmark, quiet, bottom centre.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26
            text: "yoake"
            color: Qt.alpha(Theme.text, Theme.inkGhost)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.weight: Font.Medium
            font.letterSpacing: Theme.trackCaption
            opacity: surface.entered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animArrive } }
        }
    }
}
