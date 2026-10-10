import QtQuick
import Quickshell
import "widgets"

ShellRoot {
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool quickactionsEnabled: Config.getSetting("general", {}).quickactions !== false
    readonly property bool dockEnabled: Config.getSetting("dock", {}).enabled !== false

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    // A QML singleton is constructed on first reference, and nothing
    // references this one: it writes into ThemeBackend instead of being read.
    // Without this line the layer is not late, it is absent.
    readonly property var _kizashiLayer: [KizashiPalette]

    ScreenshotOverlay {}
    Main {}
    Bar {}
    Lock {}
    WidgetRedactor {}

    Launcher {}
    Clipboard {}    

    Polkit {}
    PopoutManager {}

    Loader {
        active: dockEnabled
        sourceComponent: Dock {}
    }

    Loader {
        active: !performanceMode
        sourceComponent: Idle {}
    }
    Variants {
        model: performanceMode ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: !performanceMode
        sourceComponent: WallpaperEngine {}
    }
    Loader {
        active: !performanceMode && quickactionsEnabled
        sourceComponent: Floating {}
    }

    Component.onCompleted: {
        Qt.application.organization = "kizashi";
        Qt.application.domain = "kizashi.org";
        Qt.application.name = "kizashi";
        FirstLaunch.checkFirstLaunch();
        SysNotif.checkBattery();
    }
}
