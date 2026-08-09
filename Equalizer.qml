import QtQuick

// Ten bands, and the light that crosses them when a preset lands.
//
// The animation is the reason this component is worth its length. A preset
// applied to ten bands at once is a jump cut: everything is different and
// nothing moved. A light that crosses the row -- each handle leaving for its
// new value at the moment the light reaches it -- is the same change told as
// one event, and it takes about two tempos to cross, which is exactly long
// enough for the eye to travel with it.
//
// The trail it leaves is not decoration either. The bright line runs through
// the handle centres, so it *is* the response curve -- the only place the
// shape of the equaliser is stated as a shape rather than as ten numbers.
Item {
    id: root

    implicitHeight: layout.implicitHeight

    // 0 to 1 as the light crosses. Drives the head's position, which handle has
    // been reached, and how much of the trail is drawn.
    property real sweep: 0
    // Fades the trail once the change has landed. Separate from the sweep so
    // the curve can linger after the light has gone, which is what makes it
    // readable at all.
    property real trailLife: 0

    // Where each handle's centre is, in this item's coordinates. Recomputed
    // when the bands move, because that is the curve.
    property var points: []

    function _recompute() {
        const out = [];
        for (let i = 0; i < bands.count; i++) {
            const cell = bands.itemAt(i);
            if (!cell) return;
            out.push(Qt.point(bandRow.x + cell.x + cell.width / 2,
                              bandRow.y + cell.handleY));
        }
        root.points = out;
    }

    Connections {
        target: Eq
        // Only a preset sweeps. Dragging one band is a change to one thing and
        // a light crossing the whole row for it would be the shell making more
        // of the gesture than the person did.
        function onApplied() {
            crossing.restart();
        }
    }

    SequentialAnimation {
        id: crossing
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "sweep"; from: 0; to: 1
                duration: Direction.crossing
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root; property: "trailLife"; to: 1
                duration: Math.round(Direction.tempo * 0.4)
            }
        }
        PauseAnimation { duration: Direction.rest }
        NumberAnimation {
            target: root; property: "trailLife"; to: 0
            duration: Theme.animArrive
            easing.type: Easing.InQuad
        }
        // Parked, not left running: the head is only a light while it is
        // crossing something.
        onFinished: root.sweep = 0
    }

    Column {
        id: layout
        anchors.fill: parent
        spacing: Theme.gapCard

        Row {
            width: parent.width
            spacing: Theme.spacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Equalizer"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Medium
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - eqTitleWidth.width - routeChip.width - presetLabel.width
                    - Theme.spacing * 3
                height: 1
            }

            Text {
                id: eqTitleWidth
                visible: false
                text: "Equalizer"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Medium
            }

            // Whether the sound is actually going through the filter. Without
            // it the panel is ten sliders that do nothing you can hear, which
            // is the single most confusing thing an equaliser can be.
            Chip {
                id: routeChip
                anchors.verticalCenter: parent.verticalCenter
                tone: "audio"
                live: Eq.routed
                glyph: Glyphs.equalizer
                label: Eq.routed ? "Включён" : "Выключен"
                onClicked: Eq.setRouted(!Eq.routed)
            }

            Text {
                id: presetLabel
                anchors.verticalCenter: parent.verticalCenter
                text: Eq.preset !== "" ? Eq.preset : "Своя"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }
        }

        Item {
            id: bandArea
            width: parent.width
            height: 132

            Row {
                id: bandRow
                anchors.fill: parent
                spacing: Theme.spacing

                Repeater {
                    id: bands
                    model: Eq.frequencies.length

                    delegate: VSlider {
                        id: band
                        required property int index

                        width: (bandArea.width - Theme.spacing * (Eq.frequencies.length - 1))
                            / Eq.frequencies.length
                        height: bandArea.height
                        from: Eq.minGain
                        to: Eq.maxGain
                        caption: Eq.labels[band.index]
                        tint: Theme.accent

                        // The band leaves for its new value when the light gets
                        // to it, not when the preset was clicked. Everything
                        // about the sweep is this one line.
                        readonly property real target: Eq.bands[band.index]
                        readonly property real reached:
                            root.sweep * (Eq.frequencies.length - 1)

                        value: band.target
                        Behavior on value {
                            SequentialAnimation {
                                PauseAnimation {
                                    duration: crossing.running
                                        ? Direction.sweep(band.index, Eq.frequencies.length)
                                        : 0
                                }
                                NumberAnimation {
                                    duration: Theme.animNormal
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easeSpringBig
                                }
                            }
                        }

                        onMoved: v => Eq.setBand(band.index, v)
                        onHandleYChanged: root._recompute()
                        Component.onCompleted: root._recompute()
                    }
                }
            }

            // Under the handles, so the light passes behind them rather than
            // over: a bloom on top of a knob hides the thing it is pointing at.
            Trail {
                anchors.fill: parent
                z: -1
                points: root.points
                head: root.sweep
                life: root.trailLife
                tint: Theme.accent
            }

            Bloom {
                z: -1
                visible: crossing.running
                amount: crossing.running ? 1 : 0
                reach: 30
                coreSize: 9
                // Warm at the bottom of the spectrum and cold at the top, which
                // is not decoration: it is the one place in this shell where a
                // colour is a physical quantity.
                tint: Qt.tint(Theme.tone("audio"),
                    Qt.alpha(Theme.tone("net"), root.sweep))
                x: root.points.length > 1
                    ? root.points[0].x + (root.points[root.points.length - 1].x
                        - root.points[0].x) * root.sweep - width / 2
                    : 0
                y: {
                    if (root.points.length < 2) return 0;
                    const at = root.sweep * (root.points.length - 1);
                    const i = Math.max(0, Math.min(root.points.length - 2, Math.floor(at)));
                    const t = at - i;
                    return root.points[i].y + (root.points[i + 1].y - root.points[i].y) * t
                        - height / 2;
                }
            }
        }

        Grid {
            width: parent.width
            columns: 4
            rowSpacing: Theme.spacing
            columnSpacing: Theme.spacing

            Repeater {
                model: Eq.presetNames

                delegate: Rectangle {
                    id: presetButton
                    required property var modelData

                    width: (parent.width - Theme.spacing * 3) / 4
                    height: 30
                    radius: Theme.radiusChip

                    readonly property bool current: Eq.preset === presetButton.modelData

                    // Cross-fade, not a marker that travels. The buttons sit in
                    // a grid two rows deep and there is nothing between them for
                    // a marker to fly across; the change is which one is lit,
                    // and both being dim for a moment is what says so.
                    color: presetButton.current
                        ? Theme.accent
                        : (presetHit.containsMouse ? Qt.alpha(Theme.text, Theme.fillHover)
                                                   : Qt.alpha(Theme.text, Theme.fillSubtle))
                    Behavior on color { ColorAnimation { duration: Theme.animNormal } }

                    Text {
                        anchors.centerIn: parent
                        text: presetButton.modelData
                        color: presetButton.current ? Theme.crust : Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.weight: presetButton.current ? Font.DemiBold : Font.Normal
                        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                    }

                    MouseArea {
                        id: presetHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Eq.usePreset(presetButton.modelData)
                    }
                }
            }
        }

        // Said out loud rather than left to be discovered. A panel of controls
        // that quietly do nothing is worse than no panel.
        Text {
            width: parent.width
            visible: !Eq.available
            text: "Фильтр не найден. Установить: bin/yoake-eq install, затем "
                + "systemctl --user restart pipewire pipewire-pulse wireplumber"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontMicro
            wrapMode: Text.WordWrap
        }
    }
}
