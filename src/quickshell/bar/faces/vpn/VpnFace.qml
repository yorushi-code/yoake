import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"

// The VPN chip. It reads Mihomo, which is what actually keeps the state;
// referencing it here is also what constructs it, since a QML singleton is
// built on first use.
Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property bool showLayout: false
    property alias vpnPill: vpnPill

    // Three states worth telling apart at chip size, and they are not degrees
    // of the same thing: off is a choice, leaking is a fault, and running is
    // the ordinary case. Colour carries it because the glyph cannot.
    readonly property bool isUp: Mihomo.running && Mihomo.controllerUp
    readonly property bool isBad: (isUp && Mihomo.leaking) || Mihomo.conflict !== ""

    readonly property string label: {
        if (Mihomo.conflict !== "") return Mihomo.conflict;
        if (!Mihomo.running) return "Off";
        if (!Mihomo.controllerUp) return "...";
        if (Mihomo.leaking) return "Leak";
        return Mihomo.currentNode !== "" ? Mihomo.currentNode : "On";
    }

    function s(val) { return barWindow ? barWindow.s(val) : val; }

    property real targetWidth: ((!module || module.moduleActive) && vpnLayout.implicitWidth > 0)
        ? (vpnLayout.implicitWidth + s(isCompact ? 8 : 10)) : 0
    property bool isFaceVisible: showLayout && targetWidth > 0

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    Timer {
        running: (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: root.showLayout ? 0 : root.s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: vpnLayout
        anchors.centerIn: parent
        property int pillHeight: root.s(root.isCompact ? 28 : 30)

        ClickButton {
            id: vpnPill
            property bool initAnimTrigger: false

            height: vpnLayout.pillHeight
            maxWidth: root.s(170)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - root.s(2))
            horizontalPadding: root.s(root.isCompact ? 10 : 12)
            buttonIcon: root.isUp ? "󰦝" : "󰦞"
            iconFontSize: root.s(root.isCompact ? 14 : 15)
            buttonText: root.label
            textFontSize: root.s(root.isCompact ? 11 : 12)
            accentColor: root.isBad ? ThemeBackend.red
                : (root.isUp ? ThemeBackend.teal
                    : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0))
            textColor: (root.isBad || root.isUp) ? ThemeBackend.base : ThemeBackend.text

            property real targetWidth: implicitWidth
            width: targetWidth
            Behavior on width {
                enabled: root.barWindow && root.barWindow.startupCascadeFinished
                NumberAnimation { duration: 480; easing.type: Easing.OutQuint }
            }

            Timer {
                running: (!root.module || root.module.moduleActive) && root.showLayout && !vpnPill.initAnimTrigger
                interval: 130
                onTriggered: vpnPill.initAnimTrigger = true
            }
            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate {
                y: vpnPill.initAnimTrigger ? 0 : root.s(15)
                Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
            }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c",
                Caching.yoakeDir + "/scripts/qs_manager.sh toggle vpn"])
        }
    }
}
