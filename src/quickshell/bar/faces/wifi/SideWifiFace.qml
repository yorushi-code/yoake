import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property bool isDesktop: false
    property bool showLayout: (!module || module.moduleActive) && (!barWindow || (barWindow.isStartupReady && barWindow.isDataReady))
    property alias wifiPill: wifiBtn

    // Данные из общего синглтона YoakeNet, как и у верхнего виджета; служба
    // Quickshell.Networking здесь не создаётся -- почему, см. Net.qml.
    readonly property bool isWifiOn: YoakeNet.wifiEnabled
    readonly property string wifiSsid: YoakeNet.ssid
    readonly property string wifiIcon: YoakeNet.wifiIcon
    readonly property string ethStatus: YoakeNet.ethConnected ? "Connected"
        : (YoakeNet.ethPresent ? "Disconnected" : "Ethernet")
    readonly property string wifiStatus: YoakeNet.wifiEnabled ? "Enabled" : "Off"
    property bool showEthernet: ethStatus === "Connected" || (isDesktop && !isWifiOn)
    property bool isActive: showEthernet ? (ethStatus === "Connected") : isWifiOn

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

    property real targetHeight: wifiBtn.height + (barWindow ? barWindow.s(root.isCompact ? 8 : 10) : (root.isCompact ? 8 : 10))
    property bool isFaceVisible: showLayout && targetHeight > 0

    implicitHeight: targetHeight
    implicitWidth: parent ? parent.width : 0

    ClickButton {
        id: wifiBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
        height: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
        horizontalPadding: 0
        buttonIcon: root.showEthernet ? "󰈀" : root.wifiIcon
        iconFontSize: barWindow ? barWindow.s(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
        accentColor: root.isActive ? (root.isCompact ? Qt.lighter(ThemeBackend.blue, 1.08) : ThemeBackend.blue) : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
        textColor: root.isActive ? ThemeBackend.base : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.yoakeDir + "/scripts/qs_manager.sh toggle network wifi"])
    }
}
