import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property bool isDesktop: false
    // Данные берёт общий синглтон KizashiNet -- он же кормит боковой виджет,
    // так что опросчик в системе один. Подробности, почему не служба
    // Quickshell.Networking, -- в самом Net.qml.
    readonly property bool isWifiOn: KizashiNet.wifiEnabled
    readonly property string wifiSsid: KizashiNet.ssid
    readonly property string wifiIcon: KizashiNet.wifiIcon
    readonly property string ethStatus: KizashiNet.ethConnected ? "Connected"
        : (KizashiNet.ethPresent ? "Disconnected" : "Ethernet")
    readonly property string wifiStatus: KizashiNet.wifiEnabled ? "Enabled" : "Off"
    property bool showEthernet: ethStatus === "Connected" || (isDesktop && !isWifiOn)
    property bool showLayout: (!module || module.moduleActive) && (!barWindow || (barWindow.isStartupReady && barWindow.isDataReady))
    property alias wifiPill: wifiPill

    Connections {
        target: module || null
        function onModuleActiveChanged() {
            if (module && !module.moduleActive) {
                chassisDetector.running = false;
            } else {
                chassisDetector.running = true;
            }
        }
    }

    Process {
        id: chassisDetector
        running: !module || module.moduleActive
        command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isDesktop = (this.text.trim() === "desktop");
            }
        }
    }

    property real targetWidth: ((!module || module.moduleActive) && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    property bool isFaceVisible: showLayout && targetWidth > 0

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    transform: Translate {
        x: root.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        property int pillHeight: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)

        ClickButton {
            id: wifiPill
            property bool initAnimTrigger: root.showLayout
            property bool isActive: root.showEthernet ? (root.ethStatus === "Connected") : root.isWifiOn

            height: sysLayout.pillHeight
            maxWidth: barWindow ? barWindow.s(root.isCompact ? 156 : 160) : (root.isCompact ? 156 : 160)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            horizontalPadding: barWindow ? barWindow.s(root.isCompact ? 10 : 12) : (root.isCompact ? 10 : 12)
            buttonIcon: root.showEthernet ? "󰈀" : root.wifiIcon
            iconFontSize: barWindow ? barWindow.s(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
            buttonText: root.showEthernet ? root.ethStatus : ((root.isWifiOn ? (root.wifiSsid !== "" ? root.wifiSsid : "On") : "Off"))
            textFontSize: barWindow ? barWindow.s(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)
            accentColor: isActive ? (root.isCompact ? Qt.lighter(ThemeBackend.blue, 1.08) : ThemeBackend.blue) : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
            textColor: isActive ? ThemeBackend.base : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

            property real targetWidth: implicitWidth
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: wifiPill.initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.kizashiDir + "/scripts/qs_manager.sh toggle network wifi"])
        }
    }
}
