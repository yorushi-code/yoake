import QtQuick

// The edge of a list that continues.
//
// Three Flickables in this shell clip their content and none of them said so.
// A subscription row cut in half by a panel edge and a cheat sheet missing its
// last line both read as rendering faults, which is the worst way for a list to
// be longer than its box: the reader concludes the shell is broken rather than
// that there is more to see.
//
// A scrollbar is the obvious answer and the wrong one here. Every surface in
// this shell is glass laid over a wallpaper, and a rail parked on top of one is
// the single piece of chrome that cannot be made to belong to it. A fade says
// the same thing and is made of the surface it sits on — and it says it only
// while it is true, which a rail cannot.
Item {
    id: root

    required property Flickable flick
    // What the list is sitting on. A fade is that surface reasserting itself
    // over its own content, so it has to be the ground's colour rather than a
    // shadow's.
    property color tint: Theme.crust
    property real extent: 28

    anchors.fill: root.flick
    // Decoration over a scrollable list is the one place a stray hit area does
    // real damage: it would eat the wheel event for the list it is describing.
    enabled: false

    // A pixel of slack at each end, because contentY lands on fractions after a
    // flick and an edge that flickers is worse than no edge.
    readonly property bool moreAbove: root.flick && root.flick.contentY > 1
    readonly property bool moreBelow: root.flick
        && root.flick.contentY < root.flick.contentHeight - root.flick.height - 1

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.extent
        opacity: root.moreAbove ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(root.tint, Theme.veilDense) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.extent
        opacity: root.moreBelow ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.alpha(root.tint, Theme.veilDense) }
        }
    }
}
