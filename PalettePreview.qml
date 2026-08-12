import QtQuick

// The accent, where it came from, and the other candidates found in the image.
//
// This exists because "the clock is cyan and there is no cyan in the wallpaper"
// was unanswerable: the accent was ANSI slot 12 with a saturate() on top, and
// nothing in the UI could have told you that. Now the measured hue and the
// confidence behind it are on screen.
//
// With `probe` set it describes a palette that is not in force yet — what the
// shell would look like after applying that wallpaper. Pinning is only offered
// for the live palette: a pin belongs to the image it was chosen against, and
// wallpaper-palette.py drops it on the next wallpaper change anyway.
Column {
    id: root

    property real swatchSize: 30
    property var probe: null

    readonly property bool live: root.probe === null

    // Each of these tests `probe` itself rather than the derived `live`: QML
    // does not promise the two bindings are re-evaluated in the same pass, and
    // one frame of `live === false` with a null probe is a TypeError.
    readonly property color accentColor: root.probe ? root.probe.accent : Theme.accent
    readonly property real hue: root.probe
        ? ((root.probe.meta && root.probe.meta.hue) || 0)
        : GeneratedColors.hue
    readonly property real confidence: root.probe
        ? ((root.probe.meta && root.probe.meta.confidence) || 0)
        : GeneratedColors.confidence
    readonly property bool muted: root.probe
        ? (root.probe.meta && root.probe.meta.muted === true)
        : GeneratedColors.muted
    readonly property var swatches: root.probe
        ? ((root.probe.meta && root.probe.meta.swatches) || [])
        : GeneratedColors.swatches

    spacing: Theme.gapWide

    Row {
        spacing: Theme.gapWide

        Rectangle {
            width: root.swatchSize * 1.6
            height: root.swatchSize
            radius: Theme.radius - 3
            color: root.accentColor
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.text, Theme.strokeFirm)
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            // Explicit, so the caption elides at the panel edge instead of
            // being clipped mid-word by it.
            width: root.width - root.swatchSize * 1.6 - 10
            spacing: Theme.gapPair

            Text {
                width: parent.width
                text: {
                    if (!root.live) return "Станет оттенком " + Math.round(root.hue) + "°";
                    if (GeneratedColors.pinned) return "Акцент закреплён вручную";
                    return "Оттенок обоев " + Math.round(root.hue) + "°";
                }
                color: Theme.text
                font.pixelSize: Theme.fontBody
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                // Naming the low-chroma case outright: on a near-monochrome
                // wallpaper a muted accent is the correct answer, not a bug.
                text: root.muted
                    ? "Мало цвета — акцент приглушён"
                    : "Насыщенность " + Math.round(root.confidence * 100) + "%"
                color: Theme.subtext0
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }
    }

    // Confidence read as a bar, so "muted" is visibly a measurement rather
    // than an opinion.
    Rectangle {
        width: parent.width
        height: 3
        radius: 1.5
        color: Qt.alpha(Theme.text, Theme.fillMuted)

        Rectangle {
            width: parent.width * Math.max(0.02, root.confidence)
            height: parent.height
            radius: parent.radius
            color: root.accentColor
            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }
    }

    Flow {
        width: parent.width
        spacing: 8
        // Two or more, because the strip's job is to offer the alternatives.
        // On a wallpaper that is genuinely one broad hue the analysis returns a
        // single candidate, which is the accent already shown above it, and the
        // strip became one small square with a card's width of nothing beside
        // it -- a hole that looked like a failure to load rather than an answer.
        visible: root.swatches.length > 1

        Repeater {
            model: root.swatches

            delegate: Rectangle {
                id: swatch
                required property var modelData

                width: root.swatchSize
                height: root.swatchSize
                radius: Theme.radius - 4
                color: swatch.modelData.hex

                // Loose: the dominant hue is a weighted mean over the whole
                // image and lands a degree or two off the peak it came from.
                readonly property bool current: Math.abs(root.hue - swatch.modelData.hue) < 2

                scale: swatchArea.containsMouse ? 1.12 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animFast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeSpring
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: parent.radius + 3
                    color: "transparent"
                    border.width: 2
                    border.color: swatch.current ? Theme.text : "transparent"
                    opacity: swatch.current ? 0.7 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                }

                MouseArea {
                    id: swatchArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: GeneratedColors.pin(swatch.modelData.hue, swatch.modelData.chroma)
                }

                Tooltip {
                    anchorItem: swatch
                    active: swatchArea.containsMouse
                    text: Math.round(swatch.modelData.hue) + "° · "
                        + Math.round(swatch.modelData.chroma * 1000) / 10 + "% цветности"
                    subtext: root.live ? "ЛКМ — закрепить как акцент" : "Кандидат в акценты"
                }
            }
        }
    }

    Text {
        text: "Вернуть цвет из обоев"
        color: resetArea.containsMouse ? Theme.accent : Theme.subtext0
        font.pixelSize: Theme.fontSmall
        font.underline: resetArea.containsMouse
        visible: root.live && GeneratedColors.pinned
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        MouseArea {
            id: resetArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: GeneratedColors.unpin()
        }
    }
}
