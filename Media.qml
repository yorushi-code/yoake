pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Single source of truth for "the player we're showing". Bar, DesktopClock
// and MediaOsd all need the same answer, and each picking its own favourite
// out of Mpris.players meant they could disagree mid-track-change.
//
// Browser players emit badly behaved metadata. Firefox, on every track
// change, alternates the real track frame with a placeholder carrying the
// page title and an empty artist, and it sets `mpris:artUrl` only to clear it
// again a few milliseconds later:
//
//   T=[Осколки]                A=[БАСТАРД] ART=[…_53.png]
//   T=[Yandex Music: Select…]  A=[]        ART=[]          <- 26ms later
//   T=[Осколки]                A=[БАСТАРД] ART=[]
//
// Binding the UI straight to those properties makes the art and title
// visibly flicker. Everything below latches the last frame that looks real.
Singleton {
    id: root

    // An explicit choice from the bar's right-click menu, which wins over the
    // heuristic below until that player goes away. Without it there was no way
    // to say which of two paused players the shell should be controlling.
    property var pinned: null

    // Prefer something actually playing; fall back to the first known player
    // so a paused track still shows instead of the UI going blank.
    readonly property var player: {
        const list = Mpris.players.values;
        if (root.pinned && list.indexOf(root.pinned) >= 0) return root.pinned;
        return list.find(p => p.isPlaying) || list[0] || null;
    }

    function pin(target) {
        root.pinned = (root.pinned === target) ? null : target;
    }

    // Everything MPRIS is offering, for a panel that lets a person choose
    // rather than a heuristic that decides for them. Ordered so the list does
    // not reshuffle under the pointer: playing first, then whatever order MPRIS
    // reported, which is stable for the life of a player.
    readonly property var players: {
        const list = [...Mpris.players.values];
        list.sort((a, b) => (b.isPlaying ? 1 : 0) - (a.isPlaying ? 1 : 0));
        return list;
    }

    // What to call one on screen. `identity` is the application's own name for
    // itself and is what a person recognises; the bus name is the fallback for
    // a player that did not set one.
    function playerLabel(p) {
        if (!p) return "";
        const raw = String(p.identity
            || String(p.dbusName || "").replace("org.mpris.MediaPlayer2.", ""));
        // Firefox reports its Identity as "Mozilla org.mozilla.firefox" -- the
        // name and the application id in one string. Dropping a reverse-DNS
        // token is not guessing at what an application meant; it is refusing to
        // print a field the application filled in badly.
        return raw.split(/\s+/).filter(w => !/^[a-z0-9-]+(\.[a-z0-9-]+){2,}$/.test(w))
            .join(" ") || raw;
    }

    // Three states, and they are not the same question. A player can be
    // chosen, or merely playing, or neither -- and a panel that shows only
    // "playing" cannot say why the shell is following a paused one.
    function playerState(p) {
        if (!p) return "";
        if (root.pinned === p) return "выбран";
        if (p.isPlaying) return "играет";
        return "";
    }

    // A pinned player that goes away leaves a dangling choice: `player` already
    // falls back correctly, so nothing breaks visibly, but the pin survives and
    // would silently re-take control if an application with the same object
    // ever came back. Cleared as soon as it is gone, so the choice a person
    // made is either honoured or forgotten -- never haunting.
    property Connections _playersGone: Connections {
        target: Mpris.players
        function onValuesChanged() {
            if (root.pinned && Mpris.players.values.indexOf(root.pinned) < 0) {
                root.pinned = null;
            }
        }
    }

    // ── Latched metadata (what the UI binds to) ──
    property string title: ""
    property string artist: ""
    property string artUrl: ""

    // Firefox publishes no mpris:artUrl at all for most sites — verified with
    // playerctl, the key is simply absent — but the extension that controls
    // playback sends a notification carrying the cover. When the two agree on
    // the track, that image is the art, and it is the only copy of it in the
    // system.
    //
    // The catch is what the notification hands over: an image://qsimage/<id>
    // handle owned by the notification itself. Dismiss it, let it expire, or
    // restart the shell, and the handle is dead — which is the cover vanishing
    // and "Failed to get image from provider" in the log. So the notification
    // that supplied it is remembered, and the art is dropped the moment that
    // notification is no longer among the tracked ones.
    property string notificationArt: ""
    property var notificationArtId: null

    readonly property string cover: root.artUrl !== "" ? root.artUrl : root.notificationArt

    // Whether this player has ever reported a non-empty artist. Used to tell
    // "Firefox glitch frame" from "a player that genuinely has no artist"
    // (podcasts, radio streams) — without it, the filter below would leave
    // those players permanently blank.
    property bool _sawArtist: false

    function _sync() {
        if (!player) {
            title = "";
            artist = "";
            artUrl = "";
            _sawArtist = false;
            return;
        }

        const t = player.trackTitle;
        const a = player.trackArtist;
        const art = player.trackArtUrl;

        if (a !== "") {
            _sawArtist = true;
        } else if (_sawArtist) {
            // Artist vanished on a player that normally reports one: this is
            // the placeholder frame, not a real track. Drop it entirely.
            return;
        }

        if (t !== title || a !== artist) {
            title = t;
            artist = a;
            // Art belongs to the track we just left, and Firefox deletes the
            // old file, so keeping it would only produce a broken image.
            artUrl = "";
        }

        // Only ever latched from a non-empty value — the clear-to-empty that
        // follows a few milliseconds later is exactly the flicker we drop.
        if (art !== "") artUrl = art;
    }

    // Metadata changes are coalesced through a short debounce instead of
    // syncing on every raw change. Switching tracks forward-then-back makes a
    // browser player churn title/artist/artUrl within a few ms, and reacting
    // to each one thrashed the async image loader in AlbumArt hard enough to
    // segfault the whole shell (rapid source swaps to already-deleted art
    // files, racing cancel-vs-load). Collapsing the churn to a single sync
    // per settle both fixes the crash and drops the redundant work.
    Timer {
        id: syncDebounce
        interval: 90
        onTriggered: root._sync()
    }

    Connections {
        target: root.player
        function onTrackTitleChanged() { syncDebounce.restart(); }
        function onTrackArtistChanged() { syncDebounce.restart(); }
        function onTrackArtUrlChanged() { syncDebounce.restart(); }
    }

    onPlayerChanged: {
        _sawArtist = false;
        _sync();
    }

    readonly property bool hasPlayer: player !== null && title !== ""
    readonly property bool playing: player !== null && player.isPlaying

    readonly property real position: player ? player.position : 0
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    // ── OSD visibility, driven by track changes ──
    property bool osdShown: false

    // A popup telling you what is playing, over the window you are playing it
    // in, is noise covering the controls you just used. Matching MPRIS to a
    // niri window has no exact key, so this compares tokens: the DesktopEntry
    // ("firefox"), the dbus name's own segment, and the last component of the
    // window's app_id ("org.mozilla.firefox" -> "firefox").
    readonly property var ownerTokens: {
        if (!root.player) return [];
        const out = [];
        if (root.player.desktopEntry) out.push(String(root.player.desktopEntry).toLowerCase());
        const name = String(root.player.dbusName || "");
        const tail = name.replace("org.mpris.MediaPlayer2.", "").split(".")[0];
        if (tail !== "") out.push(tail.toLowerCase());
        if (root.player.identity) out.push(String(root.player.identity).toLowerCase().replace(/\s+/g, ""));
        return out;
    }

    readonly property bool ownerFocused: {
        const win = Niri.focusedWindow;
        if (!win || !win.app_id || root.ownerTokens.length === 0) return false;
        const appId = String(win.app_id).toLowerCase();
        const last = appId.split(".").pop();
        return root.ownerTokens.some(t => t === last || appId.indexOf(t) >= 0 || t.indexOf(last) >= 0);
    }

    // Read from Prefs once rather than bound to it: a binding plus the
    // write-back handler is a loop, since storing the value changes the object
    // the binding reads from.
    property bool osdEnabled: true
    Component.onCompleted: {
        _sync();
        if (Prefs.loaded) root.osdEnabled = Prefs.get("mediaOsd", true);
    }
    onOsdEnabledChanged: if (Prefs.loaded) Prefs.set("mediaOsd", root.osdEnabled)

    // Singleton construction order is not defined, so the file may still be
    // unread when this one is built.
    property Connections _prefsReady: Connections {
        target: Prefs
        function onLoadedChanged() {
            if (Prefs.loaded) root.osdEnabled = Prefs.get("mediaOsd", true);
        }
    }

    // Built from the latched values, not the raw ones — keyed off the raw
    // title this fired on every placeholder frame and the OSD flashed
    // repeatedly during a single track change.
    readonly property string trackId: title === "" ? "" : `${title}|${artist}`
    property bool _primed: false

    onTrackIdChanged: {
        // The first assignment happens at startup, when nothing actually
        // changed — showing the OSD there would pop it on every login.
        if (!_primed) {
            _primed = trackId !== "";
            return;
        }
        if (trackId !== "") root.showOsd();
    }

    Timer {
        id: osdTimer
        interval: 4000
        onTriggered: root.osdShown = false
    }

    function showOsd() {
        if (!root.hasPlayer || !root.osdEnabled || root.ownerFocused) return;
        root.osdShown = true;
        osdTimer.interval = 4000;
        osdTimer.restart();
    }

    function hideOsd() {
        root.osdShown = false;
        osdTimer.stop();
    }

    // Held open while the pointer is on it, and given a fresh, shorter run when
    // the pointer leaves -- long enough to reach for a button again, short
    // enough that brushing past does not pin the popup to the corner.
    function holdOsd(held) {
        if (!root.osdShown) return;
        if (held) osdTimer.stop();
        else {
            osdTimer.interval = 1600;
            osdTimer.restart();
        }
    }

    // Alt-tabbing into the player while the popup is still up is the same
    // situation as the popup never having been shown.
    onOwnerFocusedChanged: if (root.ownerFocused) root.hideOsd()

    // Takes the newest notification whose text matches the track and keeps its
    // image. Matching on the title rather than trusting any notification with a
    // picture: a mail client's avatar is not album art.
    function _adoptNotificationArt(values) {
        // The handle dies with its notification, so a cover whose source is
        // gone has to go with it rather than leaving a broken image behind.
        if (root.notificationArtId !== null) {
            let alive = false;
            for (const n of values) {
                if (n && n.id === root.notificationArtId) {
                    alive = true;
                    break;
                }
            }
            if (!alive) {
                root.notificationArt = "";
                root.notificationArtId = null;
            }
        }

        if (root.artUrl !== "" || root.title === "") return;
        for (let i = values.length - 1; i >= 0; i--) {
            const n = values[i];
            if (!n || !n.image || n.image === "") continue;
            const text = ((n.summary || "") + " " + (n.body || "")).toLowerCase();
            if (text.indexOf(root.title.toLowerCase()) >= 0) {
                root.notificationArt = n.image;
                root.notificationArtId = n.id;
                return;
            }
        }
    }

    // Whether this notification is the player saying what the shell is already
    // saying in the corner.
    //
    // Every track change arrived twice: the corner card at the bottom right and
    // the player's own notification at the top right, two announcements of one
    // event in two corners. The same title test that adopts a notification's
    // cover identifies it, and the guards keep it narrow -- only while the card
    // is actually up, and never on a title short enough to appear in unrelated
    // text by accident. The notification is only kept out of the toast stack;
    // it is still in the history like any other.
    function announcesTrack(notification) {
        if (!root.osdShown || root.title.length < 5) return false;
        if (!notification) return false;
        const text = ((notification.summary || "") + " " + (notification.body || "")).toLowerCase();
        return text.indexOf(root.title.toLowerCase()) >= 0;
    }

    // A new track invalidates whatever the last notification handed over.
    onTitleChanged: {
        root.notificationArt = "";
        root.notificationArtId = null;
    }

    // ── Controls ──
    function togglePlay() {
        if (player && player.canTogglePlaying) player.togglePlaying();
        showOsd();
    }

    function next() {
        if (player && player.canGoNext) player.next();
        showOsd();
    }

    function previous() {
        if (player && player.canGoPrevious) player.previous();
        showOsd();
    }

    // Shuffle and repeat, which every player exposes and nothing in this shell
    // could reach until the media page needed them.
    readonly property bool shuffleOn: root.player !== null && root.player.shuffle
    readonly property bool canShuffle: root.player !== null && root.player.shuffleSupported

    function toggleShuffle() {
        if (root.canShuffle) root.player.shuffle = !root.player.shuffle;
    }

    readonly property int loopState: root.player ? root.player.loopState : 0
    readonly property string loopGlyph: {
        if (root.loopState === MprisLoopState.Track) return Glyphs.repeatOne;
        if (root.loopState === MprisLoopState.Playlist) return Glyphs.repeatAll;
        return Glyphs.repeatOff;
    }

    // None -> playlist -> track -> none, which is the order every player's own
    // button walks and therefore the one people expect.
    function cycleLoop() {
        if (!root.player || !root.player.loopSupported) return;
        if (root.loopState === MprisLoopState.None) {
            root.player.loopState = MprisLoopState.Playlist;
        } else if (root.loopState === MprisLoopState.Playlist) {
            root.player.loopState = MprisLoopState.Track;
        } else {
            root.player.loopState = MprisLoopState.None;
        }
    }

    // fraction is 0..1 of total length.
    //
    // Never quite to the end: setting the position to the length itself ends
    // the track, so dragging the wave all the way right skipped to the next
    // song instead of seeking. Half a second short is indistinguishable to look
    // at and does what was asked.
    function seek(fraction) {
        if (!player || !player.canSeek || root.length <= 0) return;
        const target = Math.max(0, Math.min(1, fraction)) * root.length;
        player.position = Math.min(target, Math.max(0, root.length - 0.5));
        // The poll below only asks once a second, so without this the position
        // shown after a seek is the one from before it for up to a second --
        // which reads as the seek having been ignored.
        seekSettle.restart();
    }

    // Asks the player where it is, several times, right after being told to
    // move. Players answer a SetPosition at their own pace and some only report
    // the new position on the next tick of their own clock.
    property Timer _seekSettle: Timer {
        id: seekSettle
        interval: 90
        repeat: true
        property int ticks: 0
        onTriggered: {
            if (root.player) root.player.positionChanged();
            seekSettle.ticks++;
            if (seekSettle.ticks > 12) {
                seekSettle.stop();
                seekSettle.ticks = 0;
            }
        }
        onRunningChanged: if (running) seekSettle.ticks = 0
    }

    // MPRIS position is only refreshed on demand, so without this poll every
    // progress bar in the shell sits frozen while a track plays.
    Timer {
        interval: 1000
        running: root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged()
    }
}
