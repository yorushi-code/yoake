import QtQuick
import Quickshell

ShellRoot {
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool quickactionsEnabled: Config.getSetting("general", {}).quickactions !== false

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    // A QML singleton is constructed on first reference, and nothing
    // references this one: it writes into ThemeBackend instead of being read.
    // Without this line the layer is not late, it is absent.
    readonly property var _yoakeLayer: [YoakePalette]

    ScreenshotOverlay {}
    Main {}
    Bar {}
    Lock {}

    Launcher {}
    Clipboard {}	

    Polkit {}
    PopoutManager {}


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
}
