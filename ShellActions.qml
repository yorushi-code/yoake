pragma Singleton
import Quickshell

// The shell's own menu, shared by the bar islands and the desktop right-click.
//
// It lived inline in Bar.qml, which meant the desktop could not offer the same
// entries without duplicating them — and a duplicated menu is one that drifts.
Singleton {
    id: root

    // Resolved through DesktopEntries so the real Exec line and icon are used
    // rather than a guessed command, and entries that aren't installed are
    // dropped instead of producing a menu item that fails silently.
    readonly property var favouriteIds: [
        "dev.yorushi.MihomoGui",
        "org.pulseaudio.pavucontrol",
        "org.gnome.Nautilus",
        "kitty"
    ]

    readonly property var shellMenu: {
        const out = [
            {
                text: "Сменить обои",
                glyph: Glyphs.image,
                action: () => Toggles.wallpaperPickerOpen = true
            },
            {
                text: "Горячие клавиши",
                glyph: Glyphs.keyboard,
                action: () => Toggles.cheatSheetOpen = true
            },
            {
                text: "Панель управления",
                glyph: Glyphs.tune,
                action: () => Toggles.controlCenterOpen = true
            }
        ];

        // DesktopEntries populates asynchronously, and byId() is a plain call
        // that registers no dependency — touching the model here is what makes
        // this binding re-run once the entries have actually been scanned.
        const _ = DesktopEntries.applications.values.length;

        const apps = [];
        for (const id of root.favouriteIds) {
            const entry = DesktopEntries.byId(id);
            if (!entry) continue;
            apps.push({
                text: entry.name,
                glyph: Glyphs.apps,
                action: () => Quickshell.execDetached(entry.command)
            });
        }
        if (apps.length > 0) {
            out.push({ separator: true });
            for (const a of apps) out.push(a);
        }

        out.push({ separator: true });
        out.push({
            text: "Перезагрузить оболочку",
            glyph: Glyphs.refresh,
            action: () => Quickshell.reload(true)
        });
        return out;
    }

    // Desktop-only extras: entries that make no sense hanging off a bar island.
    readonly property var desktopMenu: {
        const out = [
            {
                text: "Центр уведомлений",
                glyph: Glyphs.bell,
                action: () => Toggles.notifCenterOpen = true
            },
            {
                text: "Календарь",
                glyph: Glyphs.calendar,
                action: () => Toggles.calendarOpen = true
            },
            { separator: true }
        ];
        return out.concat(root.shellMenu);
    }
}
