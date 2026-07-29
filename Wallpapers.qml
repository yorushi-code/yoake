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

    // ── applying ──
    property Process setter: Process {}

    function apply(path) {
        root.setter.command = [Quickshell.env("HOME") + "/.local/bin/set-wallpaper.sh", path];
        root.setter.running = true;
    }
}
