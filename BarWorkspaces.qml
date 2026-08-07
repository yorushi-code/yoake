import QtQuick
import Quickshell

// Workspace pills. Unfocused workspaces are dots and the focused one widens
// into a numbered pill — a lighter touch than uniform numbered squares.
//
// The output is a parameter rather than the hardcoded "eDP-1" it used to be:
// the shell is instantiated per screen now, and a bar on a second monitor was
// previously showing the laptop panel's workspaces.
Row {
    id: root

    property string output: ""

    spacing: Theme.spacing
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // Positioner transitions rather than a Component.onCompleted animation in
    // the delegate: these fire only when a pill really is added or has to
    // shift, which is the whole point of the ScriptModel below. The old
    // hand-rolled entry ran on every delegate construction, and before the
    // model was diffed that meant every workspace switch.
    add: MotionAdd {}
    move: MotionMove {}
    populate: MotionAdd {}

    Repeater {
        // ScriptModel, not the plain array. workspacesFor() returns a fresh
        // array on every niri event, and a Repeater bound to an array rebuilds
        // every delegate when its identity changes — so switching workspace
        // destroyed and recreated all the pills and replayed their pop-in
        // animation each time. That is the "animations repeat for no reason"
        // bug: measured at 24 delegate rebuilds over seven switches, now zero.
        model: ScriptModel {
            values: Niri.workspacesFor(root.output)
            objectProp: "id"
        }

        delegate: Item {
            id: wsDelegate
            required property var modelData
            width: pill.width
            height: Theme.barHeight
            anchors.verticalCenter: parent.verticalCenter

            // So the focused desk reads as lit rather than just filled.
            Glow {
                anchors.fill: pill
                radius: pill.radius
                tint: modelData.is_urgent ? Theme.red : Theme.accent
                reach: 20
                amount: modelData.is_focused
                    ? Theme.veilDense
                    : (modelData.is_urgent ? Theme.veilFirm : 0)
                Behavior on amount {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                }
            }

            readonly property bool occupied: Niri.windowCountOn(modelData.id) > 0

            Rectangle {
                id: pill
                // Three states, not two: focused is a numbered pill, occupied a
                // full dot, empty a small hollow one. An empty workspace and one
                // with six windows used to be the same mark.
                width: modelData.is_focused ? 26 : (wsDelegate.occupied ? 9 : 7)
                height: modelData.is_focused ? 9 : (wsDelegate.occupied ? 9 : 7)
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.is_focused
                    ? Theme.accent
                    : (modelData.is_urgent ? Theme.red
                        : (mouseArea.containsMouse ? Theme.subtext0
                            : (wsDelegate.occupied ? Qt.alpha(Theme.text, Theme.inkFaint) : "transparent")))
                border.width: (!modelData.is_focused && !wsDelegate.occupied) ? 1.5 : 0
                border.color: Qt.alpha(Theme.text, Theme.inkGhost)
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on width {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                }
                Behavior on height {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.idx
                    visible: modelData.is_focused
                    color: Theme.crust
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMicro
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                }

                Ripple {
                    anchors.fill: parent
                    radius: parent.radius
                    rippleColor: Theme.text
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: {
                    Menus.closeAll();
                    Niri.focusWorkspace(modelData.idx);
                }
                // Wheel over the workspace row walks between them, matching the
                // Mod+scroll bind that already does this compositor-side.
                onWheel: wheel => {
                    Niri.action(wheel.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down");
                }
            }

            Tooltip {
                anchorItem: wsDelegate
                active: mouseArea.containsMouse
                text: modelData.name ? modelData.name : "Рабочий стол " + modelData.idx
                subtext: {
                    const n = Niri.windowCountOn(modelData.id);
                    if (n === 0) return "пусто · колесо — переключение";
                    const word = n === 1 ? "окно" : (n < 5 ? "окна" : "окон");
                    return n + " " + word + " · колесо — переключение";
                }
            }
        }
    }
}
