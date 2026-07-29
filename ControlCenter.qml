import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth

Item {
    id: root

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    property var wifiDevice: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi) return d;
        }
        return null;
    }

    readonly property bool btEnabled: Bluetooth.defaultAdapter !== null
        && Bluetooth.defaultAdapter.enabled

    readonly property var quickLaunchIds: [
        "dev.yorushi.MihomoGui",
        "org.pulseaudio.pavucontrol",
        "org.gnome.Nautilus",
        "kitty"
    ]

    readonly property var quickLaunch: {
        // byId() registers no dependency, so the model is touched here to make
        // this binding re-run once the async scan has finished.
        const _ = DesktopEntries.applications.values.length;
        const out = [];
        for (const id of root.quickLaunchIds) {
            const entry = DesktopEntries.byId(id);
            if (entry) out.push(entry);
        }
        return out;
    }

    // Expandable section: which sub-panel (if any) is showing its device/
    // network list instead of just the on/off toggle.
    property string expanded: "" // "wifi" | "bluetooth" | ""


    PanelWindow {
        id: win
        // Mapping is driven by an explicit bool, never bound to
        // Toggles.controlCenterOpen directly. A binding like
        // `visible: open || hideDelay.running` races: when open flips false
        // the visible binding can re-evaluate BEFORE the Connections handler
        // restarts the timer, so the window unmaps instantly and the exit
        // animation never plays (the "jerky hide"). Here `mapped` only ever
        // changes by assignment — true on open, false when the close timer
        // fires — so the panel stays mapped for the whole fade.
        property bool mapped: false
        visible: mapped
        // Full-screen rather than card-sized: without a backdrop there was no
        // click-outside-to-close, so the only ways out were the ✕ and the
        // keybind that opened it.
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusiveZone: 0
        focusable: Toggles.controlCenterOpen

        readonly property int cardWidth: 320
        // 36 top inset (clears the close button) + 16 bottom, plus slack —
        // budgeting only 40 total clipped the power-button row.
        readonly property int cardHeight: Math.min(Screen.height - Theme.barHeight - 60,
            chrome.implicitContentHeight + 64)

        // Slightly longer than the exit animation so the unmap lands just
        // after the fade finishes, never mid-fade.
        Timer {
            id: hideDelay
            interval: Theme.animExit + 40
            onTriggered: win.mapped = false
        }
        Connections {
            target: Toggles
            function onControlCenterOpenChanged() {
                if (Toggles.controlCenterOpen) {
                    hideDelay.stop();
                    win.mapped = true;
                    Brightness.refresh();
                } else {
                    hideDelay.restart();
                }
            }
        }
        Component.onCompleted: win.mapped = Toggles.controlCenterOpen

        MouseArea {
            anchors.fill: parent
            onClicked: Toggles.controlCenterOpen = false
        }

        Item {
            anchors.fill: parent
            focus: Toggles.controlCenterOpen
            Keys.onEscapePressed: Toggles.controlCenterOpen = false

            PanelChrome {
                id: chrome
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
                anchors.rightMargin: Theme.barMargin
                width: win.cardWidth
                height: win.cardHeight
                screenX: Screen.width - Theme.barMargin - win.cardWidth
                screenY: Theme.barHeight + Theme.barMargin * 2
                opacity: Toggles.controlCenterOpen ? 1 : 0
                scale: Toggles.controlCenterOpen ? 1 : 0.9
                transformOrigin: Item.TopRight
                // Duration/easing depend on direction: the open state's value
                // is already latched by the time the Behavior fires, so this
                // reads "arriving" vs "leaving" correctly. Open punches in
                // (bigger spring, longer); exit accelerates cleanly to 0.
                Behavior on opacity {
                    NumberAnimation {
                        duration: Toggles.controlCenterOpen ? Theme.animSlow : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Toggles.controlCenterOpen ? Theme.easeEmphasized : Theme.easeExit
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Toggles.controlCenterOpen ? Theme.animSlow : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Toggles.controlCenterOpen ? Theme.easeSpringBig : Theme.easeExit
                    }
                }
                onCloseRequested: Toggles.controlCenterOpen = false

                property alias implicitContentHeight: content.implicitHeight

                // Swallows clicks so the backdrop doesn't treat a click on the
                // panel itself as "outside".
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.topMargin: 36
                    contentHeight: content.implicitHeight
                    clip: true

                    Column {
                        id: content
                        width: parent.width
                        spacing: 16

                        SliderRow {
                            width: parent.width
                            label: "Громкость"
                            value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
                            onMoved: v => {
                                if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                    Pipewire.defaultAudioSink.audio.volume = v;
                                }
                            }
                            opacity: Toggles.controlCenterOpen ? 1 : 0
                            scale: Toggles.controlCenterOpen ? 1 : 0.92
                            transformOrigin: Item.Top
                            Behavior on opacity {
                                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                            }
                            Behavior on scale {
                                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                            }
                        }

                        SliderRow {
                            id: brightnessSlider
                            width: parent.width
                            label: "Яркость"
                            // Bound, not assigned: the singleton is updated by
                            // the Fn keys too, and this has to follow.
                            value: Brightness.value
                            onMoved: v => Brightness.set(v)
                            opacity: Toggles.controlCenterOpen ? 1 : 0
                            scale: Toggles.controlCenterOpen ? 1 : 0.92
                            transformOrigin: Item.Top
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: 40 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                                }
                            }
                            Behavior on scale {
                                SequentialAnimation {
                                    PauseAnimation { duration: 40 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                                }
                            }
                        }

                        // ── Wi-Fi ──
                        Column {
                            width: parent.width
                            spacing: 6
                            opacity: Toggles.controlCenterOpen ? 1 : 0
                            scale: Toggles.controlCenterOpen ? 1 : 0.92
                            transformOrigin: Item.Top
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: 80 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                                }
                            }
                            Behavior on scale {
                                SequentialAnimation {
                                    PauseAnimation { duration: 80 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                                }
                            }

                            ToggleRow {
                                width: parent.width
                                glyph: Glyphs.wifi
                                label: "Wi-Fi"
                                detail: root.wifiDevice && root.wifiDevice.connected ? "подключено" : ""
                                active: Networking.wifiEnabled
                                expanded: root.expanded === "wifi"
                                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                                onExpandRequested: {
                                    root.expanded = root.expanded === "wifi" ? "" : "wifi";
                                    // Scanning only on expand, never on a timer: a
                                    // periodic rescan stalls this card's link.
                                    if (root.expanded === "wifi" && root.wifiDevice) root.wifiDevice.scan();
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 4
                                visible: root.expanded === "wifi" && root.wifiDevice
                                Repeater {
                                    model: root.expanded === "wifi" && root.wifiDevice ? root.wifiDevice.networks : []
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 34
                                        radius: 17
                                        color: modelData.connected ? Theme.surface1 : Theme.surface0

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name + (modelData.connected ? " ✓" : "") + `  ${Math.round(modelData.signalStrength)}%`
                                            color: Theme.text
                                            font.pixelSize: 11
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                                        }
                                    }
                                }
                            }
                        }

                        // ── Bluetooth ──
                        Column {
                            width: parent.width
                            spacing: 6
                            opacity: Toggles.controlCenterOpen ? 1 : 0
                            scale: Toggles.controlCenterOpen ? 1 : 0.92
                            transformOrigin: Item.Top
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: 120 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                                }
                            }
                            Behavior on scale {
                                SequentialAnimation {
                                    PauseAnimation { duration: 120 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                                }
                            }

                            ToggleRow {
                                width: parent.width
                                glyph: root.btEnabled ? Glyphs.bluetooth : Glyphs.bluetoothOff
                                label: "Bluetooth"
                                active: root.btEnabled
                                expanded: root.expanded === "bluetooth"
                                onToggled: {
                                    if (Bluetooth.defaultAdapter) {
                                        Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                                    }
                                }
                                onExpandRequested: root.expanded = root.expanded === "bluetooth" ? "" : "bluetooth"
                            }

                            Column {
                                width: parent.width
                                spacing: 4
                                visible: root.expanded === "bluetooth"
                                Repeater {
                                    model: root.expanded === "bluetooth" ? Bluetooth.devices : []
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 34
                                        radius: 17
                                        color: modelData.connected ? Theme.surface1 : Theme.surface0

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (modelData.name || modelData.deviceName) + (modelData.connected ? " ✓" : "")
                                            color: Theme.text
                                            font.pixelSize: 11
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                                        }
                                    }
                                }
                            }
                        }

                        // ── Power profile ──
                        // The only place in the shell this can be changed
                        // besides the battery's right-click menu; profiles come
                        // from power-profiles-daemon rather than a fixed list,
                        // since which exist depends on the platform driver.
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: Power.available
                            opacity: Toggles.controlCenterOpen ? 1 : 0
                            scale: Toggles.controlCenterOpen ? 1 : 0.92
                            transformOrigin: Item.Top
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: 140 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                                }
                            }
                            Behavior on scale {
                                SequentialAnimation {
                                    PauseAnimation { duration: 140 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                                }
                            }

                            Text {
                                text: "Профиль питания"
                                color: Theme.subtext1
                                font.pixelSize: 11
                            }

                            Row {
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: Power.profiles
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: (content.width - (Power.profiles.length - 1) * 8) / Math.max(1, Power.profiles.length)
                                        height: 34
                                        radius: 17
                                        color: Power.activeProfile === modelData
                                            ? Theme.accent
                                            : (profileMa.containsMouse ? Theme.surface1 : Theme.surface0)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        scale: profileMa.pressed ? 0.94 : 1.0
                                        Behavior on scale {
                                            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: Power.glyphFor(modelData)
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: 12
                                                color: Power.activeProfile === modelData ? Theme.crust : Theme.text
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: Power.labelFor(modelData)
                                                color: Power.activeProfile === modelData ? Theme.crust : Theme.text
                                                font.pixelSize: 10
                                            }
                                        }

                                        MouseArea {
                                            id: profileMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Power.setProfile(modelData)
                                        }
                                    }
                                }
                            }
                        }

                        // ── Video wallpaper ──
                        // Only meaningful when the current wallpaper is a video;
                        // playback is otherwise stopped anyway.
                        ToggleRow {
                            width: parent.width
                            visible: Wallpaper.isVideo
                            glyph: Glyphs.video
                            label: "Пауза видео на батарее"
                            detail: Wallpaper.videoPaused ? "сейчас на паузе" : ""
                            active: Wallpaper.pauseOnBattery
                            expandable: false
                            onToggled: Wallpaper.pauseOnBattery = !Wallpaper.pauseOnBattery
                            opacity: Toggles.controlCenterOpen ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                            }
                        }

                        // ── System load ──
                        // Mirrors the desktop stats so the numbers are reachable
                        // even with windows covering the desktop.
                        Row {
                            width: parent.width
                            spacing: 10
                            opacity: Toggles.controlCenterOpen ? 1 : 0
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: 180 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                                }
                            }

                            StatChip {
                                width: (content.width - 20) / 3
                                glyph: Glyphs.cpu
                                label: Math.round(SysInfo.cpu * 100) + "%"
                                level: SysInfo.cpu
                            }
                            StatChip {
                                width: (content.width - 20) / 3
                                glyph: Glyphs.memory
                                label: Math.round(SysInfo.memory * 100) + "%"
                                level: SysInfo.memory
                            }
                            StatChip {
                                width: (content.width - 20) / 3
                                glyph: Glyphs.thermometer
                                label: SysInfo.temperature > 0 ? SysInfo.temperature + "°" : "--"
                                level: Math.max(0, Math.min(1, (SysInfo.temperature - 40) / 50))
                            }
                        }

                        // ── Quick launch ──
                        // Entries resolved through DesktopEntries so the real
                        // Exec line is used and anything not installed simply
                        // does not appear.
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.quickLaunch.length > 0
                            opacity: Toggles.controlCenterOpen ? 1 : 0
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: 200 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                                }
                            }

                            Text {
                                text: "Приложения"
                                color: Theme.subtext1
                                font.pixelSize: 11
                            }

                            Flow {
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: root.quickLaunch
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: appLabel.implicitWidth + 34
                                        height: 32
                                        radius: 16
                                        color: appMa.containsMouse ? Theme.surface1 : Theme.surface0
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        scale: appMa.pressed ? 0.94 : 1.0
                                        Behavior on scale {
                                            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Item {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 16
                                                height: 16

                                                Image {
                                                    id: appIcon
                                                    anchors.fill: parent
                                                    source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                                                    sourceSize.width: 32
                                                    sourceSize.height: 32
                                                    asynchronous: true
                                                    visible: status === Image.Ready
                                                }
                                                // Themes don't carry every icon
                                                // an app asks for (mihomo wants
                                                // network-vpn-symbolic), which
                                                // otherwise leaves a blank gap.
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: !appIcon.visible
                                                    text: Glyphs.apps
                                                    font.family: "Symbols Nerd Font"
                                                    font.pixelSize: 13
                                                    color: Theme.subtext1
                                                }
                                            }
                                            Text {
                                                id: appLabel
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.name
                                                color: Theme.text
                                                font.pixelSize: 11
                                            }
                                        }

                                        MouseArea {
                                            id: appMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Quickshell.execDetached(modelData.command);
                                                Toggles.controlCenterOpen = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 8
                            opacity: Toggles.controlCenterOpen ? 1 : 0
                            scale: Toggles.controlCenterOpen ? 1 : 0.92
                            transformOrigin: Item.Top
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: 160 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                                }
                            }
                            Behavior on scale {
                                SequentialAnimation {
                                    PauseAnimation { duration: 160 }
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                                }
                            }

                            Repeater {
                                model: [
                                    { label: "Блок", glyph: Glyphs.lock, act: () => Power.lock() },
                                    { label: "Сон", glyph: Glyphs.sleep, act: () => Power.suspend() },
                                    { label: "Рестарт", glyph: Glyphs.restart, act: () => Power.reboot() },
                                    { label: "Выкл", glyph: Glyphs.power, act: () => Power.powerOff(), danger: true }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: (content.width - 24) / 4
                                    height: 36
                                    radius: 18
                                    // Power off tints red on hover — the one
                                    // destructive action stands apart.
                                    color: powerMouseArea.containsMouse
                                        ? (modelData.danger ? Theme.red : Theme.surface1)
                                        : Theme.surface0
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    scale: powerMouseArea.pressed ? 0.9 : (powerMouseArea.containsMouse ? 1.08 : 1.0)
                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.glyph
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: 13
                                            color: Theme.text
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.label
                                            color: Theme.text
                                            font.pixelSize: 9
                                        }
                                    }

                                    Ripple {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        rippleColor: modelData.danger ? Theme.red : Theme.accent
                                    }

                                    MouseArea {
                                        id: powerMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Toggles.controlCenterOpen = false;
                                            modelData.act();
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
