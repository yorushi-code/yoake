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

    // Singletons that have to exist whether or not anything is looking at them.
    //
    // A singleton is constructed on first reference, and a reference that only
    // appears inside a lazily-built dashboard page is no reference at all until
    // the page is opened. `qs ipc call idle state` answered "Target not found"
    // until Idle was listed here; NightLight was worse, because it looks like
    // it works -- the tile shows the right state the moment you open the page
    // that constructs it, and the warm screen you asked for last night simply
    // never came back after a restart.
    // Perception belongs here for the same reason and more sharply: it is
    // referenced by nothing at all -- it writes into Theme rather than being
    // read -- so without this line it is never constructed and the entire
    // semantic layer is simply absent, with every token sitting at its default
    // and nothing to indicate anything is missing.
    property var _alive: [Idle, NightLight, Context, Perception]

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
    LazyPanel {
        shown: Toggles.dashboardOpen
        Dashboard {}
    }

    // A menu or panel left up after the user has moved to a window reads as
    // the shell being stuck. Popups hold no focus of their own under niri, so
    // the compositor's own focus events are the only reliable signal.
    Connections {
        target: Niri
        function onAttentionMoved() {
            Menus.closeAll();
            Toggles.closeTransient();
        }
    }
}
