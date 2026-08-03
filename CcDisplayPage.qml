import QtQuick

// Everything that changes how the screen looks: brightness, colour temperature,
// and the palette the wallpaper produced.
Flickable {
    id: root

    contentHeight: list.implicitHeight
    clip: true

    Column {
        id: list
        width: parent.width
        spacing: 16

        SliderRow {
            width: parent.width
            label: "Яркость"
            // Bound, not assigned: the singleton is updated by the Fn keys too,
            // and this has to follow.
            value: Brightness.value
            onMoved: v => Brightness.set(v)
        }

        Column {
            width: parent.width
            spacing: 8

            ToggleRow {
                width: parent.width
                glyph: Glyphs.brightness
                label: "Ночной режим"
                detail: NightLight.enabled ? NightLight.temperature + "K" : ""
                active: NightLight.enabled
                expandable: false
                onToggled: NightLight.toggle()
            }

            SliderRow {
                width: parent.width
                visible: NightLight.enabled
                label: "Температура"
                value: (NightLight.temperature - NightLight.minTemperature)
                    / (NightLight.maxTemperature - NightLight.minTemperature)
                // Rounded to 100K: wlsunset restarts on every change, and a
                // continuous drag would respawn it on each pixel of travel.
                onMoved: v => {
                    const span = NightLight.maxTemperature - NightLight.minTemperature;
                    NightLight.temperature =
                        Math.round((NightLight.minTemperature + v * span) / 100) * 100;
                }
            }
        }

        ToggleRow {
            width: parent.width
            glyph: Glyphs.music
            label: "Плашка плеера"
            detail: Media.osdEnabled ? "при смене трека" : "не показывать"
            active: Media.osdEnabled
            expandable: false
            onToggled: Media.osdEnabled = !Media.osdEnabled
        }

        ToggleRow {
            width: parent.width
            visible: Wallpaper.isVideo
            glyph: Glyphs.video
            label: "Пауза видео на батарее"
            detail: Wallpaper.videoPaused ? "сейчас на паузе" : ""
            active: Wallpaper.pauseOnBattery
            expandable: false
            onToggled: Wallpaper.pauseOnBattery = !Wallpaper.pauseOnBattery
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.text, Theme.fillMuted)
        }

        PalettePreview {
            width: parent.width
            swatchSize: 28
        }
    }
}
