import QtQuick

// The light that crosses a row while a change crosses it.
//
// Rule 8 needs something to be the wave. This is it: a soft halo with a bright
// core, put at a position along a row by whoever owns the row, and given a hue
// that may travel with it. On an equaliser the core runs warm at the bottom of
// the spectrum and cold at the top, which is not decoration -- it is the one
// place in the shell where a colour is a physical quantity.
//
// Drawn as a Glow plus a small solid core rather than as a blurred sprite:
// growth and brightness are then a transform and an opacity, which the scene
// graph applies without re-rasterising anything.
Item {
    id: root

    // 0 dark, 1 at full strength.
    property real amount: 0
    property color tint: Theme.accent
    // The hot centre. White reads as energy; the tint alone reads as a stain.
    property color core: "white"
    property real reach: 26
    // Size of the solid centre, which is what makes it a light rather than a
    // patch of colour.
    property real coreSize: 7

    visible: root.amount > 0.02
    implicitWidth: root.coreSize
    implicitHeight: root.coreSize

    Glow {
        anchors.centerIn: parent
        width: root.coreSize * 2
        height: root.coreSize * 2
        radius: width / 2
        tint: root.tint
        reach: root.reach
        amount: root.amount
        swell: root.amount
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.coreSize * (0.4 + 0.6 * root.amount)
        height: width
        radius: width / 2
        color: root.core
        opacity: root.amount * root.amount
    }
}
