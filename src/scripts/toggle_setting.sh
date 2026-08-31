#!/usr/bin/env bash
# Переключает булеву настройку в settings.json.
#
# Нужен потому, что две вещи, которые удобно вешать на клавишу -- «не
# беспокоить» и «не давать засыпать» -- живут только в конфиге: IPC-обработчика
# у них нет, а Config следит за файлом и подхватывает правку вживую.
#
#     toggle_setting.sh .notifications.dnd
#     toggle_setting.sh .idle.manualInhibit
set -eu
KEY="${1:?путь к ключу, например .notifications.dnd}"
FILE="${QS_SETTINGS:-$HOME/.config/yoake/settings.json}"
[ -f "$FILE" ] || { echo "нет файла настроек: $FILE" >&2; exit 1; }
TMP="$(mktemp "${FILE}.XXXXXX")"
# Пишем во временный и подменяем целиком: FileView читает асинхронно, и
# застигнутый на середине файл разбирается как мусор.
jq "$KEY = ($KEY | not)" "$FILE" > "$TMP" && mv -f "$TMP" "$FILE"
