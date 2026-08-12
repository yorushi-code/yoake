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
// three meaning "the entrance the panels have".
//
// ── Why the shared part is a fade and not a fade and a grow ──
//
// A row inside a surface that scaled must not scale again. `PanelChrome` gives
// every panel a `Reveal` that grows it from `Theme.revealScale`, so a delegate
// that also grew from `Theme.revealScale` composed the two: the card began at
// 0.81 of its size, driven by two animations that owned one visual dimension
// between them and agreed about it only by luck. That is the `Reveal` defect
// one level up — one property, one owner.
//
// So the surface owns its size and a row inside it fades, and travels if it
// comes from somewhere. The toasts are the exception that proves it: their
// chrome is born `shown`, so its `Reveal` never transitions and nothing else is
// animating their size. They declare the grow themselves, below.
//
// Not `Reveal` itself, deliberately. A wrapper would add an Item and four
// Behaviors to every row of every list, and the beats it would buy are worth
// nothing here: a delegate is `ambient` by Direction's own definition — present,
// never the subject — and at that type the beats fall 15 to 42 ms apart, which
// is under the threshold at which a sequence reads as a sequence at all. The
// coherence was worth having; the layer was not.
//
// Anything declared inside runs alongside the fade, after the one wait — which
// is how a list whose items come *from* somewhere adds its travel, and how the
// toasts add their grow, without either of them adding a second clock.
SequentialAnimation {
    id: root

    // The delegate. It is expected to start at `opacity: 0`.
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
    }
}
