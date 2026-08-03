import QtQuick
import Quickshell

// The desktop widget layer: one per output, below normal windows, so the
// widgets only show on empty desktop space — wallpaper-level decoration rather
// than another always-on-top bar.
//
// This replaces DesktopClock, which was a single fixed panel in the top-right
// corner. The widgets are separate now and each one remembers where it was put.
PanelWindow {
    id: surface

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // Span the whole output including the strip the bar reserves; the widgets
    // position themselves against the full area.
    exclusiveZone: -1
    focusable: false
    aboveWindows: false

    readonly property string outputName: surface.modelData.name

    // Only what genuinely takes input. A full-output surface with no mask
    // claims the whole input region and silently eats every click on bare
    // desktop, which is what stopped menus being dismissable. In edit mode all
    // four widgets are grabbable; otherwise only the transport controls are,
    // and only when there is a player.
    mask: Region {
        Region { item: DesktopWidgets.editing ? clockWidget : null }
        Region { item: DesktopWidgets.editing ? spectrumWidget : null }
        Region { item: DesktopWidgets.editing ? statsWidget : null }
        Region { item: (DesktopWidgets.editing || Media.hasPlayer) ? mediaWidget : null }
    }

    Item {
        id: field
        anchors.fill: parent
        // Room for the bar and a comfortable page margin, so a widget dragged
        // to an edge does not end up under the island or flush with the bezel.
        anchors.topMargin: Theme.barHeight + Theme.barMargin * 3
        anchors.leftMargin: 46
        anchors.rightMargin: 46
        anchors.bottomMargin: 46

        DesktopWidget {
            id: clockWidget
            name: "clock"
            screenName: surface.outputName
            defaultX: 1.0
            defaultY: 0.0

            WidgetClock {}
        }

        DesktopWidget {
            id: spectrumWidget
            name: "spectrum"
            screenName: surface.outputName
            defaultX: 1.0
            defaultY: 0.22

            WidgetSpectrum {}
        }

        DesktopWidget {
            id: statsWidget
            name: "stats"
            screenName: surface.outputName
            defaultX: 1.0
            defaultY: 0.32

            WidgetStats {}
        }

        DesktopWidget {
            id: mediaWidget
            name: "media"
            screenName: surface.outputName
            defaultX: 1.0
            defaultY: 0.44
            visible: Media.hasPlayer || DesktopWidgets.editing
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

            WidgetMedia {
                // The glass samples the wallpaper at its real position, and the
                // widget can be anywhere now.
                screenX: field.x + mediaWidget.x
                screenY: field.y + mediaWidget.y
            }
        }
    }

    // A hint while editing, so the mode is not something the user has to
    // remember they turned on.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        width: hint.width + 28
        height: 32
        radius: Theme.radiusCard
        color: Qt.alpha(Theme.crust, 0.9)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.5)
        opacity: DesktopWidgets.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

        Text {
            id: hint
            anchors.centerIn: parent
            text: "Перетащите виджеты · Mod+Shift+E — готово"
            color: Theme.text
            font.pixelSize: 11
        }
    }
}
