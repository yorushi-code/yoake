import QtQuick

// Transition for items sliding to a new slot because a neighbour appeared or
// went away. Without one they teleport, which makes an addition elsewhere in
// the list look like the whole list flickered.
Transition {
    NumberAnimation {
        properties: "x,y"
        duration: Theme.animNormal
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasized
    }
}
