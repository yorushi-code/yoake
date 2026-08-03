import QtQuick
import QtQuick.Effects

// A widget that can be picked up and put somewhere else.
//
// Position is stored as a fraction of the *free* space rather than of the
// screen, so 1.0 means "flush with the right edge" whatever the widget's own
// width is — a fraction of the screen would push a wide widget half off it.
Item {
    id: root

    required property string name
    required property string screenName
    // Where it lives before the user has ever moved it.
    property real defaultX: 0.5
    property real defaultY: 0.5

    default property alias content: holder.children

    readonly property bool editing: DesktopWidgets.editing

    property real fx: root.defaultX
    property real fy: root.defaultY

    implicitWidth: holder.childrenRect.width
    implicitHeight: holder.childrenRect.height
    width: implicitWidth
    height: implicitHeight

    x: (parent ? parent.width - width : 0) * root.fx
    y: (parent ? parent.height - height : 0) * root.fy

    // Loaded once the preferences file has been read, which may be after this
    // is built — singleton construction order is not defined.
    function _restore() {
        const p = DesktopWidgets.positionFor(root.name, root.screenName,
                                             root.defaultX, root.defaultY);
        root.fx = p.x;
        root.fy = p.y;
    }

    Component.onCompleted: if (Prefs.loaded) root._restore()

    property Connections _prefsReady: Connections {
        target: Prefs
        function onLoadedChanged() { if (Prefs.loaded) root._restore(); }
    }

    // A soft darkening under every desktop widget.
    //
    // These are the only things in the shell drawn straight onto the picture,
    // and no ink choice can be right for all of it: a video's brightness was
    // measured from one extracted frame at 0.31 while the frame actually on
    // screen was 0.82, and even a still picture is rarely uniform under the
    // corner a widget happens to sit in. A scrim does not need to know -- it is
    // how the lock screen keeps its own type readable, and it costs one blurred
    // rectangle per widget rather than an outline per glyph.
    RectangularShadow {
        anchors.fill: parent
        anchors.margins: -6
        radius: 26
        blur: 38
        spread: 10
        color: "#000000"
        opacity: Theme.deskScrim
        visible: opacity > 0
        offset: Qt.vector2d(0, 2)
        z: -1
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    // Edit-mode chrome, drawn behind the widget so it reads as a slot the
    // widget is sitting in rather than as a border around its content.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -10
        z: -1
        radius: Theme.radius + 6
        color: drag.active
            ? Qt.alpha(Theme.accent, 0.22)
            : (hover.hovered ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, Theme.fillSubtle))
        border.width: 1
        border.color: drag.active ? Theme.accent : Qt.alpha(Theme.text, Theme.strokeFirm)
        opacity: root.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            text: root.name
            color: Theme.subtext0
            font.pixelSize: Theme.fontMicro
            font.letterSpacing: 1
        }
    }

    scale: drag.active ? 1.04 : 1
    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
    }

    HoverHandler {
        id: hover
        enabled: root.editing
        cursorShape: Qt.OpenHandCursor
    }

    DragHandler {
        id: drag
        enabled: root.editing
        target: null

        onActiveChanged: if (!drag.active) root._commit()
        onCentroidChanged: {
            if (!drag.active || !root.parent) return;
            const freeX = root.parent.width - root.width;
            const freeY = root.parent.height - root.height;
            if (freeX <= 0 || freeY <= 0) return;
            // Positioned from the pointer rather than by moving the target, so
            // the widget's x/y stay bindings on fx/fy and nothing has to be
            // re-bound after the drop. pressPosition is item-local and
            // scenePosition is window-local, so the difference is where the
            // widget's origin wants to be in the window — mapped back into the
            // field, which is inset from the window edges.
            const wanted = root.parent.mapFromItem(null,
                drag.centroid.scenePosition.x - drag.centroid.pressPosition.x,
                drag.centroid.scenePosition.y - drag.centroid.pressPosition.y);
            root.fx = Math.max(0, Math.min(1, wanted.x / freeX));
            root.fy = Math.max(0, Math.min(1, wanted.y / freeY));
        }
    }

    function _commit() {
        if (!root.parent) return;
        root.fx = DesktopWidgets.snap(root.fx, root.parent.width - root.width);
        root.fy = DesktopWidgets.snap(root.fy, root.parent.height - root.height);
        DesktopWidgets.setPosition(root.name, root.screenName, root.fx, root.fy);
    }

    // Only while settling after a drop: animating during the drag would make
    // the widget lag the cursor.
    Behavior on x {
        enabled: !drag.active
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
    }
    Behavior on y {
        enabled: !drag.active
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
    }
}
