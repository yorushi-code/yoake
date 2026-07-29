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
    width: visible ? batRow.width : 0
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
        anchors.centerIn: parent
        spacing: 5

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            font.family: "Symbols Nerd Font"
            font.pixelSize: 13
            color: root.low ? Theme.red : (root.charging ? Theme.green : Theme.accent)
            text: root.low ? Glyphs.batteryAlert : Glyphs.batteryFor(root.fraction, root.charging)
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }

            // Marks the moment the icon steps to a different level, which is
            // otherwise a change you only notice by chance.
            SequentialAnimation {
                id: pop
                NumberAnimation { target: glyph; property: "scale"; to: 1.25; duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { target: glyph; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
            }
            onTextChanged: pop.restart()

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

    Tooltip {
        anchorItem: root
        active: ma.containsMouse && !Menus.isOpen(root.menuId)
        text: root.charging ? "Заряжается" : "От батареи"
        subtext: root.remaining !== ""
            ? (root.charging ? "До полного: " + root.remaining : "Осталось: " + root.remaining)
            : "ПКМ — профиль питания"
    }
}
