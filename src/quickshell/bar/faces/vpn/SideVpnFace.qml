import QtQuick
import Quickshell
import "../../../reusables"
import "../../../"

// The VPN chip on a side bar. There is no room for a label, so colour says it
// all: teal -- the tunnel is up, red -- a leak or another tunnel took the
// route, grey -- off.
Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property bool showLayout: false
    property alias vpnPill: vpnBtn

    readonly property bool isUp: Mihomo.running && Mihomo.controllerUp
    readonly property bool isBad: (isUp && Mihomo.leaking) || Mihomo.conflict !== ""

    function s(val) { return barWindow ? barWindow.s(val) : val; }

    property real targetHeight: vpnBtn.height + s(isCompact ? 8 : 10)
    property bool isFaceVisible: showLayout && targetHeight > 0

    implicitHeight: targetHeight
    implicitWidth: parent ? parent.width : 0

    Timer {
        running: (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    IconButton {
        id: vpnBtn
        anchors.centerIn: parent
        width: root.s(root.isCompact ? 28 : 30)
        height: root.s(root.isCompact ? 28 : 30)
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - root.s(2))
        buttonIcon: root.isUp ? "󰦝" : "󰦞"
        iconFontSize: root.s(root.isCompact ? 14 : 15)
        accentColor: root.isBad ? ThemeBackend.red
            : (root.isUp ? ThemeBackend.teal
                : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0))
        textColor: (root.isBad || root.isUp) ? ThemeBackend.base : ThemeBackend.text
        onClicked: Quickshell.execDetached(["bash", "-c",
            Caching.yoakeDir + "/scripts/qs_manager.sh toggle vpn"])
    }
}
