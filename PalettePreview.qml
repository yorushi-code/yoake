import QtQuick

// The accent, where it came from, and the other candidates found in the
// wallpaper.
//
// This exists because "the clock is cyan and there is no cyan in the image"
// was unanswerable: the accent was ANSI slot 12 with a saturate() on top, and
// nothing in the UI could have told you that. Now the measured hue and the
// confidence behind it are on screen, and any swatch can be pinned by clicking
// it.
Column {
    id: root

    property real swatchSize: 30

    spacing: 10

    Row {
        spacing: 10

        Rectangle {
            width: root.swatchSize * 1.6
            height: root.swatchSize
            radius: Theme.radius - 3
            color: Theme.accent
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.18)
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            // Explicit, so the caption elides at the panel edge instead of
            // being clipped mid-word by it.
            width: root.width - root.swatchSize * 1.6 - 10
            spacing: 2

            Text {
                width: parent.width
                text: GeneratedColors.pinned
                    ? "Акцент закреплён вручную"
                    : "Оттенок обоев " + Math.round(GeneratedColors.hue) + "°"
                color: Theme.text
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                // Naming the low-chroma case outright: on a near-monochrome
                // wallpaper a muted accent is the correct answer, not a bug.
                text: GeneratedColors.muted
                    ? "Мало цвета — акцент приглушён"
                    : "Насыщенность " + Math.round(GeneratedColors.confidence * 100) + "%"
                color: Theme.subtext0
                font.pixelSize: 11
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
        color: Qt.alpha(Theme.text, 0.10)

        Rectangle {
            width: parent.width * Math.max(0.02, GeneratedColors.confidence)
            height: parent.height
            radius: parent.radius
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }
    }

    Flow {
        width: parent.width
        spacing: 8
        visible: GeneratedColors.swatches.length > 0

        Repeater {
            model: GeneratedColors.swatches

            delegate: Rectangle {
                id: swatch
                required property var modelData

                width: root.swatchSize
                height: root.swatchSize
                radius: Theme.radius - 4
                color: swatch.modelData.hex

                // Loose: the dominant hue is a weighted mean over the whole
                // image and lands a degree or two off the peak it came from.
                readonly property bool current: Math.abs(GeneratedColors.hue - swatch.modelData.hue) < 2

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
                    cursorShape: Qt.PointingHandCursor
                    onClicked: GeneratedColors.pin(swatch.modelData.hue, swatch.modelData.chroma)
                }

                Tooltip {
                    anchorItem: swatch
                    active: swatchArea.containsMouse
                    text: Math.round(swatch.modelData.hue) + "° · "
                        + Math.round(swatch.modelData.chroma * 1000) / 10 + "% цветности"
                    subtext: "ЛКМ — закрепить как акцент"
                }
            }
        }
    }

    Text {
        text: "Вернуть цвет из обоев"
        color: resetArea.containsMouse ? Theme.accent : Theme.subtext0
        font.pixelSize: 11
        font.underline: resetArea.containsMouse
        visible: GeneratedColors.pinned
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
