import QtQuick

// Add-a-subscription form, inline in the panel rather than in a dialog.
//
// The URL is a credential: it carries the provider's access token in its query
// string. It is visible only while being typed and is wiped from the field the
// moment it is handed to the backend, which never shows it again — the panel
// only ever displays the host.
Column {
    id: root

    property bool busy: false
    signal submitted(string name, string url, string userAgent)

    spacing: 8

    function reset() {
        nameField.text = "";
        urlField.text = "";
        agentField.text = "";
    }

    component Field: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder: ""

        width: parent ? parent.width : 0
        height: 34
        radius: Theme.radius
        color: Qt.alpha(Theme.text, input.activeFocus ? 0.12 : 0.06)
        border.width: 1
        border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.7) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            verticalAlignment: Text.AlignVCenter
            color: Theme.text
            font.pixelSize: Theme.fontBody
            selectByMouse: true
            selectionColor: Qt.alpha(Theme.accent, 0.4)
            clip: true

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: field.placeholder
                color: Theme.subtext0
                font.pixelSize: Theme.fontBody
                visible: input.text === ""
            }
        }
    }

    Field {
        id: nameField
        placeholder: "Название"
    }

    Field {
        id: urlField
        placeholder: "Ссылка на подписку"
    }

    Field {
        id: agentField
        // Some providers hand back a different — or empty — node list depending
        // on what asked. Left blank the backend probes several itself.
        placeholder: "User-Agent (необязательно)"
    }

    Rectangle {
        id: submitButton
        width: parent.width
        height: 34
        radius: Theme.radius
        readonly property bool ready: nameField.text.trim() !== "" && urlField.text.trim() !== ""
        color: !submitButton.ready || root.busy
            ? Qt.alpha(Theme.text, 0.08)
            : (submitArea.containsMouse ? Theme.accent : Qt.alpha(Theme.accent, 0.85))
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.centerIn: parent
            text: root.busy ? "Загрузка…" : "Добавить"
            color: submitButton.ready && !root.busy ? Theme.crust : Theme.subtext0
            font.pixelSize: Theme.fontBody
            font.bold: true
        }

        MouseArea {
            id: submitArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: submitButton.ready && !root.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.submitted(nameField.text.trim(), urlField.text.trim(),
                               agentField.text.trim());
                root.reset();
            }
        }
    }
}
