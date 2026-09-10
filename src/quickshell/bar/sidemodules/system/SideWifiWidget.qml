import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

Rectangle {
    id: sideWifiRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property bool isDesktop: false
    property real targetY: 0
    property bool showLayout: moduleActive && (!barWindow || (barWindow.isStartupReady && barWindow.isDataReady))
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

    property real targetWidth: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    property real targetHeight: (moduleActive && wifiBtn.height > 0) ? (wifiBtn.height + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0

    width: targetWidth
    height: targetHeight

    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    x: barWindow ? ((barWindow.baseOffsetX !== undefined ? barWindow.baseOffsetX : 0) + (barWindow.barHeight - width) / 2) : 0
    y: targetY
    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    clip: true

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    onModuleActiveChanged: {
        if (!moduleActive) {
            chassisDetector.running = false;
        } else {
            chassisDetector.running = true;
        }
    }

    Process {
        id: chassisDetector
        running: sideWifiRoot.moduleActive
        command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                isDesktop = (this.text.trim() === "desktop");
            }
        }
    }

    IconButton {
        id: wifiBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(sideWifiRoot.isCompact ? 28 : 30) : (sideWifiRoot.isCompact ? 28 : 30)
        height: barWindow ? barWindow.s(sideWifiRoot.isCompact ? 28 : 30) : (sideWifiRoot.isCompact ? 28 : 30)
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
        buttonIcon: sideWifiRoot.showEthernet ? "󰈀" : sideWifiRoot.wifiIcon
        iconFontSize: barWindow ? barWindow.s(sideWifiRoot.isCompact ? 14 : 15) : (sideWifiRoot.isCompact ? 14 : 15)
        accentColor: sideWifiRoot.isActive ? (sideWifiRoot.isCompact ? Qt.lighter(ThemeBackend.blue, 1.08) : ThemeBackend.blue) : (sideWifiRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
        textColor: sideWifiRoot.isActive ? ThemeBackend.base : (sideWifiRoot.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)
        iconOffsetX: sideWifiRoot.showEthernet ? 0 : -3
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.yoakeDir + "/scripts/qs_manager.sh toggle network wifi"])
    }
}
