pragma Singleton
import Quickshell

// One way to turn an icon name into something an Image can load.
//
// There were three spellings of this across the shell -- a name with a fallback
// string, a hasThemeIcon test followed by a lookup, and the check form -- which
// is how the same bug came to be fixed in one file and left standing in two.
Singleton {
    id: root

    // Always the check form, never a name with a fallback handed to the icon
    // engine.
    //
    // Measured: a theme can hold a name at 16, 22 and 24 and nothing larger.
    // Asked for that name at 30 with a fallback, the engine fails outright --
    // and so does the fallback, which AdwaitaLegacy also stops at 24 -- and
    // IconImage draws Qt's magenta checkerboard while still reporting itself
    // Ready, so no status check can catch it. Asked with the check flag, the
    // same icon renders and the log stays quiet.
    //
    // `fallback` may be "" for the callers that want an empty string when there
    // is nothing, because they draw a glyph instead.
    function forName(name, fallback) {
        const wanted = name || "";
        const found = wanted !== "" ? Quickshell.iconPath(wanted, true) : "";
        if (found !== "") return found;
        const alt = fallback === undefined ? "application-x-executable" : fallback;
        return alt !== "" ? Quickshell.iconPath(alt, true) : "";
    }
}
