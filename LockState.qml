pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Session lock state and the one PAM conversation behind it.
//
// Kept out of the surface so there is exactly one authentication in flight no
// matter how many screens are showing a lock surface, and so the lock survives
// a surface being created or destroyed by a monitor being plugged in.
Singleton {
    id: root

    property bool locked: false
    // What the user has typed but not yet submitted. Held here rather than in
    // the field so a second monitor's surface shows the same dots.
    property string entry: ""
    property bool busy: false
    property bool failed: false
    property string message: ""
    property int attempts: 0

    signal shake()

    function lock() {
        if (root.locked) return;
        root.entry = "";
        root.failed = false;
        root.message = "";
        root.attempts = 0;
        root.locked = true;
    }

    function submit() {
        if (root.busy || root.entry === "") return;
        root.busy = true;
        root.failed = false;
        root.message = "";
        // start() opens the conversation; PAM then asks for the password
        // through pamMessage and the answer goes back with respond().
        if (!pam.start()) {
            root.busy = false;
            root.failed = true;
            root.message = "PAM не отвечает";
            root.shake();
        }
    }

    PamContext {
        id: pam
        // /etc/pam.d/yshell, which is `auth include login` — the same shape
        // swaylock and hyprlock ship. Its own file rather than borrowing
        // theirs, so this lock is not authenticating as something it is not,
        // and so the stack can be changed for it alone.
        config: "yshell"
        user: Quickshell.env("USER")

        onPamMessage: {
            if (!pam.responseRequired) {
                if (pam.messageIsError) root.message = pam.message;
                return;
            }
            pam.respond(root.entry);
        }

        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.entry = "";
                root.failed = false;
                root.locked = false;
                return;
            }
            root.attempts += 1;
            root.entry = "";
            root.failed = true;
            root.message = result === PamResult.MaxTries
                ? "Слишком много попыток"
                : "Неверный пароль";
            root.shake();
        }

        onError: err => {
            root.busy = false;
            root.failed = true;
            root.message = "Ошибка проверки: " + err;
            root.shake();
        }
    }

    property IpcHandler handler: IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function state(): string {
            return root.locked ? "locked" : "unlocked";
        }

        // Deliberately no unlock: an IPC that dropped the lock would let anyone
        // with a shell on this machine — an ssh session, a stray script — open
        // the physical screen. The stack was verified before this was removed:
        // a wrong password comes back Failed rather than Error, which is only
        // possible if PAM is reaching the shadow file and a right one would
        // come back Success.
        //
        // If it ever does trap the session, the way out is a TTY: Ctrl+Alt+F2,
        // log in, `pkill niri`.
    }
}
