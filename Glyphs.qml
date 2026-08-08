pragma Singleton
import QtQuick
import Quickshell

// Every icon the shell draws, as a Material Symbols name.
//
// It used to be Nerd Font, written as `\u{F05A9}` escapes because the glyphs
// live in the Private Use Area and half the tooling between an editor and this
// file silently mangles those codepoints — a lost icon is an invisible bug,
// since the Text simply renders nothing. That whole problem is gone: Material
// Symbols ships ligatures, so the icon's own name *is* the text, and
// `Glyphs.wifi` is now the string "wifi".
//
// Which means this file is no longer a decoder ring. It is kept anyway, and
// for a better reason than it had: it is the shell's vocabulary. A widget asks
// for `Glyphs.batteryAlert`, not for whichever of `battery_alert`,
// `battery_1_bar` and `battery_error` somebody reached for that day, and the
// same state gets the same picture in the bar, the dashboard and a menu.
//
// Names on the left are the shell's; names on the right are upstream's, and
// every one of them was checked against the font's own codepoint table rather
// than remembered.
Singleton {
    // Network
    readonly property string wifi: "wifi"
    readonly property string wifiOff: "wifi_off"
    readonly property string wifi1: "network_wifi_1_bar"
    readonly property string wifi2: "network_wifi_2_bar"
    readonly property string wifi3: "network_wifi_3_bar"
    readonly property string wifi4: "network_wifi"
    readonly property string wifiNone: "signal_wifi_0_bar"
    readonly property string ethernet: "lan"
    readonly property string vpn: "vpn_lock"
    readonly property string earth: "public"

    // Audio
    readonly property string volumeHigh: "volume_up"
    readonly property string volumeMedium: "volume_down"
    readonly property string volumeLow: "volume_mute"
    readonly property string volumeOff: "volume_mute"  // level zero, still audible; `volumeMute` is the crossed speaker
    readonly property string volumeMute: "volume_off"
    readonly property string microphone: "mic"
    readonly property string microphoneOff: "mic_off"
    readonly property string headphones: "headphones"
    readonly property string speaker: "speaker"
    readonly property string speakerMultiple: "speaker_group"

    // Battery
    readonly property string battery: "battery_android_full"
    readonly property string batteryCharging: "battery_android_bolt"
    readonly property string batteryAlert: "battery_android_alert"

    // Notifications
    readonly property string bell: "notifications"
    readonly property string bellOff: "notifications_off"
    readonly property string bellBadge: "notifications_active"

    // Interface
    readonly property string check: "check"
    readonly property string close: "close"
    readonly property string chevronDown: "keyboard_arrow_down"
    readonly property string chevronUp: "keyboard_arrow_up"
    readonly property string chevronLeft: "keyboard_arrow_left"
    readonly property string chevronRight: "keyboard_arrow_right"
    readonly property string download: "download"
    readonly property string upload: "upload"
    readonly property string dot: "circle"  // outline at FILL 0 and a solid dot at FILL 1
    readonly property string plus: "add"
    readonly property string minus: "remove"
    readonly property string refresh: "refresh"
    readonly property string copy: "content_copy"
    readonly property string openExternal: "open_in_new"
    readonly property string cog: "settings"
    readonly property string tune: "tune"

    // Session
    readonly property string power: "power_settings_new"
    readonly property string restart: "restart_alt"
    readonly property string sleep: "bedtime"
    readonly property string coffee: "coffee"
    readonly property string lock: "lock"

    // Power profiles
    readonly property string speedometer: "speed"
    readonly property string leaf: "eco"
    readonly property string flash: "bolt"

    // Media
    readonly property string play: "play_arrow"
    readonly property string pause: "pause"
    readonly property string skipNext: "skip_next"
    readonly property string skipPrevious: "skip_previous"
    readonly property string music: "music_note"
    readonly property string playlist: "queue_music"
    readonly property string shuffle: "shuffle_on"  // upstream ships the on-state as its own glyph rather than
    readonly property string shuffleOff: "shuffle"  // as a fill, so these two are a genuine pair
    readonly property string repeatAll: "repeat_on"
    readonly property string repeatOne: "repeat_one_on"
    readonly property string repeatOff: "repeat"

    // Machine
    readonly property string cpu: "memory"  // upstream's `memory` is the processor die, not the RAM
    readonly property string memory: "memory_alt"  // and `memory_alt` is the RAM stick
    readonly property string thermometer: "thermostat"
    readonly property string disk: "hard_drive"
    readonly property string brightness: "brightness_6"

    // Weather
    readonly property string weatherSunny: "clear_day"
    readonly property string weatherNight: "clear_night"
    readonly property string weatherPartly: "partly_cloudy_day"
    readonly property string weatherNightPartly: "partly_cloudy_night"
    readonly property string weatherCloudy: "cloud"
    readonly property string weatherFog: "foggy"
    readonly property string weatherRain: "rainy"
    readonly property string weatherPour: "rainy_heavy"
    readonly property string weatherSnow: "weather_snowy"
    readonly property string weatherStorm: "thunderstorm"
    readonly property string wind: "air"
    readonly property string humidity: "humidity_percentage"

    // Bluetooth
    readonly property string bluetooth: "bluetooth"
    readonly property string bluetoothOff: "bluetooth_disabled"

    // Everything else
    readonly property string image: "image"
    readonly property string palette: "palette"
    readonly property string keyboard: "keyboard"
    readonly property string apps: "apps"
    readonly property string monitor: "monitor"
    readonly property string folder: "folder"
    readonly property string magnify: "search"
    readonly property string terminal: "terminal"
    readonly property string web: "language"
    readonly property string calendar: "calendar_month"
    readonly property string record: "radio_button_checked"
    readonly property string stop: "stop"
    readonly property string video: "videocam"

    // Eight steps, not ten. The old Nerd Font set had one glyph per 10% and
    // this one has one per bar, which is what the hardware draws and what the
    // eye counts -- a battery that distinguishes 70% from 80% by a difference
    // nobody can see was precision the picture never had.
    //
    // Horizontal, deliberately: `battery_*_bar` is the upright cell and
    // `battery_android_*` is the flat one, and a flat battery in a horizontal
    // bar of flat icons is the one that belongs there.
    readonly property var batterySteps: [
        "battery_android_0", "battery_android_1", "battery_android_2",
        "battery_android_3", "battery_android_4", "battery_android_5",
        "battery_android_6", "battery_android_full"
    ]

    function batteryFor(fraction, charging) {
        if (charging) return batteryCharging;
        const last = batterySteps.length - 1;
        return batterySteps[Math.max(0, Math.min(last, Math.round(fraction * last)))];
    }

    // ── Added for the panels that let you change things ──
    //
    // Every name below belongs to a control rather than to a readout, which is
    // most of what this pass is about. Declared here in one block so no track
    // has to reach into this file while the others are working in theirs.
    readonly property string equalizer: "graphic_eq"
    readonly property string tuneVertical: "tune"
    readonly property string swap: "swap_horiz"
    readonly property string recordDot: "fiber_manual_record"
    readonly property string stream: "graphic_eq"
    readonly property string outputs: "speaker"
    readonly property string inputs: "mic"
    readonly property string scan: "wifi_find"
    readonly property string forget: "link_off"
    readonly property string paired: "link"
    readonly property string batterySaver: "battery_saver"
    readonly property string performance: "bolt"
    readonly property string balanced: "balance"
    readonly property string nightLight: "nightlight"
    readonly property string preset: "bookmark"
    readonly property string presetSaved: "bookmark_added"

    // -1 means "no link" rather than 0%, which is a real signal level.
    function wifiFor(percent) {
        if (percent < 0) return wifiOff;
        if (percent >= 75) return wifi4;
        if (percent >= 50) return wifi3;
        if (percent >= 25) return wifi2;
        if (percent > 0) return wifi1;
        return wifiNone;
    }

    function volumeFor(volume, muted) {
        if (muted) return volumeMute;
        if (volume <= 0.001) return volumeOff;
        if (volume < 0.33) return volumeLow;
        if (volume < 0.66) return volumeMedium;
        return volumeHigh;
    }
}
