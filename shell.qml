import Quickshell

// The bar and the wallpaper are instantiated per connected output: both are
// output-specific surfaces, and a single instance meant a second monitor got
// neither (the bar even filtered workspaces by a hardcoded "eDP-1"). The
// panels below are transient popups anchored to the focused screen, so one of
// each is correct.
ShellRoot {
    Variants {
        model: Quickshell.screens
        WallpaperView {}
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    DesktopClock {}
    NotificationCenter {}
    Osd {}
    MediaOsd {}
    CheatSheet {}
    ControlCenter {}
    Calendar {}
}
