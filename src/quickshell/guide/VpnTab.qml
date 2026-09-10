import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

// Что делает VPN-панель и чем именно управляет.
//
// Панель стоит на двух опорах, и знать, где проходит граница, полезно: когда
// что-то не работает, ответ почти всегда лежит по одну сторону от неё. Живое
// управление -- узлы, задержки, режим -- идёт прямо в контроллер mihomo по
// HTTP. Всё, что связано с жизнью процесса и подписками, идёт через yworld.
//
// Строки здесь записаны по-русски прямо в коде, как и в самой панели: этот
// слой так и написан, и разводить в нём два разных подхода хуже, чем один
// неидеальный.
Item {
    id: vpnTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    // Открытие вкладки -- достаточный повод спросить состояние: страница про
    // панель, которая показывает устаревшие цифры, объясняет хуже, чем никакая.
    onVisibleChanged: if (visible) Mihomo.refresh()

    readonly property var sections: [
        {
            title: "На чём это стоит",
            body: "Две опоры, и граница между ними объясняет почти любую неполадку. "
                + "Узлы, задержки, переключение и режим идут прямо в контроллер mihomo "
                + "по HTTP на 127.0.0.1:9090 -- это мгновенно и работает, пока ядро "
                + "живо. Запуск, остановка, подписки и проверка выхода идут через "
                + "yworld: там разбор share-ссылок, подбор user-agent и сборка "
                + "конфига, и переписывать это в оболочку было бы шагом назад."
        },
        {
            title: "Кнопки сверху",
            body: "«Включить» и «Выключить» поднимают и гасят ядро через yworld; пока "
                + "команда идёт, кнопка говорит «...» -- запуск занимает до восьми "
                + "секунд, потому что контроллер опрашивается до первого ответа.\n\n"
                + "«Замерить» гоняет задержки всей группы одним запросом. Само по себе "
                + "это не нужно: панель меряет при открытии, но только то, что ещё ни "
                + "разу не мерилось. Кнопка -- чтобы обновить числа руками.\n\n"
                + "«Выход» спрашивает, каким адресом трафик выходит наружу. Это до "
                + "двенадцати секунд сетевых запросов, поэтому оно не делается само."
        },
        {
            title: "Режим правил",
            body: "«По правилам» -- каждое соединение решается по конфигу: часть идёт "
                + "в туннель, часть напрямую. «Через прокси» -- всё в туннель, включая "
                + "то, что правила пускали мимо. «Напрямую» -- туннель поднят, но не "
                + "используется.\n\n"
                + "Это первое, что стоит проверить, когда сайт открылся не из той "
                + "страны, из которой ожидалось."
        },
        {
            title: "Группы и узлы",
            body: "Вкладки над списком -- группы из конфига. PROXY обычно и есть та, "
                + "что несёт трафик; остальные видны, когда конфиг их заводит.\n\n"
                + "Клик по узлу переключает группу на него и закрывает установленные "
                + "соединения. Без этого старые соединения продолжали бы идти прежним "
                + "узлом, и переключение выглядело бы как не сработавшее.\n\n"
                + "Цвет числа -- это оценка, а не украшение: до 150 мс годится для "
                + "разговора, до 400 -- для страниц, дальше -- заметно. Прочерк значит "
                + "«не мерилось», «нет» -- что узел не ответил. У AUTO и DIRECT "
                + "задержки нет: это не серверы."
        },
        {
            title: "Подписки",
            body: "Секция внизу, свёрнутая: её трогают редко, и отдавать ей половину "
                + "высоты вместо узлов было бы неверно.\n\n"
                + "Плюс разворачивает поля имени и ссылки. У каждой подписки три "
                + "кнопки: сменить ядро по кругу (mihomo -- sing-box -- xray), обновить "
                + "с сервера и удалить. Клик по самой строке поднимает туннель на этой "
                + "подписке, то есть переключается на неё."
        },
        {
            title: "Две полосы предупреждений",
            body: "Красная -- чужой туннель забрал маршрут по умолчанию. Худший случай "
                + "здесь в том, что оба туннеля выглядят исправными, а трафика не несёт "
                + "проигравший. Кнопка «Остановить» гасит соперника.\n\n"
                + "Оранжевая -- systemd-resolved перехвачен туннелем. DNS в туннеле "
                + "держится на перехвате порта 53 самим ядром, и resolved для этого не "
                + "нужен. Но при auto-route ядро пробует записать себя туда, и уходит "
                + "адрес из его же fake-ip диапазона: если запись прошла, резолвер шлёт "
                + "запросы в никуда. Поэтому DNS-сервер на интерфейсе туннеля -- признак "
                + "поломки, а не здоровья. Лечится правилом polkit из install/polkit."
        },
        {
            title: "Чего панель не делает сама",
            body: "Ничего в фоне. Пока панель закрыта, не идёт ни проверка выхода, ни "
                + "поток трафика, ни замеры: всё это включается по её видимости. Это не "
                + "экономия ради экономии -- проверка выхода стоит до двенадцати секунд "
                + "запросов, и раньше она уходила при каждом входе в систему ради "
                + "ответа, на который никто не смотрел."
        }
    ]

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(4)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: docCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: docCol
            width: parent.width
            spacing: rootObj.s(12)

            // Живое состояние: страница про управление должна показывать, что
            // из описанного сейчас правда.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: rootObj.s(4)
                implicitHeight: rootObj.s(52)
                radius: ThemeBackend.borderRadius
                color: Mihomo.running
                    ? Qt.alpha(ThemeBackend.green, 0.12)
                    : Qt.alpha(ThemeBackend.surface2, 0.5)
                border.width: 1
                border.color: Mihomo.running ? Qt.alpha(ThemeBackend.green, 0.4) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: rootObj.s(14)
                    anchors.rightMargin: rootObj.s(14)
                    spacing: rootObj.s(10)

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: {
                            if (!Mihomo.running) return "Туннель выключен";
                            let parts = [];
                            if (Mihomo.active !== "") parts.push(Mihomo.active);
                            parts.push("ядро " + Mihomo.core);
                            if (Mihomo.mode !== "") parts.push("режим " + Mihomo.mode);
                            parts.push("групп: " + Mihomo.groups.length);
                            return parts.join(" · ");
                        }
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(12)
                        color: ThemeBackend.text
                    }

                    ClickButton {
                        height: rootObj.s(30)
                        cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
                        horizontalPadding: rootObj.s(14)
                        buttonText: "Открыть панель"
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        onClicked: Quickshell.execDetached(["bash", "-c",
                            Caching.yoakeDir + "/scripts/qs_manager.sh toggle vpn"])
                    }
                }
            }

            Repeater {
                model: vpnTabRoot.sections

                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: sectionCol.implicitHeight + rootObj.s(26)
                    radius: ThemeBackend.borderRadius
                    color: ThemeBackend.surface0

                    ColumnLayout {
                        id: sectionCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: rootObj.s(13)
                        spacing: rootObj.s(7)

                        Text {
                            text: modelData.title
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: modelData.body
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(12)
                            color: ThemeBackend.subtext1
                            lineHeight: 1.3
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: rootObj.s(8) }
        }
    }
}
