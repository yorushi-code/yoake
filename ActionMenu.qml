import QtQuick
import Quickshell

// Menu built from a plain JS model, used by every right-click in the bar.
//
// Model entries are objects:
//   { text, glyph, checkable, checked, enabled, separator, destructive,
//     action: function() {...} }
// A `separator: true` entry needs nothing else. Entries are rebuilt by the
// owner each time the menu opens, which is what keeps live lists (audio sinks,
// wifi networks, MPRIS players) from going stale between openings.
MenuSurface {
    id: root

    property var model: []
    // The item the menu hangs from; the caller sets this and toggles `open`.
    property Item anchorItem: null
    // The owner's key in the Menus registry, so this menu can retire itself
    // without the owner having to observe every way it might close.
    property string menuId: ""

    anchor {
        item: root.anchorItem
        rect.y: root.anchorItem ? root.anchorItem.height : 0
        // Slides along the edge instead of hanging off-screen when the owning
        // widget sits near a corner of the bar.
        gravity: Edges.Bottom
        adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY
    }

    // Width is measured from the entry text rather than taken from the layout.
    // Binding it to `column.implicitWidth` defines it circularly — the rows are
    // sized to the column, the column to the popup, and the popup to this — so
    // it settled at 0 and the whole menu mapped as a 20px sliver. Height is
    // safe to take from the layout: row heights are fixed constants.
    contentHeight: column.implicitHeight

    TextMetrics {
        id: metrics
        font.pixelSize: Theme.fontBody
    }

    // 76 covers the icon column, paddings and the submenu chevron — the same
    // budget MenuItemRow uses for its own implicitWidth.
    function measure(entries) {
        let w = 180;
        for (const e of entries) {
            if (e.separator) continue;
            metrics.text = e.text || "";
            w = Math.max(w, metrics.advanceWidth + 76);
        }
        return Math.min(420, Math.ceil(w));
    }

    // Assigned, never bound: reading the metrics inside a binding that also
    // writes to them is exactly the loop this is avoiding.
    onModelChanged: {
        root.contentWidth = root.measure(root.model);
        if (root.open && root.snapshot.length === 0) Qt.callLater(root._capture);
    }

    // Rows are built from the snapshot, not from the live model. Owners derive
    // their entries from services that keep moving — Pipewire nodes, wifi scan
    // results, MPRIS players — and any change while the menu was up rebuilt
    // every row and replayed the whole reveal cascade in place. Menus close on
    // any trigger, so there is nothing a live update could usefully show.
    property var snapshot: []

    // Taken after the bindings settle, not during them. `open` and `model` are
    // both derived from the same "is this menu open" question, and QML gives no
    // order between two bindings on the same dependency -- when `open` won the
    // race the snapshot captured the model as it was a moment earlier, which is
    // the empty list, and the menu mapped as a thin empty sliver under the bar.
    function _capture() {
        if (root.open) root.snapshot = root.model;
    }

    onOpenChanged: if (root.open) Qt.callLater(root._capture);

    Component.onCompleted: {
        root.contentWidth = root.measure(root.model);
        root._capture();
    }

    onDismissed: Menus.close(root.menuId)

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right

        Repeater {
            model: root.snapshot
            delegate: MenuItemRow {
                id: entryRow
                required property var modelData
                required property int index

                width: column.width
                text: modelData.text || ""
                glyph: modelData.glyph || ""
                checkable: modelData.checkable === true
                checked: modelData.checked === true
                separator: modelData.separator === true
                destructive: modelData.destructive === true
                enabled: modelData.enabled !== false

                // Staggered reveal, capped so a long device list doesn't
                // cascade slowly on open. The cap lives in Direction.stagger so
                // every cascade in the shell has the same rhythm.
                //
                // It fades and travels, like the launcher's rows: a list that
                // only fades in arrives everywhere at once and the stagger is
                // the only thing saying otherwise. Six pixels is enough — a
                // menu is read in one glance and anything further turns the
                // cascade into a wait.
                opacity: 0
                Component.onCompleted: entry.start()
                SequentialAnimation {
                    id: entry
                    PauseAnimation { duration: Direction.stagger(index) }
                    // Targets the row explicitly: `parent` inside an
                    // animation resolves to the enclosing Item's parent — the
                    // Column — so this animated the wrong object's opacity and
                    // left every row sitting invisible at 0.
                    ParallelAnimation {
                        NumberAnimation {
                            target: entryRow; property: "opacity"; to: 1
                            duration: Theme.animFast
                            easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized
                        }
                        NumberAnimation {
                            target: entryRow; property: "x"; from: -6; to: 0
                            duration: Theme.animNormal
                            easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig
                        }
                    }
                }

                onTriggered: {
                    // Close first: an action that opens a window or another
                    // menu should not leave this one hanging behind it.
                    Menus.close(root.menuId);
                    if (modelData.action) modelData.action();
                }
            }
        }
    }
}
