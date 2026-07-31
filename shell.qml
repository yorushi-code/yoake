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

    // Before DesktopSurface on purpose: both live on the Bottom layer, surfaces
    // there stack in creation order, and the catcher has to end up underneath
    // the desktop widgets or it would swallow their clicks.
    Variants {
        model: Quickshell.screens
        DesktopLayer {}
    }

    Variants {
        model: Quickshell.screens
        DesktopSurface {}
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // The lock has to exist before it is needed: creating the surface at the
    // moment of locking would show the desktop for the frame it takes to build.
    LockScreen {}

    // The OSDs stay eager: they answer a volume or brightness keypress, where
    // even an asynchronous load would be a visible lag on the first press.
    Osd {}
    MediaOsd {}

    // The toast stack has to exist from startup: it is what puts a
    // notification on screen in the first place.
    NotificationCenter {}

    // These four cost ~41 MB of resident set between them, measured by taking
    // them out of this file, and in a typical session most are never opened.
    LazyPanel {
        shown: Toggles.notifCenterOpen
        NotificationPanel {}
    }
    LazyPanel {
        shown: Toggles.cheatSheetOpen
        CheatSheet {}
    }
    LazyPanel {
        shown: Toggles.controlCenterOpen
        ControlCenter {}
    }
    LazyPanel {
        shown: Toggles.calendarOpen
        Calendar {}
    }
    LazyPanel {
        shown: Toggles.wallpaperPickerOpen
        WallpaperPicker {}
    }
    LazyPanel {
        shown: Toggles.vpnPanelOpen
        VpnPanel {}
    }
    LazyPanel {
        shown: Toggles.launcherOpen
        Launcher {}
    }

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
