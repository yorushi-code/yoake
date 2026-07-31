pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Weather, from Open-Meteo.
//
// Chosen because it needs no API key and no account: a dashboard that stops
// working when a free tier expires is worse than one with no weather at all.
//
// The location is found once and remembered. It has to be found over the
// physical link rather than through the tunnel — with the VPN up, an IP lookup
// reports whichever country the exit node is in, so the forecast would follow
// the tunnel around Europe. `curl --interface` is what pins it.
Singleton {
    id: root

    property real latitude: 0
    property real longitude: 0
    property string place: ""
    property bool located: false

    property real temperature: 0
    property real feelsLike: 0
    property int code: -1
    property real wind: 0
    property int humidity: 0
    property bool isDay: true
    property bool valid: false
    property string error: ""

    // Refreshed on the quarter hour rather than continuously: the forecast this
    // reads is itself published hourly.
    readonly property int refreshInterval: 15 * 60 * 1000

    // WMO weather codes, folded into the states worth drawing separately.
    function describe(wmo) {
        if (wmo === 0) return "Ясно";
        if (wmo <= 2) return "Малооблачно";
        if (wmo === 3) return "Пасмурно";
        if (wmo <= 48) return "Туман";
        if (wmo <= 57) return "Морось";
        if (wmo <= 67) return "Дождь";
        if (wmo <= 77) return "Снег";
        if (wmo <= 82) return "Ливень";
        if (wmo <= 86) return "Снегопад";
        return "Гроза";
    }

    function glyphFor(wmo, day) {
        if (wmo === 0) return day ? Glyphs.weatherSunny : Glyphs.weatherNight;
        if (wmo <= 2) return day ? Glyphs.weatherPartly : Glyphs.weatherNightPartly;
        if (wmo === 3) return Glyphs.weatherCloudy;
        if (wmo <= 48) return Glyphs.weatherFog;
        if (wmo <= 67) return Glyphs.weatherRain;
        if (wmo <= 77) return Glyphs.weatherSnow;
        if (wmo <= 82) return Glyphs.weatherPour;
        if (wmo <= 86) return Glyphs.weatherSnow;
        return Glyphs.weatherStorm;
    }

    readonly property string summary: root.valid ? root.describe(root.code) : ""
    readonly property string glyph: root.valid
        ? root.glyphFor(root.code, root.isDay) : Glyphs.weatherCloudy

    function refresh() {
        if (!root.located) {
            locate.running = true;
            return;
        }
        forecast.running = true;
    }

    // The physical interface, so a tunnel does not decide where the user is.
    Process {
        id: locate
        command: ["sh", "-c", `
dev=$(ip -o route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
if [ -n "$dev" ]; then
  curl -s -m 8 --interface "$dev" https://ipapi.co/json/ 2>/dev/null && exit 0
fi
curl -s -m 8 https://ipapi.co/json/ 2>/dev/null
`]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    root.error = "не удалось определить местоположение";
                    return;
                }
                if (!data || data.latitude === undefined) {
                    root.error = "не удалось определить местоположение";
                    return;
                }
                root.latitude = data.latitude;
                root.longitude = data.longitude;
                root.place = data.city || data.region || "";
                root.located = true;
                Prefs.set("weather.place", {
                    lat: root.latitude, lon: root.longitude, name: root.place
                });
                forecast.running = true;
            }
        }
    }

    Process {
        id: forecast
        command: ["sh", "-c",
            "curl -s -m 10 'https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + root.latitude
            + "&longitude=" + root.longitude
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,"
            + "weather_code,wind_speed_10m,is_day&timezone=auto'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    root.error = "нет ответа от сервиса погоды";
                    return;
                }
                const now = data && data.current;
                if (!now) {
                    root.error = "нет ответа от сервиса погоды";
                    return;
                }
                root.temperature = now.temperature_2m;
                root.feelsLike = now.apparent_temperature;
                root.humidity = now.relative_humidity_2m;
                root.code = now.weather_code;
                root.wind = now.wind_speed_10m;
                root.isDay = now.is_day === 1;
                root.error = "";
                root.valid = true;
            }
        }
    }

    // A location found once survives a restart; only the forecast is fetched
    // again.
    function _adoptSaved() {
        const saved = Prefs.get("weather.place", null);
        if (saved && saved.lat !== undefined) {
            root.latitude = saved.lat;
            root.longitude = saved.lon;
            root.place = saved.name || "";
            root.located = true;
        }
        root.refresh();
    }

    Connections {
        target: Prefs
        function onLoadedChanged() {
            if (Prefs.loaded) root._adoptSaved();
        }
    }

    // Prefs may already have loaded by the time this singleton is built, and a
    // handler cannot catch a signal that has been and gone — the same way a
    // lazily-loaded panel never sees the toggle that created it.
    Component.onCompleted: if (Prefs.loaded) root._adoptSaved()

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
