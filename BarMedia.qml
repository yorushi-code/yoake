import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Now-playing half of the centre island: mini spectrum plus track title, with
// transport on click/scroll. Right-click is where a second player can be
// picked — until now the shell silently decided for you (first one playing),
// with no way to say otherwise while both were paused.
Item {
    id: root

    property var barWindow: null
    // Scoped to the output so the same widget on a second monitor
    // does not share one open-menu key with this one.
    readonly property string menuId: Menus.idFor(root.barWindow, "media")

    width: mediaRow.width
    height: Theme.barHeight

    // Visible when there is something to show, **not** when the row has come out
    // wider than zero. Those read as the same test and the second is a deadlock:
    // the row's width comes from the title's `implicitWidth`, and Qt does not lay
    // text out inside an invisible subtree — so a chip that starts hidden,
    // because the shell reached this line before MPRIS had answered, never
    // measures the title it is later handed, never gains a width, and so never
    // becomes visible. It is hidden *because* it is hidden.
    //
    // That is every login. Measured on a cold start with a player already
    // playing: `hasPlayer` true, `title` 34 characters, `contentWidth` **0**,
    // `visible` false — and still false minutes later. It survived this long
    // because editing any file in this directory cures it: a reload builds the
    // chip with `Media` already populated, so the text is laid out once before
    // the guard can hide it. Nobody who works on the shell ever sees the state a
    // login leaves it in.
    //
    // `Cava.active` is here because the spectrum is the row's other occupant and
    // can be the only one.
    visible: Media.hasPlayer || Cava.active || root.width > 0

    Row {
        id: mediaRow
        anchors.centerIn: parent
        spacing: Theme.gapWide

        // Spectrum collapses to zero width when nothing is playing rather than
        // leaving a dead gap in the island.
        Row {
            id: miniViz
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: Cava.active ? implicitWidth : 0
            opacity: Cava.active ? 1 : 0
            // `Cava.active` first for the reason the title carries below; the
            // width term stays so the collapse animation is not cut off.
            visible: Cava.active || width > 0
            clip: true
            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

            Repeater {
                model: 14
                delegate: Item {
                    required property int index
                    // Sampling every other band spreads 28 cava bands across 14
                    // visible bars, so the mini view still covers the full
                    // spectrum, not only the bass end.
                    readonly property real level: Cava.values[index * 2] || 0
                    readonly property real peak: Cava.peaks[index * 2] || 0
                    width: 2
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: parent.width
                        height: Math.max(2, parent.level * 16)
                        radius: 1
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.accent
                        opacity: 0.55 + parent.level * 0.45
                        // No Behavior: Cava smooths the fall itself, once per
                        // frame for the whole band set, instead of restarting one
                        // animation per bar per frame.
                    }

                    // Peak marker: a transient that would otherwise be gone by
                    // the next frame leaves a line that sinks back down.
                    Rectangle {
                        width: parent.width
                        height: 1.5
                        radius: 0.75
                        color: Theme.text
                        opacity: parent.peak > parent.level + 0.04 ? 0.75 : 0
                        y: (parent.height - Math.max(2, parent.peak * 16)) / 2
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }
                }
            }
        }

        // The title's natural width, measured off the layout entirely.
        //
        // It used to be `Math.min(implicitWidth, 190)` read off the Text itself,
        // which is the usual idiom and is a latch here. The width is bound to the
        // measurement and the measurement is taken from the thing being sized: if
        // the width is ever 0 when the text arrives — and it is, at every login,
        // because the chip is built before MPRIS answers — the elide fits the
        // string into no pixels, `implicitWidth` reports 0 for a string that is
        // there, and the binding has no way back. Measured side by side on a cold
        // start: this element 230.78, the Text 0, same string, same font.
        //
        // `TextMetrics` is not in the layout, so nothing can starve it.
        TextMetrics {
            id: trackMetrics
            font: trackText.font
            text: trackText.text
        }

        Text {
            id: trackText
            anchors.verticalCenter: parent.verticalCenter
            // Gated on the text alone, not on Cava.active: tying it to live
            // audio levels made the title flicker away during quiet passages
            // and between tracks.
            width: text.length > 0 ? Math.min(trackMetrics.width, 190) : 0
            // **This** is where the deadlock was. `visible: width > 0` alone,
            // against a width that comes from `implicitWidth`, cannot recover
            // from starting empty: Qt does not lay text out inside an invisible
            // item, so the title handed over a moment later is never measured,
            // the width stays 0 and the item stays invisible. Leading with the
            // text breaks it; the width term stays so the collapse still plays.
            visible: text.length > 0 || width > 0
            clip: true
            elide: Text.ElideRight
            text: {
                if (!Media.hasPlayer) return "";
                return Media.artist ? `${Media.artist} — ${Media.title}` : Media.title;
            }
            color: mediaArea.containsMouse ? Theme.text : Theme.subtext1
            // Named, like every other label in the bar. This was the only one
            // that let the family default, and the default is resolved by the
            // GTK platform theme — which is not settled at process start. A Text
            // whose family has not resolved measures zero, and a zero here is
            // load-bearing: the width comes from `implicitWidth`. That is the
            // rest of the cold-start fault, and it was visible all along without
            // being noticed, because the track title was the one proportional
            // thing on a bar that is monospace everywhere else.
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            // A track change was the one thing in the bar that swapped with no
            // motion at all. A dip and rise on the incoming title is enough to
            // register as "this just changed" — a true crossfade would need a
            // second label to hold the outgoing text, which is more machinery
            // than eleven pixels of type is worth.
            onTextChanged: if (trackText.text.length > 0) trackSwap.restart()
            SequentialAnimation {
                id: trackSwap
                NumberAnimation {
                    target: trackText; property: "opacity"; to: 0.2
                    duration: Theme.animFast; easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: trackText; property: "opacity"; to: 1
                    duration: Theme.animNormal
                    easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized
                }
            }
            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
            }
        }
    }

    MouseArea {
        id: mediaArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: Media.hasPlayer
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Menus.toggle(root.menuId);
            } else if (mouse.button === Qt.MiddleButton) {
                Media.next();
            } else {
                Media.togglePlay();
            }
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) Media.previous();
            else Media.next();
        }
    }

    ActionMenu {
        id: menu
        menuId: root.menuId
        anchorItem: root
        open: Menus.isOpen(root.menuId)
        model: {
            if (!Menus.isOpen(root.menuId)) return [];
            const out = [];
            const players = Mpris.players.values;
            if (players.length > 1) {
                for (const p of players) {
                    out.push({
                        text: p.identity || p.dbusName,
                        checkable: true,
                        checked: Media.player === p,
                        action: () => Media.pin(p)
                    });
                }
                out.push({ separator: true });
            }
            const p = Media.player;
            if (p && p.shuffleSupported) {
                out.push({
                    text: "Перемешивание",
                    glyph: p.shuffle ? Glyphs.shuffle : Glyphs.shuffleOff,
                    checkable: true,
                    checked: p.shuffle === true,
                    action: () => p.shuffle = !p.shuffle
                });
            }
            if (p && p.loopSupported) {
                const states = [
                    { label: "Без повтора", value: MprisLoopState.None, glyph: Glyphs.repeatOff },
                    { label: "Повтор трека", value: MprisLoopState.Track, glyph: Glyphs.repeatOne },
                    { label: "Повтор списка", value: MprisLoopState.Playlist, glyph: Glyphs.repeatAll }
                ];
                for (const s of states) {
                    out.push({
                        text: s.label,
                        glyph: s.glyph,
                        checkable: true,
                        checked: p.loopState === s.value,
                        action: () => p.loopState = s.value
                    });
                }
            }
            if (out.length > 0) out.push({ separator: true });
            // Always available, unlike everything above it. A player that
            // supports neither shuffle nor loop and is the only one running --
            // which is every browser -- left this menu with a single item, and
            // a one-item menu is not worth the right-click it costs.
            out.push({
                text: "Скопировать название",
                glyph: Glyphs.copy,
                enabled: Media.title !== "",
                action: () => {
                    Quickshell.clipboardText = Media.artist !== ""
                        ? Media.artist + " — " + Media.title
                        : Media.title;
                }
            });
            out.push({
                text: "Открыть плеер",
                glyph: Glyphs.openExternal,
                enabled: p !== null && p.canRaise,
                action: () => { if (p) p.raise(); }
            });
            return out;
        }
    }

    Tooltip {
        anchorItem: root
        active: mediaArea.containsMouse && Media.hasPlayer && !Menus.isOpen(root.menuId)
        text: Media.title
        subtext: "ЛКМ — пауза · колесо — трек · ПКМ — плеер"
    }
}
