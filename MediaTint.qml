pragma Singleton
import QtQuick
import Quickshell

// The colour of whatever is playing.
//
// Every other surface in the shell takes its accent from the wallpaper, which
// is right: the wallpaper is what the desktop is. But the player is not about
// the desktop, it is about one record, and a record has a colour of its own —
// so the transport, the ring, the wave and the glow all move to the sleeve and
// move again on the next track. Nothing else in the shell changes colour while
// you watch, which is exactly why this reads as the music arriving rather than
// as a theme switch.
//
// Chosen rather than averaged. The mean of a sleeve is mud; what the eye
// remembers is the most saturated thing on it that is still light enough to
// draw a line with.
Singleton {
    id: root

    // Falls back to the shell accent, so a track with no art or an unusable
    // sleeve looks deliberate instead of looking broken.
    readonly property color fallback: Theme.accent

    // Animated, and that is the whole point: the recolour has to be something
    // you watch happen. Slow enough to read as the record arriving, fast
    // enough that it is over before the first chorus.
    property color accent: root.fallback
    Behavior on accent {
        ColorAnimation { duration: Theme.animArrive; easing.type: Easing.InOutQuad }
    }

    // A second colour for gradients, pulled from a different part of the
    // sleeve where there is one and derived where there isn't.
    property color accentAlt: root.fallback
    Behavior on accentAlt {
        ColorAnimation { duration: Theme.animArrive; easing.type: Easing.InOutQuad }
    }

    readonly property bool derived: root.accent !== root.fallback

    ColorQuantizer {
        id: quantizer
        // Only a file. Anything else is handed nothing.
        //
        // This used to exclude `image://` handles by name, having learned that
        // the quantizer failed on every one of them while the same source drew
        // fine as an `Image` -- it reads files, not QML image providers. The
        // lesson was right and was not generalised: a `data:image/jpeg;base64`
        // URL is not a file either, some players publish one as their art, and
        // the failure prints **the entire payload** as a warning. Four kilobytes
        // per track change into a log that holds about five hundred lines, which
        // wipes out the whole diagnostic history -- twice tonight, while chasing
        // something else.
        //
        // Written as what is allowed rather than as what is not, so the next
        // scheme nobody has thought of fails closed instead of loudly.
        source: /^(file:|\/)/.test(Media.cover) ? Media.cover : ""
        // Sixteen buckets: enough that a sleeve with one bright detail on a
        // dark field still surfaces the detail, few enough that the pass is
        // cheap and runs once per track.
        depth: 4
        rescaleSize: 64

        onColorsChanged: {
            stale.stop();
            root._pick(quantizer.colors);
        }
    }

    // A cover that never resolves leaves the previous record's colour on screen.
    //
    // The art can be an image://qsimage handle owned by a notification, and the
    // quantizer has been seen to fail on one -- "Failed to load image from
    // image://qsimage/4/1" in the log, while the same source drew fine as an
    // Image. A failure emits nothing at all, so without this the tint simply
    // keeps whatever the last sleeve gave it, which is worse than no tint: it
    // says something confident and wrong about the track now playing.
    Timer {
        id: stale
        interval: 1500
        onTriggered: root._reset()
    }

    // Art can vanish mid-track — a notification's image handle dies with the
    // notification — and a stale sleeve colour on the next track is worse than
    // no sleeve colour at all.
    Connections {
        target: Media
        function onCoverChanged() {
            if (Media.cover === "") {
                stale.stop();
                root._reset();
            } else {
                stale.restart();
            }
        }
    }

    function _reset() {
        root.accent = root.fallback;
        root.accentAlt = root.fallback;
    }

    // Usable on a dark card: saturated enough to read as a colour rather than
    // as grey, and light enough to sit type and hairlines in.
    function _score(c) {
        const s = c.hslSaturation;
        const l = c.hslLightness;
        if (l < 0.18 || l > 0.92) return -1;
        if (s < 0.12) return -1;
        // Lightness is scored towards 0.62 rather than maximised, and weighted
        // three to one against saturation: the brightest colour on a sleeve is
        // usually a white highlight, which is not the record's colour and
        // cannot be told apart from plain text. At a gentler weight the
        // highlight wins on saturation alone -- on a purple sleeve it picked a
        // near-white lavender over the mid purple the sleeve is actually made
        // of.
        return s * 2 - Math.abs(l - 0.62) * 3;
    }

    function _lift(c) {
        // Held inside a band whatever the sleeve does, so a very dark or a very
        // pale record still produces a mark that can be seen on the card.
        const l = Math.max(0.58, Math.min(0.78, c.hslLightness));
        const s = Math.max(0.42, Math.min(0.95, c.hslSaturation));
        return Qt.hsla(c.hslHue, s, l, 1);
    }

    function _pick(colors) {
        if (!colors || colors.length === 0) {
            root._reset();
            return;
        }

        const ranked = [];
        for (const c of colors) {
            const score = root._score(c);
            if (score > 0) ranked.push({ color: c, score: score });
        }
        if (ranked.length === 0) {
            root._reset();
            return;
        }
        ranked.sort((a, b) => b.score - a.score);

        const best = ranked[0].color;
        root.accent = root._lift(best);

        // The companion is the best-scoring colour that is not a near-neighbour
        // of the first. Two shades of the same hue make a gradient that reads
        // as a rendering artefact rather than as two colours.
        for (let i = 1; i < ranked.length; i++) {
            const hue = ranked[i].color.hslHue;
            let delta = Math.abs(hue - best.hslHue);
            if (delta > 0.5) delta = 1 - delta;
            if (delta > 0.06) {
                root.accentAlt = root._lift(ranked[i].color);
                return;
            }
        }
        // One-colour sleeve: walk the hue rather than inventing a second one.
        root.accentAlt = Qt.hsla((best.hslHue + 0.08) % 1,
                                 Math.max(0.42, Math.min(0.95, best.hslSaturation)),
                                 Math.max(0.58, Math.min(0.78, best.hslLightness * 1.06)),
                                 1);
    }
}
