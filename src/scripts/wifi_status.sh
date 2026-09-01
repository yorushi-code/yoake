#!/usr/bin/env sh
# Состояние сети для виджета в баре -- без сканирования эфира.
#
# Служба Quickshell.Networking, будучи созданной, шлёт NetworkManager
# RequestScan примерно раз в одиннадцать секунд, и отключить это из QML не
# удалось: ни флаг scannerEnabled на устройстве, ни снятие подписки на список
# точек не помогают. Каждое сканирование уводит радио со своего канала обходить
# все 38, и измерения дали p99 задержки 113 мс против 1,6 мс без оболочки.
#
# Здесь ничего не сканируется: `iw dev link` читает уже установленное
# соединение, `nmcli general`/`dev` -- состояние из демона.
#
# Выводит одну строку: радио|SSID|сигнал_dBm|состояние_ethernet
RADIO=$(nmcli -t -f WIFI general 2>/dev/null)
DEV=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')
ETH=$(nmcli -t -f TYPE,STATE device 2>/dev/null | awk -F: '$1=="ethernet"{print $2; exit}')
SSID=""
SIG=""
if [ -n "$DEV" ]; then
    LINK=$(iw dev "$DEV" link 2>/dev/null)
    SSID=$(printf '%s\n' "$LINK" | sed -n 's/^[[:space:]]*SSID: //p')
    SIG=$(printf '%s\n' "$LINK" | sed -n 's/^[[:space:]]*signal: \(-\{0,1\}[0-9]\{1,\}\).*/\1/p')
fi
printf '%s|%s|%s|%s\n' "$RADIO" "$SSID" "$SIG" "$ETH"
