# Event sounds

Eleven samples, all made by `bin/yoake-sfx-build` from one instrument: a sine
with a four-millisecond attack and an exponential tail, peaking at −12 dBFS.

They are generated rather than borrowed for the same reason the icons are one
family. A set assembled from a sound theme is eleven strangers — the freedesktop
theme in particular is a decade of different people's taste — and a shell that
speaks in eleven voices does not sound like one thing.

## The vocabulary

Direction carries the meaning, and it is the whole of it:

| shape | means | events |
|---|---|---|
| two tones **up** | something arrived | `device-added`, `network-up`, `vpn-up`, `complete` |
| two tones **down** | something left | `device-removed`, `network-lost`, `vpn-down` |
| two tones **flat** | something is now running or has stopped | `record-start`, `record-stop` |
| one tone | something to look at | `message` |
| one **low** tone | something is wrong | `error` |

A connect and a disconnect are the same two pitches either way round, so the
pair is audibly one event and its reverse. Nobody has to learn that.

`error` is deliberately outside the set: an error that chimes like everything
else is an error nobody notices.

## Regenerating

    bin/yoake-sfx-build

Idempotent — a file that already exists is left alone, so running it after an
update will not overwrite anything you replaced by hand. Delete the sample you
want rebuilt, or the whole directory for a clean set.

## Why these events and no others

The rule is in `Sfx.qml` and it is the only thing keeping the set small: **a
sound is for something with a consequence off the screen.** Headphones
connecting, a network dropping, a tunnel coming up, a recording ending, an
action failing.

Not: a panel opening, a hover, a focus change, a workspace switch, a preset
button, a seek, a volume step. Every one of those is already answered by
something moving on screen, and a shell that chirps at all of them is a shell
people switch off on the second day — at which point the first list stops being
heard too.

The policy lives in `Sfx.qml` as state watchers rather than at the call sites,
because scattered across five singletons it becomes five people's taste, and
this is exactly the kind of rule that erodes one well-meaning call at a time.

## Playback

`bin/yoake-sfx` keeps one `mpv --idle` alive for the session and takes event
names on stdin, so an event costs a line written to a socket rather than a fork
and an exec. The stream is tagged `media.role=event` so PipeWire does not file
it as music — a click that turns up in the shell's own stream list is a bug
people notice immediately.

Silenced entirely while the screen is being recorded or the microphone is in
use. That is also the most likely reason the reference recording this was
modelled on has no interface sounds in it at all.
