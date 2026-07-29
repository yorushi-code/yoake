import QtQuick

// Transition for an item entering a positioner (Row/Column/Grid/ListView).
//
// Used with ScriptModel-backed views, where a row really does appear rather
// than the whole list being rebuilt — a Repeater over a plain array never
// reaches these, because there the "addition" is every delegate at once.
Transition {
    ParallelAnimation {
        NumberAnimation {
            properties: "opacity"
            from: 0
            to: 1
            duration: Theme.animNormal
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasized
        }
        NumberAnimation {
            properties: "scale"
            from: Theme.revealScale
            to: 1
            duration: Theme.animSlow
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeSpringBig
        }
    }
}
