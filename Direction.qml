pragma Singleton
import QtQuick

// When things happen, and in what order.
//
// Perception says what the space should be, Theme says what that looks like,
// and neither answers the question a demo reel is actually won on: in what
// order does a person experience it. A panel that changes its air, moves its
// surface, lights its accent and fills in its content on the same frame is
// correct in every value and reads as digital. The same four events spread
// across a fifth of a second read as breathing. Nothing about the tokens
// changed -- only the order did.
//
// Not downstream of Theme, despite consuming it. Theme answers "how much" and
// this answers "when"; they are orthogonal and both feed presentation. It is
// placed after Theme in the file list only because the tempo below is derived
// from the motion scale.
//
// ── Beats are fractions of the tempo, never milliseconds ──
//
// The obvious way to write this is the way it is written down in every motion
// spec: space at 0, object at +40ms, accent at +90, content at +150. That is
// correct exactly once, at one tempo. Perception now moves `motionScale`
// between 0.55 and 1.60, so at 3am `animNormal` is 352ms while a hardcoded
// +40 would still be +40 -- the content would arrive before the space had
// finished opening, and the choreography would invert itself precisely in the
// state it was designed for. Everything here is therefore relative, and a beat
// keeps its place in the sequence at every tempo the shell can reach.
QtObject {
    id: root

    // The unit. Every offset below is a fraction of it, so the whole sequence
    // stretches and compresses together.
    readonly property int tempo: Theme.animNormal

    // ── The four beats of an arrival ──
    //
    // Space first, always. A surface that moves into room that has not been
    // made yet has to shove something aside, and shoving is the difference
    // between an interface that opens and one that interrupts.
    // Convenience accessors for the narrative sequence, derived from the
    // dictionary below rather than restating its numbers -- two spellings of
    // one sequence is how a ladder becomes sixteen radii.
    //
    // The accent is third of the four, never first. It answers "where do I
    // look", and asking that before there is anything to look at is what makes
    // a shell feel like it is flashing at you.
    readonly property int beatSpace: root.beatsFor("narrative").space
    readonly property int beatObject: root.beatsFor("narrative").object
    readonly property int beatAccent: root.beatsFor("narrative").accent
    readonly property int beatContent: root.beatsFor("narrative").content

    // Silence after a move. Also relative: a fixed 250-400ms is dead air at a
    // fast tempo and an overlap at a slow one, which is the same bug as the
    // beats and worth naming twice because it is the one people re-introduce.
    readonly property int rest: Math.round(root.tempo * 1.40)

    // Per-item delay for a cascade. Lives here rather than in Theme, which the
    // contract says shall hold no timing policy beyond animation parameters --
    // a cascade is sequencing, and sequencing is this file. Capped: a
    // fifty-node VPN list staggered linearly would still be arriving a second
    // and a half after it opened, which reads as the shell being slow rather
    // than as motion.
    function stagger(index) {
        return Math.min(Math.max(0, index), 9) * Math.round(root.tempo * 0.155);
    }

    // ── Rule 8: a change across a row travels along it ──
    //
    // A stagger is a cascade of arrivals; this is something else. When ten
    // things that already exist all take a new value at once -- ten equaliser
    // bands on a preset, a device list on a new default, a grid of tiles on a
    // new profile -- doing it on one frame is a jump cut. The row is one object
    // and the change should cross it like a wave crossing a rope.
    //
    // Written as a fraction of the whole crossing rather than per item, because
    // the crossing has to take the same time whether the row is four long or
    // sixteen: what the eye follows is the light travelling, and a light that
    // takes four times as long on a longer row reads as the shell hesitating.
    //
    // The measured reference is 43 ms a band over ten bands, which is a hair
    // under two tempos for the whole sweep.
    readonly property int crossing: Math.round(root.tempo * 1.95)

    function sweep(index, count) {
        if (count <= 1) return 0;
        const at = Math.max(0, Math.min(count - 1, index));
        return Math.round(root.crossing * (at / (count - 1)));
    }

    // ── Surface types, which used to be written here as exemptions ──
    //
    // Two of the montage rules are wrong applied to everything, and both would
    // remove something the shell is better for having. Writing that down as
    // "rule 6 except cava, rule 3 except the OSD" was the wrong shape: an
    // exception is a philosophical claim that the next person has to be
    // persuaded of, and it accumulates. A type is an API, and a caller either
    // has one or does not.
    //
    // narrative      opens and tells you something. The full sequence.
    // acknowledge    answers a key you just pressed. Every beat at zero: on a
    //                volume key the accent *is* the message, and holding it
    //                back by a beat turns a keypress into lag. Theme says as
    //                much where animFlick is defined -- not the shell
    //                answering, the shell acknowledging.
    // continuous     never arrives, so it is never sequenced: cava, the bass
    //                glow, a spectrum. "Only what is in focus may move" would
    //                switch off the two things on this desktop that most read
    //                as alive, which is how a shell becomes a screenshot.
    //                Theme already carried the distinction that settles it --
    //                animFlick/Fast/Normal/Slow are the shell answering,
    //                animBusy/animBreath are a thing showing it is running.
    // ambient        present but never the subject; arrives as one soft event
    //                rather than as a sequence, because a sequence is a claim
    //                on attention and this class is not making one.
    readonly property var beats: ({
        "narrative": { space: 0.00, object: 0.20, accent: 0.45, content: 0.65 },
        "acknowledge": { space: 0.00, object: 0.00, accent: 0.00, content: 0.00 },
        "continuous": { space: 0.00, object: 0.00, accent: 0.00, content: 0.00 },
        "ambient": { space: 0.00, object: 0.12, accent: 0.12, content: 0.12 }
    })

    // Resolved against the current tempo, so a caller never sees a number and
    // cannot pin one. An unknown type falls back to narrative rather than to
    // zero: a surface that forgot to declare itself should look overdressed,
    // not instant, because the first is noticed and fixed and the second is
    // silently the old behaviour.
    function beatsFor(surfaceType) {
        const b = root.beats[surfaceType] || root.beats["narrative"];
        return {
            space: Math.round(root.tempo * b.space),
            object: Math.round(root.tempo * b.object),
            accent: Math.round(root.tempo * b.accent),
            content: Math.round(root.tempo * b.content)
        };
    }

    // Whether a type is sequenced at all. `continuous` surfaces are not
    // arrivals and must not be wrapped in one.
    function sequenced(surfaceType) {
        return surfaceType !== "continuous";
    }
}
