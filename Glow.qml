import QtQuick
import QtQuick.Effects

// The shell's one bloom.
//
// Drawn with the same primitive as a shadow and it is not one. A shadow says
// how far off the surface a thing sits, and that belongs to `Surface`, which
// owns depth for everything raised. This says a thing is *lit* — the focused
// desk, the island the music is coming through, a band the bass just hit.
//
// Four widgets built this figure by hand and settled on the same shape each
// time: accent-tinted, zero offset, spread about one, blur chosen by eye. What
// they did not agree on is the expensive part. `spread` is geometry, so moving
// it re-rasterises the whole blur — `BarIsland` measured that at 4.4 points of
// a core for one pulsing island and wrote it down, and the other three never
// heard. Here the geometry is fixed and growth is a transform, which the scene
// graph applies for free.
RectangularShadow {
    id: root

    // How lit, 0..1. The whole of the animation lives here.
    property real amount: 0
    // Extra reach on top of it — a beat, a swell. A scale rather than more
    // spread, for the reason above.
    property real swell: 0
    property color tint: Theme.accent
    // How far the light carries, which follows the size of the thing that is
    // lit: a 20px pill and a 116px cover cannot share a radius of light.
    property real reach: 20

    color: root.tint
    blur: root.reach
    spread: 1
    offset: Qt.vector2d(0, 0)
    opacity: root.amount
    // Below this it is under two per cent and indistinguishable from nothing,
    // while still costing a blurred rectangle every frame.
    visible: root.amount > 0.02
    scale: 1 + root.swell * 0.16
}
