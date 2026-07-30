import QtQuick

// System load, mirroring the desktop widget so the numbers stay reachable when
// windows cover the desktop.
Row {
    id: root

    spacing: 8

    readonly property real cellWidth: (root.width - root.spacing * 2) / 3

    StatChip {
        width: root.cellWidth
        glyph: Glyphs.cpu
        label: Math.round(SysInfo.cpu * 100) + "%"
        level: SysInfo.cpu
    }
    StatChip {
        width: root.cellWidth
        glyph: Glyphs.memory
        label: Math.round(SysInfo.memory * 100) + "%"
        level: SysInfo.memory
    }
    StatChip {
        width: root.cellWidth
        glyph: Glyphs.thermometer
        label: SysInfo.temperature > 0 ? SysInfo.temperature + "°" : "--"
        // 40-90C mapped onto the bar: below 40 idle reads as empty and above 90
        // the machine is thermally throttling anyway.
        level: Math.max(0, Math.min(1, (SysInfo.temperature - 40) / 50))
    }
}
