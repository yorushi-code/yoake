import QtQuick
import Quickshell

// The bar, the wallpaper and the desktop click-catcher are instantiated per
// connected output: all three are output-specific surfaces, and a single
// instance meant a second monitor got none of them (the bar even filtered
// workspaces by a hardcoded "eDP-1"). The panels below are transient popups
// anchored to the focused screen, so one of each is correct.
ShellRoot {
    Variants {
        model: Quickshell.screens
        WallpaperView {}
    }

    // Before DesktopClock on purpose: both live on the Bottom layer, surfaces
    // there stack in creation order, and the catcher has to end up underneath
    // the desktop widgets or it would swallow their clicks.
    Variants {
        model: Quickshell.screens
        DesktopLayer {}
    }

    DesktopClock {}

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    NotificationCenter {}
    Osd {}
    MediaOsd {}
    CheatSheet {}
    ControlCenter {}
    Calendar {}

    // A menu or panel left up after the user has moved to a window reads as
    // the shell being stuck. Popups hold no focus of their own under niri, so
    // the compositor's own focus events are the only reliable signal.
    Connections {
        target: Niri
        function onAttentionMoved() {
            Menus.closeAll();
            Toggles.closeAll();
        }
    }
}
