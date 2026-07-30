import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

// The control centre's tiles.
//
// Kept apart from ControlCenter so that file is layout and window plumbing
// only: the previous version had every toggle, every device list and every
// animation inline across 675 lines, which is how a tile could be added only by
// editing the same block as the power buttons.
Grid {
    id: root

    // Which tile's page the pager should show, "" for none.
    signal pageRequested(string page)

    readonly property var wifiDevice: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi) return d;
        }
        return null;
    }
    // NetworkDevice.connected is a plain bool, so the SSID has to come from the
    // network list rather than from the device.
    readonly property string ssid: {
        if (!root.wifiDevice) return "";
        for (const n of root.wifiDevice.networks.values) {
            if (n.connected) return n.name;
        }
        return "";
    }
    readonly property bool btEnabled: Bluetooth.defaultAdapter !== null
        && Bluetooth.defaultAdapter.enabled

    columns: 2
    spacing: 8

    readonly property real cellWidth: (root.width - root.spacing) / 2

    CcTile {
        width: root.cellWidth
        glyph: Networking.wifiEnabled ? Glyphs.wifi : Glyphs.wifiOff
        label: "Wi-Fi"
        detail: !Networking.wifiEnabled
            ? "выключен"
            : (root.ssid !== "" ? root.ssid : "не подключено")
        active: Networking.wifiEnabled
        expandable: true
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        onPageRequested: root.pageRequested("wifi")
    }

    CcTile {
        width: root.cellWidth
        glyph: root.btEnabled ? Glyphs.bluetooth : Glyphs.bluetoothOff
        label: "Bluetooth"
        detail: root.btEnabled ? "включён" : "выключен"
        active: root.btEnabled
        expandable: true
        onToggled: {
            if (Bluetooth.defaultAdapter) {
                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
            }
        }
        onPageRequested: root.pageRequested("bluetooth")
    }

    CcTile {
        width: root.cellWidth
        glyph: Glyphs.vpn
        label: "VPN"
        detail: Mihomo.busy
            ? "подключение…"
            : (Mihomo.running ? (Mihomo.currentNode || Mihomo.active) : "отключён")
        active: Mihomo.running
        expandable: true
        // Toggling here is the tunnel itself; the chevron opens the full panel,
        // which is where nodes and subscriptions live.
        onToggled: Mihomo.running ? Mihomo.stop() : Mihomo.start()
        onPageRequested: Toggles.exclusive("vpnPanel")
    }

    CcTile {
        width: root.cellWidth
        glyph: Glyphs.image
        label: "Обои"
        detail: Wallpaper.isVideo ? "видео" : "изображение"
        stateful: false
        onToggled: Toggles.exclusive("wallpaperPicker")
    }

    CcTile {
        width: root.cellWidth
        glyph: Glyphs.brightness
        label: "Экран"
        detail: NightLight.enabled
            ? NightLight.temperature + "K"
            : Math.round(Brightness.value * 100) + "%"
        active: NightLight.enabled
        expandable: true
        onToggled: NightLight.toggle()
        onPageRequested: root.pageRequested("display")
    }

    CcTile {
        width: root.cellWidth
        glyph: Notifs.dnd ? Glyphs.bellOff : Glyphs.bell
        label: "Не беспокоить"
        detail: Notifs.dnd ? "включено" : "выключено"
        active: Notifs.dnd
        onToggled: Notifs.dnd = !Notifs.dnd
    }

    CcTile {
        width: root.cellWidth
        glyph: Recorder.recording ? Glyphs.stop : Glyphs.record
        label: "Запись"
        detail: Recorder.recording ? Recorder.elapsedText : "экран"
        active: Recorder.recording
        onToggled: Recorder.toggle()
    }

    CcTile {
        width: root.cellWidth
        glyph: Glyphs.monitor
        label: "Виджеты"
        detail: DesktopWidgets.editing ? "перетаскивание" : "закреплены"
        active: DesktopWidgets.editing
        // Closes on its way out: the widgets being edited are behind this
        // panel, so leaving it up would hide the thing being arranged.
        onToggled: {
            DesktopWidgets.toggleEditing();
            Toggles.controlCenterOpen = false;
        }
    }

    CcTile {
        width: root.cellWidth
        glyph: Power.available ? Power.glyphFor(Power.activeProfile) : Glyphs.power
        label: "Питание"
        detail: Power.available ? Power.labelFor(Power.activeProfile) : "выключение"
        stateful: false
        expandable: true
        onToggled: root.pageRequested("power")
        onPageRequested: root.pageRequested("power")
    }
}
