pragma Singleton
import QtQuick
import Quickshell

// The shell's own language, for anything with a day or a month in it.
//
// Qt.formatDateTime uses the system locale, and this session runs under en_US —
// so the bar read "Sun, 2 Aug" under a clock, next to a panel that said
// "Воскресенье". Two surfaces had already been fixed by passing Qt.locale
// individually, which is the same fix written three times and forgotten on the
// fourth.
//
// Not named Locale: QtQml exports a value type by that name and it wins the
// lookup, exactly as QtQuick's Palette did.
Singleton {
    id: root

    readonly property var locale: Qt.locale("ru_RU")

    function date(when, format) {
        return when.toLocaleDateString(root.locale, format);
    }

    // Russian month and weekday names come back lower-case, which is right
    // inside a sentence and wrong as a heading.
    function dateCapitalised(when, format) {
        const s = root.date(when, format);
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function time(when, format) {
        return when.toLocaleTimeString(root.locale, format);
    }
}
