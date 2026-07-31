import QtQuick

// CPU, memory and temperature.
Row {
    spacing: 18

    StatGauge {
        glyph: Glyphs.cpu
        value: Math.round(SysInfo.cpu * 100) + "%"
        level: SysInfo.cpu
    }
    StatGauge {
        glyph: Glyphs.memory
        value: Math.round(SysInfo.memory * 100) + "%"
        level: SysInfo.memory
    }
    StatGauge {
        glyph: Glyphs.thermometer
        visible: SysInfo.temperature > 0
        value: SysInfo.temperature + "\u00b0"
        // 40-90C mapped onto the ring: below 40 idle reads as empty and above
        // 90 the machine is thermally throttling anyway.
        level: Math.max(0, Math.min(1, (SysInfo.temperature - 40) / 50))
    }
}
