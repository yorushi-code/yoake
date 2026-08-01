pragma Singleton
import QtQuick
import Quickshell

// Every Nerd Font icon the shell draws, as escape sequences instead of literal
// characters.
//
// The glyphs live in the Private Use Area, and plenty of tooling between an
// editor and this file (and the odd terminal) silently mangles or drops those
// codepoints — a lost icon shows up as an invisible bug, since the Text just
// renders nothing. `\u{...}` survives every text pipeline intact, and having
// one table also means a widget references `Glyphs.wifi3` rather than an
// opaque box nobody can grep for.
//
// Names mirror the upstream nf-md-* names so they can be looked up directly in
// the Nerd Fonts cheat sheet.
Singleton {
    // Network
    readonly property string wifi: "\u{F05A9}"
    readonly property string wifiOff: "\u{F05AA}"
    readonly property string wifi1: "\u{F091F}"
    readonly property string wifi2: "\u{F0922}"
    readonly property string wifi3: "\u{F0925}"
    readonly property string wifi4: "\u{F0928}"
    readonly property string wifiNone: "\u{F092F}"
    readonly property string ethernet: "\u{F0200}"
    readonly property string vpn: "\u{F0582}"
    readonly property string earth: "\u{F01E7}"

    // Audio
    readonly property string volumeHigh: "\u{F057E}"
    readonly property string volumeMedium: "\u{F0580}"
    readonly property string volumeLow: "\u{F057F}"
    readonly property string volumeOff: "\u{F0581}"
    readonly property string volumeMute: "\u{F075F}"
    readonly property string microphone: "\u{F036C}"
    readonly property string microphoneOff: "\u{F036D}"
    readonly property string headphones: "\u{F02CB}"
    readonly property string speaker: "\u{F04C3}"
    readonly property string speakerMultiple: "\u{F0D38}"

    // Battery — indexed lookup lives in batteryFor() below.
    readonly property string battery: "\u{F0079}"
    readonly property string batteryCharging: "\u{F0084}"
    readonly property string batteryAlert: "\u{F0083}"
    readonly property var batterySteps: [
        "\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}",
        "\u{F007F}", "\u{F0080}", "\u{F0081}", "\u{F0082}", "\u{F0079}"
    ]

    // Notifications
    readonly property string bell: "\u{F009A}"
    readonly property string bellOff: "\u{F009B}"
    readonly property string bellBadge: "\u{F116B}"

    // Chrome / controls
    readonly property string check: "\u{F012C}"
    readonly property string close: "\u{F0156}"
    readonly property string chevronDown: "\u{F0140}"
    readonly property string chevronUp: "\u{F0143}"
    readonly property string download: "\u{F0045}"
    readonly property string upload: "\u{F0552}"
    readonly property string chevronLeft: "\u{F0141}"
    readonly property string chevronRight: "\u{F0142}"
    readonly property string dot: "\u{F09DF}"
    readonly property string plus: "\u{F0415}"
    readonly property string minus: "\u{F0374}"
    readonly property string refresh: "\u{F0450}"
    readonly property string copy: "\u{F018F}"
    readonly property string openExternal: "\u{F03CC}"
    readonly property string cog: "\u{F0493}"
    readonly property string tune: "\u{F062E}"

    // Session / power
    readonly property string power: "\u{F0425}"
    readonly property string restart: "\u{F0709}"
    readonly property string sleep: "\u{F04B2}"
    readonly property string lock: "\u{F033E}"
    readonly property string speedometer: "\u{F04C5}"
    readonly property string leaf: "\u{F032A}"
    readonly property string flash: "\u{F0241}"

    // Media
    readonly property string play: "\u{F040A}"
    readonly property string pause: "\u{F03E4}"
    readonly property string skipNext: "\u{F04AD}"
    readonly property string skipPrevious: "\u{F04AE}"
    readonly property string music: "\u{F075A}"
    readonly property string playlist: "\u{F0CB8}"
    readonly property string shuffle: "\u{F049D}"
    readonly property string shuffleOff: "\u{F049E}"
    readonly property string repeatAll: "\u{F0456}"
    readonly property string repeatOne: "\u{F0458}"
    readonly property string repeatOff: "\u{F0457}"

    // System stats
    readonly property string cpu: "\u{F0EE0}"
    readonly property string memory: "\u{F035B}"
    readonly property string thermometer: "\u{F050F}"
    readonly property string disk: "\u{F02CA}"
    readonly property string brightness: "\u{F00DF}"

    // Weather — nf-md-weather-*
    readonly property string weatherSunny: "\u{F0599}"
    readonly property string weatherNight: "\u{F0594}"
    readonly property string weatherPartly: "\u{F0595}"
    readonly property string weatherNightPartly: "\u{F0F31}"
    readonly property string weatherCloudy: "\u{F0590}"
    readonly property string weatherFog: "\u{F0591}"
    readonly property string weatherRain: "\u{F0597}"
    readonly property string weatherPour: "\u{F0596}"
    readonly property string weatherSnow: "\u{F0598}"
    readonly property string weatherStorm: "\u{F067E}"
    readonly property string wind: "\u{F059D}"
    readonly property string humidity: "\u{F058E}"

    // Apps / misc
    readonly property string bluetooth: "\u{F00AF}"
    readonly property string bluetoothOff: "\u{F00B2}"
    readonly property string image: "\u{F02E9}"
    readonly property string palette: "\u{F03D8}"
    readonly property string keyboard: "\u{F030C}"
    readonly property string apps: "\u{F003B}"
    readonly property string monitor: "\u{F0379}"
    readonly property string folder: "\u{F024B}"
    readonly property string magnify: "\u{F0349}"
    readonly property string terminal: "\u{F018D}"
    readonly property string web: "\u{F059F}"
    readonly property string calendar: "\u{F00F6}"
    readonly property string record: "\u{F044A}"
    readonly property string stop: "\u{F04DB}"
    readonly property string video: "\u{F0567}"

    // Rounds to the nearest 10% bucket the icon set provides. The step for a
    // given bucket is at index-1 (the array starts at battery_10, not at
    // empty), so 50% picks battery_50 rather than battery_60; clamping keeps
    // 0% and 100% on the end entries instead of falling off the array.
    function batteryFor(fraction, charging) {
        if (charging) return batteryCharging;
        const idx = Math.max(0, Math.min(9, Math.round(fraction * 10) - 1));
        return batterySteps[idx];
    }

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
