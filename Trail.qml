import QtQuick
import QtQuick.Shapes

// The line the travelling light leaves behind it.
//
// Two strokes over the same points. A wide, soft, low-alpha one that reads as
// plasma, and a thin bright one that passes exactly through the points -- and
// the thin one is the reason this is not decoration: on an equaliser it is the
// response curve, drawn through the band handles, so the prettiest thing on the
// panel is also the only place the curve is stated at all.
//
// Revealed by clipping rather than by shortening the path. A polyline cannot be
// drawn partially without recomputing it every frame, and a clip is one
// rectangle the scene graph already knows how to move.
Item {
    id: root

    // Points in this item's coordinates, in order.
    property var points: []
    // How much of the row the light has crossed, 0..1.
    property real head: 0
    // Fades the whole thing out once the change has landed. The trail is a
    // response, not an ornament: it has to end, or it becomes a permanently
    // running animation on a surface (see PerformanceContract.md).
    property real life: 0
    property color tint: Theme.accent

    visible: root.life > 0.02 && root.points.length > 1

    Item {
        id: window
        height: parent.height
        width: Math.max(0, root.width * Math.max(0, Math.min(1, root.head)))
        clip: true

        Shape {
            width: root.width
            height: root.height
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            opacity: root.life

            // The soft body. Breathing on the vertical only, so the curve keeps
            // passing through the points while the cloud around it moves.
            ShapePath {
                strokeColor: Qt.alpha(root.tint, Theme.veilSoft)
                strokeWidth: 11
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: root.points }
            }

            ShapePath {
                strokeColor: Qt.alpha(root.tint, Theme.veilThin)
                strokeWidth: 20
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: root.points }
            }

            // The statement.
            ShapePath {
                strokeColor: Qt.alpha("white", Theme.veilDense)
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: root.points }
            }
        }
    }
}
