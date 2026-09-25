pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Состояние сети для бара, без службы Quickshell.Networking.
//
// Служба, будучи созданной, шлёт NetworkManager RequestScan примерно раз в
// одиннадцать секунд. Отключить это из QML не удалось: ни scannerEnabled на
// устройстве, ни снятие подписки на список точек, ни удаление виджета из бара
// -- Bar.qml всё равно создаёт и верхний, и боковой бар, а SideWifiWidget
// трогал службу одним обращением к wifiEnabled, и этого хватало.
//
// Каждое сканирование уводит радио со своего канала обходить все 38 каналов.
// Измерено на этой машине: с оболочкой p99 задержки 113 мс и 15% пакетов
// дольше 20 мс, без неё -- 1,6 мс и ни одного.
//
// Здесь ничего не сканируется: скрипт читает уже установленное соединение.
// Панель сети и системная панель службу по-прежнему используют -- им это по
// делу, и живут они только пока открыты.
Singleton {
    id: root

    property bool wifiEnabled: false
    property string ssid: ""
    property int signalDbm: 0
    property string ethState: ""

    readonly property bool ethConnected: root.ethState === "connected"
    readonly property bool ethPresent: root.ethState !== ""

    // Четыре ступени по dBm: -50 и выше отлично, ниже -80 край.
    readonly property string wifiIcon: {
        // md-wifi-strength-* (U+F091F..F092D). The U+F0D1x range used before
        // is a different set of icons in current Nerd Fonts.
        if (!root.wifiEnabled) return "󰤭";
        if (root.ssid === "") return "󰤯";
        if (root.signalDbm >= -50) return "󰤨";
        if (root.signalDbm >= -60) return "󰤥";
        if (root.signalDbm >= -70) return "󰤢";
        return "󰤟";
    }

    property Process poll: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (line === "") return;
                const f = line.split("|");
                root.wifiEnabled = (f[0] || "") === "enabled";
                root.ssid = f[1] || "";
                root.signalDbm = (f[2] !== undefined && f[2] !== "") ? parseInt(f[2], 10) : 0;
                root.ethState = f[3] || "";
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (root.poll.running) return;
            if (typeof Caching === "undefined" || !Caching.yoakeDir) return;
            root.poll.command = ["sh", Caching.yoakeDir + "/scripts/wifi_status.sh"];
            root.poll.running = true;
        }
    }
}
