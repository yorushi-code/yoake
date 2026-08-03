import QtQuick

// Two-level navigation inside one panel.
//
// A tile's detail — the network list, the paired devices, the palette — used to
// expand inline, which pushed everything below it off the bottom and left the
// user scrolling to find the row they had just clicked. Here the detail slides
// in over the panel as a page with its own title and a way back, so the panel
// never changes height and there is never a second window.
Item {
    id: root

    // Empty means the main page. The owner sets both this and `pageComponent`.
    property string page: ""
    property string title: ""
    property Component pageComponent: null

    default property alias content: mainSlot.children

    // Not "onPage": a property whose name begins with "on" collides with
    // the change-handler name of the property it is derived from —
    // `onPageChanged` is both `page`'s handler and `onPage`'s notifier, and
    // the binding silently never re-evaluated.
    readonly property bool showingPage: root.page !== ""

    signal back()

    clip: true

    Item {
        id: mainSlot
        anchors.fill: parent
        // Drifts rather than sliding fully out: the page is what the eye should
        // follow, and a main view that leaves at the same speed reads as two
        // things moving past each other.
        x: root.showingPage ? -root.width * 0.22 : 0
        opacity: root.showingPage ? 0 : 1
        visible: opacity > 0
        Behavior on x {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasized
            }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    Item {
        id: pageSlot
        anchors.fill: parent
        x: root.showingPage ? 0 : root.width
        opacity: root.showingPage ? 1 : 0
        visible: opacity > 0
        Behavior on x {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasized
            }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30

            Rectangle {
                id: backButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: Theme.radiusChip
                color: backArea.containsMouse ? Qt.alpha(Theme.text, Theme.strokeFirm) : Qt.alpha(Theme.text, 0.07)
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: Glyphs.chevronLeft
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: Theme.fontIconMicro
                    color: Theme.text
                }

                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Text {
                anchors.left: backButton.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                color: Theme.text
                font.pixelSize: Theme.fontTitle
                font.bold: true
                elide: Text.ElideRight
            }
        }

        // Destroyed on the way out, so a network scan or a device list is not
        // kept alive behind a page nobody is looking at.
        Loader {
            anchors.top: header.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            active: root.showingPage
            sourceComponent: root.pageComponent
        }
    }
}
