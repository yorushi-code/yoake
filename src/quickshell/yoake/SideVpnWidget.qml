import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import "../reusables"
import "../"

// Тот же чип на боковом баре. Раньше его тут просто не было: бар сбоку строит
// SideBar.qml из своих модулей, и VPN среди них не значился -- то есть при
// баре слева или справа панель оставалась доступной только по клавише.
//
// Места на подпись нет, поэтому всё говорит цвет: бирюзовый -- туннель поднят,
// красный -- утечка или чужой туннель забрал маршрут, серый -- выключен.
Rectangle {
    id: sideVpnRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real targetY: 0
    property bool showLayout: false
    property alias vpnPill: vpnBtn

    readonly property bool isUp: Mihomo.running && Mihomo.controllerUp
    readonly property bool isBad: (isUp && Mihomo.leaking) || Mihomo.conflict !== ""

    y: targetY
    width: barWindow ? barWindow.barHeight : 40
    height: barWindow ? barWindow.barHeight : 40

    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    radius: ThemeBackend.borderRadius
    border.width: (isGrouped || isSolid) ? 0 : 1
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    clip: true

    opacity: (showLayout && moduleActive)
        ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: sideVpnRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: sideVpnRoot.showLayout = true
    }

    IconButton {
        id: vpnBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(30) : 30
        height: barWindow ? barWindow.s(30) : 30
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
        buttonIcon: sideVpnRoot.isUp ? "󰦝" : "󰦞"
        iconFontSize: barWindow ? barWindow.s(15) : 15
        accentColor: sideVpnRoot.isBad
            ? ThemeBackend.red
            : (sideVpnRoot.isUp ? ThemeBackend.teal : ThemeBackend.surface0)
        textColor: (sideVpnRoot.isBad || sideVpnRoot.isUp) ? ThemeBackend.base : ThemeBackend.text
        onClicked: Quickshell.execDetached(["bash", "-c",
            Caching.yoakeDir + "/scripts/qs_manager.sh toggle vpn"])
    }
}
