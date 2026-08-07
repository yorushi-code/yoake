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
            spacing: Theme.gapWide

            Repeater {
                model: root.desks

                delegate: DashCard {
                    id: card
                    required property var modelData
                    required property int index

                    readonly property var windows: Niri.windows
                        .filter(w => w.workspace_id === card.modelData.id)

                    width: column.width
                    height: 72
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
                        font.pixelSize: Theme.fontDisplay
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }

                    // What is actually in front on that desk. Six icons tell
                    // you a terminal is there; they do not tell you which one,
                    // and that is the thing you are looking for when you open
                    // this page at all.
                    //
                    // Set beside the number, not against the far edge. It was
                    // right-aligned across the whole card, which on a desk with
                    // one window left six hundred pixels of nothing between the
                    // icon and its own label — two things that are the same
                    // thing, reading as two columns of an empty table.
                    Text {
                        id: focusedTitle
                        anchors.left: number.right
                        anchors.leftMargin: Theme.gapSection
                        anchors.right: icons.left
                        anchors.rightMargin: Theme.gapCard
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (card.windows.length === 0) return "пусто";
                            const focused = card.windows.find(w => w.is_focused);
                            const w = focused || card.windows[0];
                            return w ? (w.title || w.app_id || "") : "";
                        }
                        color: card.windows.length === 0
                            ? Qt.alpha(Theme.subtext0, 0.6)
                            : (card.modelData.is_focused ? Theme.text : Theme.subtext1)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                    }

                    Row {
                        id: icons
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.gapCard
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing

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
                                    // Through the desktop entry, not straight
                                    // from the app_id. They are usually the
                                    // same string, which is why this worked at
                                    // all -- but an app_id is a window class
                                    // and an icon name is an icon name, and
                                    // Firefox is org.mozilla.firefox in the one
                                    // and firefox in the other. Every window it
                                    // owned drew nothing and logged a failure.
                                    source: {
                                        const id = entry.modelData.app_id || "";
                                        const app = id ? DesktopEntries.byId(id) : null;
                                        const name = app && app.icon ? app.icon : id;
                                        return Icons.forName(name);
                                    }
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
