import QtQuick
import Quickshell

// Desks, set as figures.
//
// They were dots, which is what every shell does and what nothing else on this
// masthead is: a row of moulded shapes among set type. As numerals they carry
// the same information and read as part of the page — occupied desks are
// present, empty ones are dimmed rather than hidden, and the focused one takes
// the accent and a rule beneath it.
//
// The output is a parameter rather than a hardcoded "eDP-1": the shell is
// instantiated per screen, and a bar on a second monitor was previously showing
// the laptop panel's desks.
Row {
    id: root

    property string output: ""

    spacing: 0

    add: MotionAdd {}
    move: MotionMove {}
    populate: MotionAdd {}

    Repeater {
        // ScriptModel, not the plain array. workspacesFor() returns a fresh
        // array on every niri event, and a Repeater bound to an array rebuilds
        // every delegate when its identity changes — so switching desk destroyed
        // and recreated all of them and replayed their entry animation each
        // time. Measured at 24 rebuilds over seven switches, now zero.
        model: ScriptModel {
            values: Niri.workspacesFor(root.output)
            objectProp: "id"
        }

        delegate: Item {
            id: desk
            required property var modelData

            readonly property int windows: Niri.windowCountOn(modelData.id)
            readonly property bool occupied: desk.windows > 0

            width: figure.implicitWidth + 26
            height: 26

            Text {
                id: figure
                anchors.centerIn: parent
                text: modelData.idx
                color: modelData.is_focused ? Theme.accent
                    : (modelData.is_urgent ? Theme.red
                        : (area.containsMouse ? Theme.text
                            : (desk.occupied ? Theme.subtext1 : Qt.alpha(Theme.subtext0, 0.45))))
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                font.weight: modelData.is_focused ? Font.DemiBold : Font.Medium
                font.features: ({ "tnum": 1 })
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // The rule is the marker. A filled pill would put a moulded shape
            // back among the type, which is the thing this language does not do.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: modelData.is_focused ? figure.implicitWidth + 10 : 0
                height: Theme.ruleBold
                color: modelData.is_urgent ? Theme.red : Theme.accent
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasized
                    }
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: {
                    Menus.closeAll();
                    Niri.focusWorkspace(modelData.idx);
                }
                onWheel: wheel => {
                    Niri.action(wheel.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down");
                }
            }

            Tooltip {
                anchorItem: desk
                active: area.containsMouse
                text: modelData.name ? modelData.name : "Рабочий стол " + modelData.idx
                subtext: {
                    if (desk.windows === 0) return "пусто · колесо — переключение";
                    const word = desk.windows === 1 ? "окно" : (desk.windows < 5 ? "окна" : "окон");
                    return desk.windows + " " + word + " · колесо — переключение";
                }
            }
        }
    }
}
