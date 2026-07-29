import QtQuick
import QtQuick.Effects
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

    spacing: 7
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

            // Accent-tinted RectangularShadow doubles as a glow, so the focused
            // workspace reads as lit rather than just filled.
            RectangularShadow {
                anchors.fill: pill
                radius: pill.radius
                color: modelData.is_urgent ? Theme.red : Theme.accent
                blur: 20
                spread: 1
                opacity: modelData.is_focused ? 0.75 : (modelData.is_urgent ? 0.6 : 0)
                offset: Qt.vector2d(0, 0)
                Behavior on opacity {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                }
            }

            Rectangle {
                id: pill
                width: modelData.is_focused ? 26 : 9
                height: 9
                radius: 4.5
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.is_focused
                    ? Theme.accent
                    : (modelData.is_urgent ? Theme.red : (mouseArea.containsMouse ? Theme.subtext0 : Theme.surface2))
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on width {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.idx
                    visible: modelData.is_focused
                    color: Theme.crust
                    font.pixelSize: 9
                    font.bold: true
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
                subtext: "колесо — переключение"
            }
        }
    }
}
