import QtQuick

// Everything the shell will ever make a noise about, listed and auditionable.
//
// A sound setting that is one switch is a switch nobody dares turn on: the
// question is never "do I want sounds" but "what exactly is going to happen".
// So the list is the setting -- every event, what it means, and a click to hear
// it before committing to a day of it.
Column {
    id: root

    signal preview(string name)

    spacing: Theme.spacing

    readonly property var events: [
        { name: "device-added", text: "Устройство подключено", detail: "наушники, колонка, мышь" },
        { name: "device-removed", text: "Устройство отключено", detail: "в том числе само по себе" },
        { name: "network-up", text: "Сеть подключена", detail: "" },
        { name: "network-lost", text: "Сеть пропала", detail: "" },
        { name: "vpn-up", text: "Туннель поднят", detail: "" },
        { name: "vpn-down", text: "Туннель опущен", detail: "" },
        { name: "record-stop", text: "Запись остановлена", detail: "начало намеренно молчит — оно попало бы в запись" },
        { name: "message", text: "Уведомление", detail: "" },
        { name: "error", text: "Действие не удалось", detail: "" },
        { name: "complete", text: "Долгое дело закончилось", detail: "" }
    ]

    Text {
        text: "Звук событий"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitle
        font.weight: Font.Medium
    }

    Text {
        width: parent.width
        text: "Звучит только то, что имеет последствие вне экрана. Открытие панелей, "
            + "наведение, смена стола и перемотка молчат всегда."
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontMicro
        wrapMode: Text.WordWrap
    }

    Row {
        width: parent.width
        spacing: Theme.gapWide

        Chip {
            anchors.verticalCenter: parent.verticalCenter
            tone: "audio"
            live: Sfx.enabled
            glyph: Sfx.enabled ? Glyphs.volumeHigh : Glyphs.volumeMute
            label: Sfx.enabled ? "Включён" : "Выключен"
            onClicked: Prefs.set("sfx.enabled", !Sfx.enabled)
        }

        HSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 160
            visible: Sfx.enabled
            value: Sfx.volume / 100
            tint: Theme.tone("audio")
            onMoved: v => Prefs.set("sfx.volume", Math.round(v * 100))
        }
    }

    Repeater {
        model: root.events

        delegate: DeviceRow {
            required property var modelData
            width: root.width
            tone: "audio"
            glyph: Glyphs.play
            name: modelData.text
            subtitle: modelData.detail !== "" ? modelData.detail : modelData.name
            hasControl: false
            // Auditioned even while the whole thing is off, because that is the
            // question being asked.
            onActivated: {
                Sfx.audition(modelData.name);
                root.preview(modelData.name);
            }
        }
    }
}
