import QtQuick

// One icon.
//
// The shell drew Nerd Font glyphs, which is a bitmap-era idea wearing a font:
// a fixed picture per state, so "wifi on" and "wifi off" are two unrelated
// shapes and switching between them is a substitution the eye reads as a swap.
// Material Symbols is a variable font, and its `FILL` axis turns that into one
// shape whose interior fills — the same picture in a different state, and a
// state you can *animate into*. That is the whole reason for this component;
// everything else here is bookkeeping.
//
// `opsz` is not decoration either. The font redraws its strokes for the size
// it is set at, so leaving the axis at its default draws a 34px icon with the
// stroke weight of a 24px one, which is exactly the thin, undersized look that
// made the old icons read as clip art.
Text {
    id: root

    // A name from Glyphs, which is a Material Symbols ligature.
    property string icon: ""
    property real size: Theme.fontIcon
    // 0 outline, 1 solid.
    property real fill: 0
    // 100..700. The text beside an icon is rarely heavier than Medium, and an
    // icon at 400 sits right against it.
    property int weight: 400
    // Contrast trim: thickens the strokes without changing the glyph's advance,
    // which is what light-on-dark needs and what a weight change cannot do
    // without moving everything beside it.
    property real grade: 0

    text: root.icon
    font.family: Theme.fontIconFamily
    font.pixelSize: root.size
    font.variableAxes: ({
        "FILL": root.fill,
        "wght": root.weight,
        "GRAD": root.grade,
        // The axis only exists between these, and Qt clamps silently rather
        // than complaining, which would make a wrong value invisible.
        "opsz": Math.max(20, Math.min(48, root.size))
    })
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    Behavior on fill {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasized
        }
    }
}
