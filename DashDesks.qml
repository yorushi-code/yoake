import QtQuick
import Quickshell
import Quickshell.Widgets

// Every desk and what is on it.
//
// niri's own overview shows this by scaling the real windows down, which is
// better at telling you where things are and useless at telling you what is
// where — at that size a terminal and an editor are the same grey rectangle.
// Names and icons instead, always legible, and clicking a desk goes there.
Item {
    id: root

    readonly property var desks: Niri.workspaces
        .slice()
        .sort((a, b) => a.idx - b.idx)

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width
            spacing: 12

            Repeater {
                model: root.desks

                delegate: DashCard {
                    id: card
                    required property var modelData
                    required property int index

                    readonly property var windows: Niri.windows
                        .filter(w => w.workspace_id === card.modelData.id)

                    width: column.width
                    height: 84
                    interactive: true
                    onActivated: {
                        Niri.focusWorkspace(card.modelData.idx);
                        Toggles.dashboardOpen = false;
                    }

                    // The focused desk is marked the same way it is in the bar,
                    // so the two readings agree.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: Theme.accent
                        visible: card.modelData.is_focused
                    }

                    Text {
                        id: number
                        anchors.left: parent.left
                        anchors.leftMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.modelData.idx
                        color: card.modelData.is_focused ? Theme.accent : Theme.subtext0
                        font.family: Theme.fontDisplayFamily
                        font.pixelSize: 26
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }

                    Text {
                        anchors.left: number.right
                        anchors.leftMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.windows.length === 0
                        text: "пусто"
                        color: Qt.alpha(Theme.subtext0, 0.6)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }

                    // What is actually in front on that desk. Six icons tell
                    // you a terminal is there; they do not tell you which one,
                    // and that is the thing you are looking for when you open
                    // this page at all.
                    Text {
                        id: focusedTitle
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - number.width - icons.width - 120)
                        horizontalAlignment: Text.AlignRight
                        visible: text !== ""
                        text: {
                            const focused = card.windows.find(w => w.is_focused);
                            const w = focused || card.windows[0];
                            return w ? (w.title || w.app_id || "") : "";
                        }
                        color: card.modelData.is_focused ? Theme.subtext1 : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                    }

                    Row {
                        id: icons
                        anchors.left: number.right
                        anchors.leftMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Repeater {
                            // Six is what fits; the count beside them carries the
                            // rest rather than letting the row overflow.
                            model: card.windows.slice(0, 6)

                            delegate: Item {
                                id: entry
                                required property var modelData
                                width: 40
                                height: 40

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 28
                                    source: Quickshell.iconPath(entry.modelData.app_id,
                                                                "application-x-executable")
                                    opacity: entry.modelData.is_focused ? 1 : 0.72
                                }

                                Tooltip {
                                    anchorItem: entry
                                    active: hover.containsMouse
                                    text: entry.modelData.title || entry.modelData.app_id || ""
                                    subtext: entry.modelData.app_id || ""
                                }

                                // Clicking the window goes to the window, not
                                // merely to the desk it is on. The tooltip
                                // already names it, so the row was one step
                                // short of being useful.
                                MouseArea {
                                    id: hover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Niri.focusWindow(entry.modelData.id);
                                        Toggles.dashboardOpen = false;
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: card.windows.length > 6
                            text: "+" + (card.windows.length - 6)
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }
        }
    }
}
