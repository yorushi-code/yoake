import QtQuick
import Quickshell.Io

// What the machine is busy with, shown only while it is busy.
//
// The vision this came from asks the shell to expand its performance widgets
// under load. Doing that by changing how the shell *looks* -- darker, faster,
// sharper -- would redesign the interface at the exact moment the user needs it
// to hold still, and would spend frames on mood while the machine is already
// short of them. So the reaction is information instead: the numbers that are
// normally on a dashboard page appear in the bar for as long as they are the
// answer to a question you are actually asking, and then leave.
//
// Collapsed to zero width rather than hidden, so the island closes over the gap
// the same way it does when the music stops.
Item {
    id: root

    property var barWindow: null

    readonly property bool showing: Context.loaded

    // Collected here rather than in SysInfo, and only while the readout is on
    // screen. SysInfo cannot ask Context whether the machine is busy without
    // the two importing each other, and a `ps` every two seconds for a line
    // nobody is looking at is exactly the kind of cost this shell has spent the
    // night removing.
    property var topProcesses: []

    Timer {
        interval: 2000
        running: root.showing
        repeat: true
        triggeredOnStart: true
        onTriggered: procs.running = true
    }

    Process {
        id: procs
        // Three is what fits the card without it becoming a task manager.
        command: ["sh", "-c",
            "ps -eo comm=,pcpu= --sort=-pcpu | head -3"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.trim().split("\n")) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 2) continue;
                    out.push({ name: parts[0], cpu: parts[1] });
                }
                root.topProcesses = out;
            }
        }
    }

    onShowingChanged: if (!root.showing) root.topProcesses = [];

    implicitWidth: loadRow.width
    width: implicitWidth
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    visible: width > 0

    Row {
        id: loadRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing
        width: root.showing ? implicitWidth : 0
        opacity: root.showing ? 1 : 0
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasized
            }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Glyphs.speedometer
            font.family: Theme.fontIconFamily
            font.pixelSize: Theme.fontIconMicro
            // Yellow rather than red: this is the shell noticing, not warning.
            // Red is for the battery that is about to die.
            color: Theme.yellow
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(SysInfo.cpu * 100) + "%"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.features: ({ "tnum": 1 })
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: SysInfo.temperature > 0
            text: SysInfo.temperature + "°"
            color: SysInfo.temperature >= 85 ? Theme.red : Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.features: ({ "tnum": 1 })
        }
    }

    MouseArea {
        id: loadArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Toggles.dash("system")
    }

    // The card says which processes, because "the machine is busy" without a
    // culprit is the least useful true statement a shell can make.
    Popover {
        anchorItem: root
        hovered: loadArea.containsMouse
        minWidth: 240

        Column {
            spacing: Theme.gapWide

            Row {
                spacing: Theme.gapWide

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Glyphs.speedometer
                    font.family: Theme.fontIconFamily
                    font.pixelSize: Theme.fontIcon
                    color: Theme.yellow
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Машина занята"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.Medium
                }
            }

            Column {
                spacing: Theme.gapTight

                Repeater {
                    model: root.topProcesses

                    delegate: Row {
                        id: procRow
                        required property var modelData
                        width: 220
                        spacing: Theme.spacing

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - share.width - Theme.spacing
                            text: procRow.modelData.name
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }

                        Text {
                            id: share
                            anchors.verticalCenter: parent.verticalCenter
                            text: procRow.modelData.cpu + "%"
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }

            Text {
                text: "ЛКМ — страница «Система»"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMicro
            }
        }
    }
}
