import QtQuick
import Quickshell

// Workspaces, as fixed cells with one pill travelling between them.
//
// This was a Row of pills where the focused one widened and the others shrank
// to dots. Two things were wrong with that, and they are the same thing seen
// twice. On screen, the focus never moved: the pill you were on gave up its
// width on the same frame another one took it, which is a cross-fade, and a
// cross-fade cannot say which direction you went. In the layout, the row's
// width changed with every switch — a 26px pill becoming a 9px dot is 17px the
// whole left island breathes in and out, on a bar whose centre is composed
// against it.
//
// Fixed cells fix the second, and having somewhere fixed to travel *between* is
// what makes the first possible: the accent is now one object that glides, and
// the cell it lands on dissolves its dot into its number as it arrives.
//
// The output is a parameter rather than the hardcoded "eDP-1" it used to be:
// the shell is instantiated per screen now, and a bar on a second monitor was
// previously showing the laptop panel's workspaces.
Item {
    id: root

    property string output: ""

    // The cell is the same width whatever state it is in, which is the whole
    // point — see above. Wide enough for a two-digit index at the micro rung.
    readonly property int cellWidth: 20
    readonly property int cellGap: 3

    implicitWidth: cells.implicitWidth
    implicitHeight: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    readonly property var _all: Niri.workspacesFor(root.output)
    readonly property bool _anyFocused: root._all.some(w => w.is_focused)

    // Declared before the cells, so a number lands on top of the pill rather
    // than under it.
    Traveller {
        id: marker
        active: root._anyFocused
        slotY: Math.round((root.height - marker.slotHeight) / 2)
        slotWidth: root.cellWidth - 2
        slotHeight: 11
        // A whole cell-width hop is the common case and should read as a real
        // journey, so the span that earns full deformation is a couple of them.
        span: (root.cellWidth + root.cellGap) * 2

        readonly property real radius: height / 2

        // Inside the marker rather than anchored to it, so it inherits the
        // deformation. A glow that stays a neat rectangle while the thing it is
        // lighting stretches is two objects, and the eye finds the seam.
        Glow {
            anchors.fill: parent
            radius: marker.radius
            tint: Theme.accent
            reach: 20
            // Lit at rest and brighter in flight, because the light is the same
            // event as the movement — reading the phase off the marker keeps
            // the two from drifting apart the way a second timer would. At the
            // dense rung throughout it washed half the island, which on an
            // opaque surface is not glass catching the light, it is a stain.
            amount: marker.active
                ? Theme.veilSoft + (Theme.veilDense - Theme.veilSoft) * marker.flight
                : 0
            swell: marker.flight
            Behavior on amount {
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: marker.radius
            color: Theme.accent
        }
    }

    Row {
        id: cells
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: root.height
        spacing: root.cellGap

        // Positioner transitions rather than a Component.onCompleted animation
        // in the delegate: these fire only when a cell really is added or has
        // to shift, which is the whole point of the ScriptModel below. The old
        // hand-rolled entry ran on every delegate construction, and before the
        // model was diffed that meant every workspace switch.
        add: MotionAdd {}
        move: MotionMove {}
        populate: MotionAdd {}

        Repeater {
            // ScriptModel, not the plain array. workspacesFor() returns a fresh
            // array on every niri event, and a Repeater bound to an array
            // rebuilds every delegate when its identity changes — so switching
            // workspace destroyed and recreated all the cells and replayed
            // their pop-in animation each time. That is the "animations repeat
            // for no reason" bug: measured at 24 delegate rebuilds over seven
            // switches, now zero.
            model: ScriptModel {
                values: root._all
                objectProp: "id"
            }

            delegate: Item {
                id: cell
                required property var modelData
                width: root.cellWidth
                height: root.height

                // Compared rather than assigned: niri leaves these out of the
                // object entirely rather than sending false, and `undefined`
                // assigned to a bool property is a warning per workspace per
                // event -- which the old code never saw only because it used
                // them inside ternaries, where undefined is merely falsy.
                readonly property bool focused: cell.modelData.is_focused === true
                readonly property bool urgent: cell.modelData.is_urgent === true
                readonly property bool occupied: Niri.windowCountOn(cell.modelData.id) > 0

                // RestoreNone, deliberately. The default restores the previous
                // value when `when` goes false, and nothing orders the old
                // cell's release against the new cell's claim — so on half the
                // switches the marker would be handed back the position it had
                // just left, one frame after setting off.
                Binding {
                    target: marker
                    property: "slotX"
                    value: cells.x + cell.x + 1
                    when: cell.focused
                    restoreMode: Binding.RestoreNone
                }

                // Urgency is the cell's own business: it is a property of a
                // workspace you are *not* on, so it cannot be carried by an
                // object that is only ever on the one you are.
                Glow {
                    anchors.centerIn: dot
                    width: dot.width + 8
                    height: dot.height + 8
                    radius: width / 2
                    tint: Theme.red
                    reach: 14
                    amount: cell.urgent && !cell.focused ? Theme.veilFirm : 0
                    Behavior on amount {
                        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                    }
                }

                // Three states, not two: an empty workspace is a hollow ring,
                // one holding windows is a filled dot, and the one you are on
                // is the number. An empty desk and a desk with six windows used
                // to be the same mark.
                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    width: cell.occupied ? 8 : 7
                    height: width
                    radius: width / 2
                    // Shrinks out from under the pill as it lands rather than
                    // being switched off, so the arrival is one event.
                    scale: cell.focused ? 0.35 : 1
                    opacity: cell.focused ? 0 : 1
                    color: cell.urgent ? Theme.red
                        : (hover.containsMouse ? Theme.subtext0
                            : (cell.occupied ? Qt.alpha(Theme.text, Theme.inkFaint) : "transparent"))
                    border.width: cell.occupied ? 0 : 1.5
                    border.color: cell.urgent ? Theme.red : Qt.alpha(Theme.text, Theme.inkGhost)

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on width {
                        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                    }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: cell.modelData.idx
                    color: Theme.crust
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMicro
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                    opacity: cell.focused ? 1 : 0
                    // Held back until the pill is most of the way here. Arriving
                    // with it turns two events into one blur, and the number is
                    // the confirmation, not the announcement.
                    scale: cell.focused ? 1 : 0.6

                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: cell.focused ? Direction.beatContent : 0 }
                            NumberAnimation { duration: Theme.animFast }
                        }
                    }
                    Behavior on scale {
                        SequentialAnimation {
                            PauseAnimation { duration: cell.focused ? Direction.beatContent : 0 }
                            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                        }
                    }
                }

                // Wrapped: Ripple fills its parent by construction, so the way
                // to give it a shape other than the cell's is to give it a
                // parent of that shape.
                Item {
                    id: rippleBox
                    anchors.centerIn: parent
                    width: root.cellWidth
                    height: 18

                    Ripple {
                        id: ripple
                        radius: height / 2
                        rippleColor: Theme.text
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    anchors.margins: -2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    // Played from here rather than by the Ripple's own hit
                    // area: this MouseArea is on top of it and takes the press,
                    // so the ripple would never have seen one.
                    onPressed: mouse => {
                        const at = hover.mapToItem(rippleBox, mouse.x, mouse.y);
                        ripple.play(at.x, at.y);
                    }
                    onClicked: {
                        Menus.closeAll();
                        Niri.focusWorkspace(cell.modelData.idx);
                    }
                    // Wheel over the workspace row walks between them, matching
                    // the Mod+scroll bind that already does this
                    // compositor-side.
                    onWheel: wheel => {
                        Niri.action(wheel.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down");
                    }
                }

                Tooltip {
                    anchorItem: cell
                    active: hover.containsMouse
                    text: cell.modelData.name ? cell.modelData.name : "Рабочий стол " + cell.modelData.idx
                    subtext: {
                        const n = Niri.windowCountOn(cell.modelData.id);
                        if (n === 0) return "пусто · колесо — переключение";
                        const word = n === 1 ? "окно" : (n < 5 ? "окна" : "окон");
                        return n + " " + word + " · колесо — переключение";
                    }
                }
            }
        }
    }
}
