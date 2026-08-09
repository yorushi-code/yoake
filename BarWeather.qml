import QtQuick

// The temperature outside, in the bar.
//
// It was in the dashboard, which is to say it was somewhere you go and look
// rather than something you know. Weather is the cheapest possible example of
// what this pass is about: one number that is worth a permanent two centimetres
// of screen, and it was behind a keystroke.
Item {
    id: root

    implicitWidth: chip.implicitWidth
    implicitHeight: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    visible: Weather.valid

    Chip {
        id: chip
        anchors.centerIn: parent
        // Neutral rather than a domain colour. The bar can hold about five live
        // colours before the distinction between "doing something" and "simply
        // true" stops being made, and the weather is the least urgent of them.
        tone: "neutral"
        live: false
        glyph: Weather.glyph
        value: Math.round(Weather.temperature * 10) / 10 + "°"
        // The dashboard's overview still carries the forecast until
        // WeatherPanel is built; an empty sheet would be a dead click.
        onClicked: Toggles.dash("overview")
        onRightClicked: Weather.refresh()
    }

    Tooltip {
        anchorItem: root
        active: false
        text: Weather.summary
        subtext: Weather.place
    }
}
