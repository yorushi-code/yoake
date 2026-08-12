import QtQuick

// One arrival, shared by every list that cascades.
//
// Three lists spelled this out and all three spelled the same sentence: fade in
// and grow from `Theme.revealScale`, after `Direction.stagger(index)`. What they
// did not share was how many times they waited out that stagger. The history
// cards and the cheat sheet each ran a `ParallelAnimation` of two
// `SequentialAnimation`s, and the toasts three, every one of them opening with
// its own `PauseAnimation` counting the same delay. One delay is one wait; three
// timers for it are three chances for the parts of a single arrival to come
// apart, and three objects built and torn down per delegate for a job that needs
// one.
//
// They had also drifted in the usual quiet way: the toasts grew over `animSlow`
// with the big spring, the other two over `animNormal` with the small one, all
// three meaning "the entrance the panels have". The durations here are the ones
// `Reveal` plays for its space and object beats, because that is what the
// entrance *is* — this file is the same choreography for things that arrive
// inside a surface rather than as one.
//
// Not `Reveal` itself, deliberately. A wrapper would add an Item and four
// Behaviors to every row of every list, and the beats it would buy are worth
// nothing here: a delegate is `ambient` by Direction's own definition — present,
// never the subject — and at that type the beats fall 15 to 42 ms apart, which
// is under the threshold at which a sequence reads as a sequence at all. The
// coherence was worth having; the layer was not.
//
// Anything declared inside runs in parallel with the pair, after the one wait —
// which is how a list whose items come *from* somewhere adds its travel without
// adding a second clock.
SequentialAnimation {
    id: root

    // The delegate. It is expected to start at `opacity: 0` and
    // `scale: Theme.revealScale`, and to set its own `transformOrigin`.
    property Item item: null
    // Position in the cascade. `Direction.stagger` caps it, so a fifty-row list
    // does not still be arriving a second and a half after it opened.
    property int index: 0

    default property alias extra: bundle.animations

    PauseAnimation { duration: Direction.stagger(root.index) }

    ParallelAnimation {
        id: bundle

        NumberAnimation {
            target: root.item
            property: "opacity"
            to: 1
            duration: Theme.animNormal
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasized
        }

        NumberAnimation {
            target: root.item
            property: "scale"
            to: 1
            duration: Theme.animSlow
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeSpringBig
        }
    }
}
