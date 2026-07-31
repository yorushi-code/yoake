import QtQuick
import Quickshell
import Quickshell.Services.UPower

// The machine's vital signs, large.
//
// Three rings across the top because that is the comparison worth making —
// which of processor, memory and disk is under pressure — and the detail
// underneath for when the answer is "one of them".
Item {
    id: root

    property bool revealed: true

    readonly property int gap: 14

    DashCard {
        id: rings
        order: 0
        revealed: root.revealed
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 190

        Row {
            anchors.centerIn: parent
            spacing: 46

            DashRing {
                value: SysInfo.cpu
                primary: Math.round(SysInfo.cpu * 100) + "%"
                label: "Процессор"
                secondary: SysInfo.temperature > 0 ? SysInfo.temperature + " °C" : ""
                arcColor: SysInfo.cpu > 0.85 ? Theme.red
                    : (SysInfo.cpu > 0.6 ? Theme.yellow : Theme.accent)
            }

            DashRing {
                value: SysInfo.memory
                primary: SysInfo.formatGb(SysInfo.memoryUsedGb) + " ГиБ"
                label: "Память"
                secondary: "из " + SysInfo.formatGb(SysInfo.memoryTotalGb)
                arcColor: SysInfo.memory > 0.9 ? Theme.red
                    : (SysInfo.memory > 0.75 ? Theme.yellow : Theme.blue)
            }

            DashRing {
                value: SysInfo.disk
                primary: Math.round(SysInfo.disk * 100) + "%"
                label: "Диск"
                secondary: SysInfo.formatGb(SysInfo.diskTotalGb) + " ГиБ"
                arcColor: SysInfo.disk > 0.9 ? Theme.red : Theme.green
            }
        }
    }

    // ── Detail ──
    DashCard {
        order: 1
        revealed: root.revealed
        anchors.top: rings.bottom
        anchors.topMargin: root.gap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        title: "Подробно"

        Grid {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 6
            columns: 2
            columnSpacing: 40
            rowSpacing: 11

            readonly property real cell: (width - columnSpacing) / 2

            Repeater {
                model: [
                    { label: "Температура ЦП", value: SysInfo.temperature > 0
                        ? SysInfo.temperature + " °C" : "нет датчика" },
                    { label: "Температура ГП", value: SysInfo.gpuTemperature > 0
                        ? SysInfo.gpuTemperature + " °C" : "нет датчика" },
                    { label: "Аптайм", value: SysInfo.uptimeText },
                    { label: "Ядро", value: SysInfo.kernel },
                    { label: "Батарея", value: UPower.displayDevice.isLaptopBattery
                        ? Math.round(UPower.displayDevice.percentage * 100) + "%" : "нет" },
                    { label: "Свободно на диске", value: SysInfo.formatGb(
                        SysInfo.diskTotalGb - SysInfo.diskUsedGb) + " ГиБ" },
                    { label: "Средняя нагрузка", value: SysInfo.load1.toFixed(2) },
                    { label: "Подкачка", value: SysInfo.swapTotalGb > 0
                        ? SysInfo.formatGb(SysInfo.swapUsedGb) + " из "
                          + SysInfo.formatGb(SysInfo.swapTotalGb) + " ГиБ"
                        : "нет" },
                    { label: "Приём", value: SysInfo.formatRate(SysInfo.rxRate) },
                    { label: "Передача", value: SysInfo.formatRate(SysInfo.txRate) },
                    { label: "Система", value: SysInfo.distro },
                    { label: "Хост", value: SysInfo.host }
                ]

                delegate: Item {
                    id: fact
                    required property var modelData
                    width: parent.cell
                    height: 20

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: fact.modelData.label
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: fact.modelData.value
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
