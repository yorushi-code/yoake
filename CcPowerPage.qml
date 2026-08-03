import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Power profile and battery detail.
//
// Profiles come from power-profiles-daemon rather than a fixed list: which ones
// exist depends on the platform driver, and offering one the machine cannot
// enter is worse than not offering it.
Flickable {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: root.battery !== null && root.battery.isLaptopBattery

    contentHeight: list.implicitHeight
    clip: true

    Column {
        id: list
        width: parent.width
        spacing: 14

        Column {
            width: parent.width
            spacing: 8
            visible: Power.available

            Text {
                text: "Профиль"
                color: Theme.subtext1
                font.pixelSize: 11
            }

            Repeater {
                model: Power.profiles

                delegate: CcListRow {
                    required property var modelData
                    required property int index

                    width: list.width
                    label: Power.labelFor(modelData)
                    glyph: Power.glyphFor(modelData)
                    connected: Power.activeProfile === modelData
                    onActivated: Power.setProfile(modelData)
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6
            visible: root.hasBattery

            Text {
                text: "Батарея"
                color: Theme.subtext1
                font.pixelSize: 11
            }

            Rectangle {
                width: parent.width
                height: 10
                radius: Theme.radiusPip
                color: Qt.alpha(Theme.text, Theme.fillMuted)

                Rectangle {
                    width: parent.width * (root.hasBattery ? root.battery.percentage : 0)
                    height: parent.height
                    radius: parent.radius
                    color: root.hasBattery && root.battery.percentage < 0.2 ? Theme.red : Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.animNormal } }
                    Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                }
            }

            Text {
                width: parent.width
                text: {
                    if (!root.hasBattery) return "";
                    const pct = Math.round(root.battery.percentage * 100) + "%";
                    // timeToEmpty/Full are zero while the daemon has not settled
                    // on a rate yet, and "0 ч 0 мин left" reads as a dead
                    // battery rather than as an unknown one.
                    const secs = root.battery.state === UPowerDeviceState.Charging
                        ? root.battery.timeToFull
                        : root.battery.timeToEmpty;
                    if (!secs || secs <= 0) return pct;
                    const h = Math.floor(secs / 3600);
                    const m = Math.floor((secs % 3600) / 60);
                    const left = (h > 0 ? h + " ч " : "") + m + " мин";
                    return root.battery.state === UPowerDeviceState.Charging
                        ? pct + " · до полной " + left
                        : pct + " · осталось " + left;
                }
                color: Theme.subtext0
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.text, Theme.fillMuted)
        }

        Grid {
            width: parent.width
            columns: 2
            spacing: 8

            Repeater {
                model: [
                    { label: "Заблокировать", glyph: Glyphs.lock, act: () => Power.lock() },
                    { label: "Сон", glyph: Glyphs.sleep, act: () => Power.suspend() },
                    { label: "Выйти", glyph: Glyphs.restart, act: () => Power.logOut() },
                    { label: "Перезагрузка", glyph: Glyphs.restart, act: () => Power.reboot() },
                    { label: "Выключить", glyph: Glyphs.power, act: () => Power.powerOff(), danger: true }
                ]

                delegate: Rectangle {
                    id: action
                    required property var modelData

                    width: (list.width - 8) / 2
                    height: 40
                    radius: Theme.radius
                    // Power off tints red on hover — the one destructive action
                    // stands apart.
                    color: actionArea.containsMouse
                        ? (action.modelData.danger ? Theme.red : Qt.alpha(Theme.text, 0.16))
                        : Qt.alpha(Theme.text, Theme.fillSubtle)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    scale: actionArea.pressed ? 0.95 : 1
                    Behavior on scale {
                        NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: action.modelData.glyph
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: Theme.text
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: action.modelData.label
                            color: Theme.text
                            font.pixelSize: 11
                        }
                    }

                    Ripple {
                        anchors.fill: parent
                        radius: parent.radius
                        rippleColor: action.modelData.danger ? Theme.red : Theme.accent
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Toggles.dashboardOpen = false;
                            action.modelData.act();
                        }
                    }
                }
            }
        }
    }
}
