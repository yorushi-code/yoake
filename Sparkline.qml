import QtQuick

// A short run of samples as a filled line.
//
// Bars were the obvious choice — the shell already draws the spectrum and the
// seek wave that way — and that is exactly why this is not bars: at this size a
// column of them reads as audio, and a load history that looks like a spectrum
// is a load history nobody reads. A line says "over time" without a legend.
//
// Samples arrive from the right, so the newest is always under the same edge
// and a chart that is still filling does not stretch itself as it goes.
Item {
    id: root

    property var values: []
    // How many samples the strip is scaled for, so a half-full buffer draws at
    // its real width rather than being spread across the whole card.
    property int capacity: 45
    property color tint: Theme.accent
    property real maximum: 1

    onValuesChanged: canvas.requestPaint()
    onTintChanged: canvas.requestPaint()

    // The floor the line sits on, drawn whether or not there are samples yet:
    // an empty card with a baseline reads as "nothing has happened", an empty
    // card with nothing in it reads as broken.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.alpha(Theme.text, 0.10)
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const v = root.values;
            if (!v || v.length < 2) return;

            const step = width / Math.max(1, root.capacity - 1);
            const top = 2;
            const usable = Math.max(1, height - top - 1);
            const x0 = width - (v.length - 1) * step;

            const at = i => ({
                x: x0 + i * step,
                y: height - Math.max(0, Math.min(1, v[i] / root.maximum)) * usable
            });

            ctx.beginPath();
            let p = at(0);
            ctx.moveTo(p.x, p.y);
            for (let i = 1; i < v.length; i++) {
                p = at(i);
                ctx.lineTo(p.x, p.y);
            }

            // The fill closes down the two sides to the baseline, so the shape
            // under the line is the area rather than a wedge.
            ctx.save();
            ctx.lineTo(p.x, height);
            ctx.lineTo(x0, height);
            ctx.closePath();
            const grad = ctx.createLinearGradient(0, 0, 0, height);
            grad.addColorStop(0, Qt.alpha(root.tint, 0.30));
            grad.addColorStop(1, Qt.alpha(root.tint, 0.02));
            ctx.fillStyle = grad;
            ctx.fill();
            ctx.restore();

            ctx.strokeStyle = root.tint;
            ctx.lineWidth = 1.5;
            ctx.lineJoin = "round";
            ctx.stroke();
        }
    }

    // The newest sample gets a dot: it marks where the line is now, and it is
    // the only part of the chart that moves, which is what makes the card feel
    // live rather than printed.
    Rectangle {
        width: 5
        height: 5
        radius: 2.5
        visible: root.values.length > 1
        color: root.tint
        x: root.width - width / 2
        y: {
            const last = root.values[root.values.length - 1] || 0;
            const usable = Math.max(1, root.height - 3);
            return root.height - Math.max(0, Math.min(1, last / root.maximum)) * usable - height / 2;
        }
        Behavior on y { NumberAnimation { duration: Theme.animNormal } }
    }
}
