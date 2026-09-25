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

Rectangle {
    id: wifiWidgetRoot
    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property bool isDesktop: false
    // Данные берёт общий синглтон YoakeNet -- он же кормит боковой виджет,
    // так что опросчик в системе один. Подробности, почему не служба
    // Quickshell.Networking, -- в самом Net.qml.
    readonly property bool isWifiOn: YoakeNet.wifiEnabled
    readonly property string wifiSsid: YoakeNet.ssid
    readonly property string wifiIcon: YoakeNet.wifiIcon
    readonly property string ethStatus: YoakeNet.ethConnected ? "Connected"
        : (YoakeNet.ethPresent ? "Disconnected" : "Ethernet")
    readonly property string wifiStatus: YoakeNet.wifiEnabled ? "Enabled" : "Off"
    property bool showEthernet: ethStatus === "Connected" || (isDesktop && !isWifiOn)
    property real targetX: 0
    property bool showLayout: moduleActive && (!barWindow || (barWindow.isStartupReady && barWindow.isDataReady))
    property alias wifiPill: wifiPill

    onModuleActiveChanged: {
        if (!moduleActive) {
            chassisDetector.running = false;
        } else {
            chassisDetector.running = true;
        }
    }

    Process {
        id: chassisDetector
        running: wifiWidgetRoot.moduleActive
        command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                isDesktop = (this.text.trim() === "desktop");
            }
        }
    }

    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }
    height: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    y: barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - height) / 2 : 0
    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    clip: true

    property real targetWidth: (moduleActive && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    width: targetWidth

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    transform: Translate {
        x: wifiWidgetRoot.showLayout ? 0 : barWindow.s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        property int pillHeight: barWindow ? barWindow.s(wifiWidgetRoot.isCompact ? 28 : 30) : (wifiWidgetRoot.isCompact ? 28 : 30)

        ClickButton {
            id: wifiPill
            property bool initAnimTrigger: wifiWidgetRoot.showLayout
            property bool isActive: showEthernet ? (ethStatus === "Connected") : isWifiOn

            height: sysLayout.pillHeight
            maxWidth: barWindow ? barWindow.s(wifiWidgetRoot.isCompact ? 156 : 160) : (wifiWidgetRoot.isCompact ? 156 : 160)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            horizontalPadding: barWindow ? barWindow.s(wifiWidgetRoot.isCompact ? 10 : 12) : (wifiWidgetRoot.isCompact ? 10 : 12)
            buttonIcon: showEthernet ? "󰈀" : wifiIcon
            iconFontSize: barWindow ? barWindow.s(wifiWidgetRoot.isCompact ? 14 : 15) : (wifiWidgetRoot.isCompact ? 14 : 15)
            buttonText: showEthernet ? ethStatus : ((isWifiOn ? (wifiSsid !== "" ? wifiSsid : "On") : "Off"))
            textFontSize: barWindow ? barWindow.s(wifiWidgetRoot.isCompact ? 11 : 12) : (wifiWidgetRoot.isCompact ? 11 : 12)
            accentColor: isActive ? (wifiWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.blue, 1.08) : ThemeBackend.blue) : (wifiWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
            textColor: isActive ? ThemeBackend.base : (wifiWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

            property real targetWidth: implicitWidth
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: wifiPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.yoakeDir + "/scripts/qs_manager.sh toggle network wifi"])
        }
    }
}
