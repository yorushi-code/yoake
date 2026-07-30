import QtQuick

// CPU, memory and temperature.
Row {
    spacing: 14

    StatChip {
        glyph: Glyphs.cpu
        label: Math.round(SysInfo.cpu * 100) + "%"
        level: SysInfo.cpu
    }
    StatChip {
        glyph: Glyphs.memory
        label: Math.round(SysInfo.memory * 100) + "%"
        level: SysInfo.memory
    }
    StatChip {
        glyph: Glyphs.thermometer
        visible: SysInfo.temperature > 0
        label: SysInfo.temperature + "°"
        // 40-90C mapped onto the bar: below 40 idle reads as empty and above 90
        // the machine is thermally throttling anyway.
        level: Math.max(0, Math.min(1, (SysInfo.temperature - 40) / 50))
    }
}
