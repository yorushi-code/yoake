import QtQuick

// Which alphabet the keyboard is currently typing.
//
// The bar never showed it, on a machine that types two. The launcher carries a
// whole ЙЦУКЕН-to-QWERTY table because opening it with the wrong layout was
// common enough to be worth undoing automatically — which is the shell working
// around a fact it had decided not to display.
Item {
    id: root

    implicitWidth: chip.implicitWidth
    implicitHeight: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    visible: Layout.names.length > 1

    Chip {
        id: chip
        anchors.centerIn: parent
        // Neutral: a layout is a thing that is, not a value that is doing
        // something. Colour in the bar is reserved for the second kind.
        tone: "neutral"
        live: false
        glyph: Glyphs.keyboard
        label: Layout.label
        onClicked: Layout.next()
        onScrolled: Layout.next()
    }

    Tooltip {
        anchorItem: root
        active: chip.hovered
        text: Layout.current < Layout.names.length ? Layout.names[Layout.current] : ""
        subtext: "Клик — следующая раскладка"
    }
}
