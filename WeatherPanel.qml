import QtQuick
import Quickshell
import Quickshell.Wayland

// The forecast, from the chip that shows the temperature.
//
// The weather lived in a dashboard tab, which is to say it was somewhere you go
// and look rather than something you know. One number earned its way into the
// bar; the rest of the answer -- whether to take a coat, whether it will rain
// this afternoon -- belongs one click behind it and nowhere else.
PanelWindow {
    id: win

    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool open: Toggles.weatherPanelOpen && win.armed
    property bool armed: false
    property Timer _armTick: Timer {
        interval: 16
        running: true
        onTriggered: win.armed = true
    }

    property bool mapped: false
    visible: mapped

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    focusable: Toggles.weatherPanelOpen
    WlrLayershell.keyboardFocus: Toggles.weatherPanelOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    Timer {
        id: hideDelay
        interval: Theme.animExit + 60
        onTriggered: win.mapped = false
    }

    Connections {
        target: Toggles
        function onWeatherPanelOpenChanged() {
            if (Toggles.weatherPanelOpen) {
                hideDelay.stop();
                win.mapped = true;
            } else {
                hideDelay.restart();
            }
        }
    }
    Component.onCompleted: win.mapped = Toggles.weatherPanelOpen

    MouseArea {
        anchors.fill: parent
        onClicked: Toggles.weatherPanelOpen = false
    }

    Item {
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Toggles.weatherPanelOpen = false

        Sheet {
            id: sheet
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
            width: 520
            height: column.implicitHeight + Theme.sheetPad * 2
            // Centred, because the chip it belongs to is in the middle of the
            // strip and a sheet has to come from where it was asked for.
            align: "centre"
            shown: win.open
            onCloseRequested: Toggles.weatherPanelOpen = false

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Column {
                id: column
                anchors.fill: parent
                anchors.margins: Theme.sheetPad
                spacing: Theme.gapCard

                Row {
                    width: parent.width
                    spacing: Theme.gapCard

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Weather.glyph
                        size: Theme.fontIconHero
                        fill: 1
                        color: Theme.text
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: Math.round(Weather.temperature) + "°"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHero
                            font.weight: Font.DemiBold
                            font.features: ({ "tnum": 1 })
                        }

                        Text {
                            text: Weather.summary
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }

                        Text {
                            text: Weather.place
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontMicro
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.gapTight

                    KeyValue {
                        width: parent.width
                        key: "Ощущается"
                        value: Math.round(Weather.feelsLike) + "°"
                    }
                    KeyValue {
                        width: parent.width
                        key: "Ветер"
                        value: Math.round(Weather.wind) + " км/ч"
                    }
                    KeyValue {
                        width: parent.width
                        key: "Влажность"
                        value: Weather.humidity + "%"
                    }
                }

                // ── Ближайшие часы ──
                Row {
                    width: parent.width
                    spacing: Theme.spacing
                    visible: Weather.hourly.length > 0

                    Repeater {
                        model: Weather.hourly.slice(0, 8)

                        delegate: Column {
                            id: hourCell
                            required property var modelData
                            required property int index

                            width: (parent.width - Theme.spacing * 7) / 8
                            spacing: Theme.gapTight

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: hourCell.modelData.hour
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontMicro
                                font.features: ({ "tnum": 1 })
                            }

                            MaterialSymbol {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: Weather.glyphFor(hourCell.modelData.code, hourCell.modelData.day)
                                size: Theme.fontIconSmall
                                color: Theme.subtext1
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Math.round(hourCell.modelData.temp) + "°"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.features: ({ "tnum": 1 })
                            }

                            // Rule 8: the row fills along its own length rather
                            // than appearing all at once.
                            opacity: 0
                            Component.onCompleted: hourIn.restart()
                            SequentialAnimation {
                                id: hourIn
                                PauseAnimation { duration: Direction.sweep(hourCell.index, 8) }
                                NumberAnimation {
                                    target: hourCell; property: "opacity"; to: 1
                                    duration: Theme.animNormal
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easeEmphasized
                                }
                            }
                        }
                    }
                }

                // ── Дальше ──
                Column {
                    width: parent.width
                    spacing: Theme.spacing
                    visible: Weather.daily.length > 0

                    Repeater {
                        model: Weather.daily

                        delegate: DeviceRow {
                            required property var modelData
                            width: parent.width
                            tone: "neutral"
                            glyph: Weather.glyphFor(modelData.code, true)
                            name: modelData.label
                            hasControl: false
                            trailing: Math.round(modelData.min) + "° / "
                                + Math.round(modelData.max) + "°"
                        }
                    }
                }

                EmptyRow {
                    width: parent.width
                    visible: !Weather.valid
                    glyph: Glyphs.weatherCloudy
                    text: Weather.error !== "" ? Weather.error : "Погода ещё не загрузилась"
                }
            }
        }
    }
}
