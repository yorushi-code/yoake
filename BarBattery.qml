import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery readout, and the entry point for power profiles and session
// actions — the right-click menu is the only place in the shell where the
// power profile can be changed at all.
Item {
    id: root

    property var barWindow: null
    // Scoped to the output so the same widget on a second monitor
    // does not share one open-menu key with this one.
    readonly property string menuId: Menus.idFor(root.barWindow, "battery")

    visible: UPower.displayDevice.isLaptopBattery
        // implicitWidth off the row's *implicit* width, and the row anchored
    // rather than centred: reading .width here while the row centres itself
    // in that same width is a cycle, and Qt resolves it in no fixed order.
    // Whenever the content changed width -- VPN going from "вкл" to a speed,
    // volume from 50%% to 100%% -- the row sat off-centre inside the old width
    // for a frame, which is the clipped percentage at the island's edge.
    implicitWidth: visible ? batRow.implicitWidth : 0
    width: implicitWidth
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    readonly property var device: UPower.displayDevice
    readonly property bool charging: device.state === UPowerDeviceState.Charging
    readonly property real fraction: device.percentage
    readonly property bool low: !charging && fraction <= 0.15

    // UPower reports the estimate in seconds; it is zero while the estimate is
    // still settling, which is why it is only shown once non-zero.
    readonly property string remaining: {
        const secs = root.charging ? root.device.timeToFull : root.device.timeToEmpty;
        if (!secs || secs <= 0) return "";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h > 0 ? `${h} ч ${m} мин` : `${m} мин`;
    }

    Row {
        id: batRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapTight

        BarIcon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            glyph: root.low ? Glyphs.batteryAlert : Glyphs.batteryFor(root.fraction, root.charging)
            color: root.low ? Theme.red : (root.charging ? Theme.green : Theme.accent)
            // The ring is the charge: at a glance the shape says how full it is
            // without reading the number beside it.
            progress: root.fraction
            ringColor: root.low ? Theme.red : (root.charging ? Theme.green : Theme.accent)
            hovered: ma.containsMouse

            SequentialAnimation on opacity {
                running: root.low
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.low ? Theme.red : (root.charging ? Theme.green : Theme.text)
            font.pixelSize: 11
            text: Math.round(root.fraction * 100) + "%"
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            Power.refresh();
            Menus.toggle(root.menuId);
        }
    }

    ActionMenu {
        id: menu
        menuId: root.menuId
        anchorItem: root
        open: Menus.isOpen(root.menuId)
        model: {
            if (!Menus.isOpen(root.menuId)) return [];
            const out = [];
            for (const p of Power.profiles) {
                out.push({
                    text: Power.labelFor(p),
                    glyph: Power.glyphFor(p),
                    checkable: true,
                    checked: Power.activeProfile === p,
                    action: () => Power.setProfile(p)
                });
            }
            out.push({ separator: true });
            out.push({ text: "Заблокировать", glyph: Glyphs.lock, action: () => Power.lock() });
            out.push({ text: "Спящий режим", glyph: Glyphs.sleep, action: () => Power.suspend() });
            out.push({ text: "Перезагрузка", glyph: Glyphs.restart, action: () => Power.reboot() });
            out.push({ text: "Выключение", glyph: Glyphs.power, destructive: true, action: () => Power.powerOff() });
            return out;
        }
    }

    // Replaces the plain tooltip. A tooltip can carry two lines of text; this
    // holds the charge estimate and the three power profiles as buttons, so
    // switching profile no longer requires knowing that right-click exists.
    Popover {
        anchorItem: root
        hovered: ma.containsMouse && !Menus.isOpen(root.menuId)
        minWidth: 236

        Column {
            spacing: Theme.gapWide

            Row {
                spacing: Theme.gapWide

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.low ? Glyphs.batteryAlert
                        : Glyphs.batteryFor(root.fraction, root.charging)
                    font.family: Theme.fontIconFamily
                    font.pixelSize: 17
                    color: root.low ? Theme.red : (root.charging ? Theme.green : Theme.accent)
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: Math.round(root.fraction * 100) + "% · "
                            + (root.charging ? "заряжается" : "от батареи")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.Medium
                    }

                    Text {
                        visible: root.remaining !== ""
                        text: root.charging
                            ? "до полного " + root.remaining
                            : "осталось " + root.remaining
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                    }
                }
            }

            Rectangle {
                width: 210
                height: 1
                color: Qt.alpha(Theme.text, Theme.fillHover)
                visible: Power.available
            }

            Row {
                spacing: Theme.spacing
                visible: Power.available

                Repeater {
                    model: Power.profiles

                    delegate: Rectangle {
                        id: chip
                        required property var modelData

                        readonly property bool current: Power.activeProfile === chip.modelData
                        width: 68
                        height: 30
                        radius: Theme.radius + 3
                        color: chip.current ? Qt.alpha(Theme.accent, 0.9)
                            : (chipArea.containsMouse ? Qt.alpha(Theme.text, Theme.fillHover)
                                                      : Qt.alpha(Theme.text, 0.07))
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Power.glyphFor(chip.modelData)
                                font.family: Theme.fontIconFamily
                                font.pixelSize: 13
                                color: chip.current ? Theme.crust : Theme.subtext1
                            }
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Power.setProfile(chip.modelData)
                        }

                        Tooltip {
                            anchorItem: chip
                            active: chipArea.containsMouse
                            text: Power.labelFor(chip.modelData)
                        }
                    }
                }
            }
        }
    }
}
