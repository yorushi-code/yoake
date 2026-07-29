pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// The wallpaper library, and the thumbnail cache behind it.
//
// This replaces wallpaper-picker-gui.py, a GTK4 window embedding a WebKit view
// to get CSS hover transitions. Two toolkits and a browser engine to draw a
// grid of images, in a process that had to be spawned, painted its own theme,
// and could not show a live preview of the palette a wallpaper would produce.
//
// Thumbnails reuse the cache and key format that picker already filled
// (<basename>-<mtime>.jpg), so nothing is regenerated on the first run.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/wallpaper-picker/thumbs"

    readonly property var videoExtensions: ["mp4", "mkv", "webm", "mov", "m4v", "avi"]
    readonly property var imageExtensions: ["jpg", "jpeg", "png", "webp", "bmp"]

    property string search: ""

    function isVideo(path) {
        const dot = path.lastIndexOf(".");
        return dot >= 0 && root.videoExtensions.indexOf(path.slice(dot + 1).toLowerCase()) >= 0;
    }

    function displayName(fileName) {
        const dot = fileName.lastIndexOf(".");
        return (dot > 0 ? fileName.slice(0, dot) : fileName).replace(/[_-]/g, " ");
    }

    // Populated from the folder model; each entry is
    // { path, name, label, video, thumb, key }.
    property var entries: []
    // Thumbnails already on disk, keyed by <basename>-<mtime>.
    property var ready: ({})

    readonly property var visibleEntries: {
        const needle = root.search.trim().toLowerCase();
        if (needle === "") return root.entries;
        return root.entries.filter(e => e.label.toLowerCase().indexOf(needle) >= 0);
    }

    readonly property string currentPath: {
        const p = Wallpaper.path;
        return p.startsWith("file://") ? p.slice(7).split("?")[0] : p;
    }

    FolderListModel {
        id: folder
        folder: "file://" + root.dir
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp",
                      "*.mp4", "*.mkv", "*.webm", "*.mov", "*.m4v", "*.avi"]
        onStatusChanged: if (folder.status === FolderListModel.Ready) root._rebuild()
        onCountChanged: if (folder.status === FolderListModel.Ready) root._rebuild()
    }

    function _rebuild() {
        const out = [];
        for (let i = 0; i < folder.count; i++) {
            const name = folder.get(i, "fileName");
            const path = root.dir + "/" + name;
            // Modified time is part of the key so replacing a wallpaper with a
            // different image of the same name does not serve the old thumb.
            const modified = folder.get(i, "fileModified");
            const key = name + "-" + Math.floor(modified.getTime() / 1000);
            out.push({
                path: path,
                name: name,
                label: root.displayName(name),
                video: root.isVideo(path),
                key: key,
                thumb: root.cacheDir + "/" + key + ".jpg"
            });
        }
        root.entries = out;
        root._probe();
    }

    // ── thumbnail generation ──
    // One at a time, on purpose. Firing a Process per tile spawns a dozen
    // ImageMagick and ffmpeg decodes at once, which on an 8K source is enough
    // to stall the compositor — the picker would open to a grid of blank
    // cards and the whole desktop would hitch while they filled in.
    property var _queue: []
    property bool _working: false

    function _probe() {
        prober.command = ["sh", "-c",
            `mkdir -p '${root.cacheDir}'; ls -1 '${root.cacheDir}' 2>/dev/null`];
        prober.running = true;
    }

    Process {
        id: prober
        stdout: StdioCollector {
            onStreamFinished: {
                const have = {};
                for (const line of text.split("\n")) {
                    if (line.endsWith(".jpg")) have[line.slice(0, -4)] = true;
                }
                root.ready = have;

                const queue = [];
                for (const e of root.entries) {
                    if (!have[e.key]) queue.push(e);
                }
                root._queue = queue;
                root._next();
            }
        }
    }

    function _next() {
        if (root._working || root._queue.length === 0) return;
        const entry = root._queue[0];
        root._queue = root._queue.slice(1);
        root._working = true;
        maker.pending = entry;
        maker.command = entry.video
            // Seek before decoding and take a frame a second in: many videos
            // open on black, which would give a card with nothing on it.
            ? ["ffmpeg", "-y", "-loglevel", "error", "-ss", "1", "-i", entry.path,
               "-frames:v", "1", "-vf", "scale=480:-1", entry.thumb]
            // jpeg:size lets libjpeg decode at a reduced DCT scale rather than
            // unpacking 33 megapixels to throw almost all of it away.
            : ["magick", "-define", "jpeg:size=960x960", entry.path,
               "-resize", "480x", "-quality", "85", entry.thumb];
        maker.running = true;
    }

    Process {
        id: maker
        property var pending: null
        onExited: {
            if (maker.pending) {
                const have = root.ready;
                have[maker.pending.key] = true;
                root.ready = Object.assign({}, have);
            }
            maker.pending = null;
            root._working = false;
            root._next();
        }
    }

    // ── per-wallpaper detail ──
    // Dimensions, byte size, and the palette the wallpaper would produce if it
    // were applied. Both are probed on demand and cached by path, because the
    // picker only ever asks about the one entry the user has settled on — the
    // whole library would be a dozen ffprobes and three seconds of colour
    // analysis for information nobody looked at.
    property var meta: ({})
    property var palettes: ({})

    function request(entry) {
        if (!entry) return;
        if (root.meta[entry.path] === undefined) {
            root._metaWant = entry;
            root._pumpMeta();
        }
        if (root.palettes[entry.path] === undefined) {
            root._paletteWant = entry;
            root._pumpPalette();
        }
    }

    function formatBytes(n) {
        if (!n || n <= 0) return "";
        if (n < 1024 * 1024) return Math.round(n / 1024) + " КБ";
        return (n / 1048576).toFixed(1) + " МБ";
    }

    property var _metaWant: null

    function _pumpMeta() {
        const want = root._metaWant;
        if (info.running || !want) return;
        root._metaWant = null;
        info.target = want.path;
        // ffprobe rather than `magick identify`: one tool answers for both
        // stills and video, so there is no branch to get wrong.
        info.command = ["sh", "-c",
            "ffprobe -v error -select_streams v:0 -show_entries stream=width,height "
            + "-of csv=p=0:s=x \"$1\"; stat -c %s \"$1\"", "_", want.path];
        info.running = true;
    }

    Process {
        id: info
        property string target: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const next = Object.assign({}, root.meta);
                next[info.target] = {
                    size: (lines[0] || "").trim(),
                    bytes: parseInt((lines[1] || "0").trim(), 10) || 0
                };
                root.meta = next;
            }
        }
        onExited: root._pumpMeta()
    }

    property var _paletteWant: null

    function _pumpPalette() {
        const want = root._paletteWant;
        if (probe.running || !want) return;
        // A video is analysed through the frame already extracted for its
        // thumbnail: ImageMagick will not decode an mp4, and that frame is what
        // set-wallpaper.sh would build the palette from anyway.
        const source = want.video ? want.thumb : want.path;
        if (want.video && root.ready[want.key] !== true) return;
        root._paletteWant = null;
        probe.target = want.path;
        probe.command = [Quickshell.env("HOME") + "/.local/bin/wallpaper-palette.py",
                         "--probe", source];
        probe.running = true;
    }

    Process {
        id: probe
        property string target: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = null;
                try {
                    parsed = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const next = Object.assign({}, root.palettes);
                next[probe.target] = parsed;
                root.palettes = next;
            }
        }
        onExited: root._pumpPalette()
    }

    // ── applying ──
    property Process setter: Process {}

    function apply(path) {
        root.setter.command = [Quickshell.env("HOME") + "/.local/bin/set-wallpaper.sh", path];
        root.setter.running = true;
    }
}
