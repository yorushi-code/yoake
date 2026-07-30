import QtQuick
import Quickshell

// Time and date, sized to its own content so it can be dragged anywhere.
//
// Deliberately unadorned. Two earlier attempts at a glow both showed up as a
// visible rectangle behind the digits: a RectangularShadow draws an actual
// rounded box, and a blurred layer plus MultiEffect leaves a haze the size of
// the layer's texture bounds. The digits carry enough weight on their own.
Column {
    id: root

    spacing: 6

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: true
    }

    Item {
        id: timeGroup
        width: hhmm.width + 8 + secondsText.width
        height: hhmm.height

        Text {
            id: hhmm
            anchors.left: parent.left
            textFormat: Text.RichText
            text: {
                const hh = Qt.formatDateTime(clock.date, "hh");
                const mm = Qt.formatDateTime(clock.date, "mm");
                return `<span style="color:${Theme.text}">${hh}</span>`
                     + `<span style="color:${Theme.accent}">:${mm}</span>`;
            }
            font.pixelSize: 96
            font.bold: true
            font.letterSpacing: -2
        }

        // A separate element rather than an inline span: mixing font sizes
        // inside one RichText made the seconds sit awkwardly against the big
        // digits. Baseline anchoring lines them up whatever the sizes.
        Text {
            id: secondsText
            anchors.left: hhmm.right
            anchors.leftMargin: 8
            anchors.baseline: hhmm.baseline
            text: Qt.formatDateTime(clock.date, "ss")
            color: Theme.subtext1
            font.pixelSize: 34
            font.bold: true
        }
    }

    Text {
        anchors.right: timeGroup.right
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM").toUpperCase()
        color: Theme.subtext1
        font.pixelSize: 13
        font.letterSpacing: 3
        opacity: 0.85
    }
}
