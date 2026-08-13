import QtQuick
import Quickshell.Services.Pipewire

// What the sound is actually coming out of.
//
// There was no bluetooth in this bar at all, which is the plainest example of
// the whole problem: the machine can be playing into headphones, into the
// laptop, or into nothing, and the shell had no opinion about telling you
// which. Naming the device is most of the value — "JBL Tune 720BT" answers the
// question people ask out loud.
//
// Read off the audio graph rather than off bluetoothctl, deliberately. What is
// worth a chip in the bar is the device that is *carrying the sound*, and
// PipeWire already knows which node that is and what bus it is on; polling a
// second daemon to learn the same thing would be a process running all session
// to confirm something the shell is already bound to.
Item {
    id: root

    implicitWidth: chip.implicitWidth
    implicitHeight: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var props: root.sink && root.sink.properties ? root.sink.properties : ({})
    readonly property bool wireless: (root.props["device.bus"] || "") === "bluetooth"
    readonly property string form: (root.props["device.form-factor"] || "").toLowerCase()

    readonly property string deviceName: root.sink
        ? (root.sink.description || root.sink.nickname || root.sink.name || "")
        : ""

    Chip {
        id: chip
        anchors.centerIn: parent
        tone: "bt"
        live: root.wireless
        glyph: root.wireless
            ? (root.form === "headset" || root.form === "headphone"
                ? Glyphs.headphones : Glyphs.bluetooth)
            : Glyphs.bluetoothOff
        // Only when it is worth the room. A wired laptop speaker is the default
        // state of the machine and does not need naming; a device the sound
        // travelled to does.
        label: root.wireless ? root.deviceName : ""
        labelCap: 118
        onClicked: Toggles.toggleSheet("bt")
    }

    Tooltip {
        anchorItem: root
        active: chip.hovered
        text: root.deviceName
        subtext: root.wireless ? "Bluetooth" : "Встроенный выход"
    }
}
