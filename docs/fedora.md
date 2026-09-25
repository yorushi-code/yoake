# Running yoake on Fedora

Verified on Fedora 44, niri 26.04, quickshell 0.2.1 (`0.2.1^git20260209`, the
only build Fedora ships).

## Installing

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yorushi-code/yoake/master/install/install.sh)"

# or from a checkout:
git clone https://github.com/yorushi-code/yoake.git && cd yoake
bash install/install.sh                          # asks: yoake or Serpantinum
bash install/install.sh --product yoake --yes    # yoake, no questions
bash install/install.sh --product serpantinum    # clean upstream, its own menus
```

### Clean Serpantinum

`--product serpantinum` (or answering 2) runs `install/serpantinum.sh`: it
clones `ilyamiro/serpantinum` where upstream's own installer would, and runs
that installer. On Arch nothing else happens. On Fedora two things do:

- `install/compat/` goes in front of `PATH` for the duration: `pacman` and
  `yay` shims that answer upstream's queries and installs with dnf, through
  the same name map as yoake (`install/modules/pkg.sh`), and a `sudo` shim,
  because sudo's `secure_path` would otherwise bypass them. Nothing is ever
  removed on Fedora. What Fedora does not package (`gpu-screen-recorder`,
  `wl-gammarelay-rs`) is reported among upstream's failed packages;
  `satty` comes from its release.
- three patches to upstream's cloned installer: `fedora` in its distro
  allowlist, SDDM's Wayland greeter by default (without Xorg the X11 greeter
  would leave no login screen), and GPU detection that does not end the
  installer under `set -e`. Each is checked after it is applied; if upstream
  has changed the lines they target, the script stops instead of guessing.

### yoake

Run it as your user, not root; it asks for sudo where it needs it. Fedora and
its derivatives are detected through `/etc/os-release` (`ID`/`ID_LIKE`), and
every package call goes through `install/modules/pkg.sh`, which maps
upstream's Arch names to Fedora's and installs everything in one dnf
transaction. The Arch path is unchanged.

What it sets up, so that nothing has to be done by hand afterwards:

- packages from the Fedora repositories, plus the fonts the shell names
  (Iosevka Nerd Font downloaded, JetBrains Mono, Font Awesome 6);
- `satty` and `starship`, which Fedora does not package, from their releases
  into `~/.local/bin`; Hyprland through the `solopasha/hyprland` COPR, only if
  Hyprland is chosen;
- the shell into `~/.local/share/yoake`, the compositor config (the old one
  backed up), `~/.config/yoake/settings.json`, wallpapers;
- the equaliser as a PipeWire filter-chain (active from the next login), the
  yoake night kitty colours, the starship prompt and its hook in fish, bash
  and zsh (existing files are backed up as `*.bak.<date>`);
- SDDM with the material-you theme in Wayland mode (Fedora has no Xorg), as
  the display manager from the next boot.

Deliberately not done: `gpu-screen-recorder` and `wl-gammarelay-rs` are not
packaged for Fedora and are optional (recording falls back to `wf-recorder`;
the blue light filter is simply unavailable). Display managers are switched
for the next boot only: the installer usually runs inside a graphical session,
which stopping the current display manager would end.

The rest of this document is the manual path, written down as it was walked
before the installer supported Fedora; it explains what the installer does.

## Quickshell version

It runs on 0.2.1. This was worth checking rather than assuming: upstream
squashed its history and cut v2.0.0 on 2026-08-30, nine days after Quickshell
0.3.1, and declares no minimum version anywhere. It loads with no import errors
regardless, so there is no reason to leave Fedora's package for a COPR build or
a local prefix yet.

If that changes, the failure will be loud — missing QML types at startup, in
`qs`'s own stderr — not subtle.

## Running it

The shell finds its assets, scripts and sounds through `$YOAKE_DIR`, which must
point at the `src/` directory. `bin/yoake` and `bin/yoaked` derive it from their
own location, so from a checkout they need nothing:

```bash
bin/yoaked start
```

Running `qs -p src/quickshell/Shell.qml` by hand without that variable set is
the one mistake worth warning about, because it half-works: the bar draws and
reads real system state, but every panel-opening click is silently dead, since
each widget opens its popout through `$YOAKE_DIR/scripts/qs_manager.sh`.

## Configuration

`~/.config/yoake/settings.json`, seeded once from `config/yoake/settings.json`
and live-reloaded thereafter. Two keys matter for this fork:

```json
"theme": { "matugen": false, "yoake": true }
```

`yoake: true` puts the layer's palette in charge (see below); `matugen: false`
stops upstream's generator from overwriting it. Setting `yoake` to `false`
hands the shell back to upstream's theming unaltered, which is the only
reliable way to tell whether something is the layer's doing.

## Packages

Everything the base shell needs to start was already present. What is missing
from upstream's list, and what each one actually gates:

| Package | Gates | Needed? |
|---|---|---|
| `matugen` | upstream's wallpaper theming | No — the yoake palette layer replaces it |
| `acpi` | nothing | No — it is in upstream's package list, but no code in the tree references it |
| `satty` | annotating a screenshot after taking it | Only for that |
| `gpu-screen-recorder` | screen recording | Only for that |
| `wl-gammarelay-rs` | the blue light filter | Only for that |
| `zbar` | reading a QR code out of a screenshot | Only for that |

`imagemagick` is present as `magick` — Fedora's ImageMagick 7 package, which
upstream's Arch-shaped list names differently. It is a hard dependency of the
palette extractor, not optional.

## Testing without disturbing a running session

Two full shells in one session fight: duplicate bars and wallpaper layers, and
a scrap over the `org.freedesktop.Notifications` bus name, which the one that
started first keeps. Run the fork inside a nested niri instead — **without**
`--session`, so it does not take over D-Bus:

```bash
niri -c /path/to/minimal.kdl -- env YOAKE_DIR=$PWD/src qs -p $PWD/src/quickshell/Shell.qml
```

niri does not forward the child's stderr, so redirect it inside a wrapper
script if you want to read it. `WAYLAND_DISPLAY=wayland-2 grim shot.png` will
screenshot the nested output from outside.

## The palette

`src/scripts/wallpaper-palette.py <image>` writes
`~/.local/state/yoake/generated-colors.json`, which `YoakePalette` watches and
applies to `ThemeBackend`. It also rewrites `~/.config/fuzzel/fuzzel.ini`, so
fuzzel re-themes with the shell.

Note the state path. The shell this was ported from is still installed and
still reads its own palette out of `~/.config/quickshell/generated-colors.json`;
these two must not be pointed at the same file while both are installed.

## VPN: почему правило polkit запрещающее

Ставится один раз, руками:

```bash
sudo install -m 0644 install/polkit/49-mihomo-no-resolved.rules /etc/polkit-1/rules.d/
```

Оно **запрещает**, и это не опечатка.

DNS в туннеле держится на `dns-hijack: ["any:53"]` — mihomo перехватывает
запросы прямо в TUN, и systemd-resolved для этого не нужен. Но при
`tun.auto-route` mihomo вдобавок пытается зарегистрировать туннель в resolved и
прописывает туда `198.18.0.2` — адрес из собственного fake-ip диапазона, плюс
домен `~.` и default-route. Если это удаётся, резолвер начинает слать все
запросы на фиктивный адрес, и имена перестают разрешаться: туннель поднят,
панель выглядит исправной, интернета нет.

Регистрация состоит из четырёх отдельных действий polkit
(`set-domains`, `set-default-route`, `set-dns-servers`, `revert`) — отсюда
четыре запроса пароля подряд при каждом перезапуске туннеля.

Раньше этого не было видно по случайности: в сессии не было агента polkit,
запросы проваливались молча, и туннель оставался на рабочем перехвате. Оболочка
на serpantinum агент запускает — появились диалоги, а с ними и возможность
выдать разрешение, которое ломает DNS. Правило воспроизводит прежнее поведение:
отказ без диалога.

Побочный эффект: ручной `resolvectl dns ...` от этого пользователя тоже
перестанет работать. Откат — удалить файл, перезапускать polkitd не нужно.

Панель, со своей стороны, теперь проверяет `resolvectl status mihomo-tun` при
открытии и прямо говорит, если резолвер всё-таки перехвачен.

## Гритер serpantinum вместо своего

До этого вход держал greetd: `cage -s -- /usr/local/bin/yoake-greeter`, то есть
свой гритер на quickshell из `/usr/share/yoake/greeter/shell.qml`, с обвязкой,
которая перезапускает его несколько раз и только потом отдаёт экран `gtkgreet`.
serpantinum вместо этого возит тему для SDDM — `config/sddm/themes/material-you`
(сторонняя, Darkkal44, MIT).

Что уже сделано и работает без переключения:

```
sudo dnf install sddm sddm-wayland-generic
sudo cp -r config/sddm/themes/material-you/. /usr/share/sddm/themes/material-you/
sudo cp config/sddm/themes/material-you/font/*.ttf /usr/share/fonts/TTF/ && sudo fc-cache -f
```

`/etc/sddm.conf.d/10-material-you.conf` записан с `DisplayServer=wayland`.
Иначе нельзя: Xorg на машине нет вовсе, а SDDM по умолчанию поднимает
X11-гритер. В wayland-режиме он запускает `weston --shell=kiosk`, отсюда и
`sddm-wayland-generic` — сам пакет пустой, он тянет weston.

Тема проверена до переключения, а не после:

```
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/material-you
```

Рисуется целиком — часы, быстрые действия, поле пароля, — и сессию видит
правильно: `SESSION · NIRI`, из `/usr/share/wayland-sessions/niri.desktop`.

Переключение остаётся за человеком, потому что ошибка здесь стоит входа в
систему:

```
sudo systemctl disable greetd
sudo systemctl enable --force sddm
```

`--force` нужен, потому что символьная ссылка `display-manager.service` уже
занята greetd. Действует со следующей загрузки. Не добавляй `--now` к
`disable`: greetd — родитель текущей сессии, и она закроется на месте.

Откат — тем же способом наоборот; greetd и его гритер никуда не делись:

```
sudo systemctl disable sddm
sudo systemctl enable --force greetd
```

Если экран входа не поднялся, до этого можно добраться с текстовой консоли
(Ctrl+Alt+F3).

## Known, and upstream's

Present before any change here, left alone deliberately:

- `Caching.getConfigDir` is called in `quickactions/actions/DrawAction.qml` and
  does not exist.
- `ScreenshotOverlay.qml` calls `.trim()` on something undefined at startup.
- The media widget's marquee scrolls "Nothing is playing" continuously while
  nothing is playing.

Idle CPU measured 18.3% of one core inside a nested compositor shortly after
startup — a rough figure taken under bad conditions, recorded only so there is
something to compare against once it runs for real.

## Скриншоты: зависимости

Апстрим собран под Arch и считает обязательными `satty`, `zbarimg` и
`gpu-screen-recorder`. У нас `src/scripts/screenshot.sh` требует их только
для своего режима: `satty` — разметка (`--edit`), `zbarimg` — сканирование
QR (`--scan-qr`); запись, если `gpu-screen-recorder` не найден, идёт через
`wf-recorder`. Обычный снимок работает с одним `grim`.

Что откуда на Fedora (всё стоит с 10.09.2026):

- `zbarimg` — `sudo dnf install zbar`.
- `satty` — в Fedora не пакуется; бинарник v0.22.0 из релизов
  <https://github.com/gabm/Satty/releases> лежит в `~/.local/bin`
  (скрипт добавляет этот каталог в `PATH` сам).
- `gpu-screen-recorder` 6.1.1 — собран из <https://repo.dec05eba.com/gpu-screen-recorder>
  и поставлен в `/usr/local` (`meson setup --buildtype=release -Dstrip=true
  -Dnvidia_suspend_fix=false build && ninja -C build && sudo meson install -C build`).
  Сборочные пакеты: `gcc-c++ meson libva-devel libcap-devel vulkan-headers
  mesa-libEGL-devel` плюс уже стоявший `ffmpeg-devel` из RPM Fusion.
  Установщик выставляет `cap_sys_admin` на `gsr-kms-server` — так захват
  монитора идёт без запроса пароля. Кодирует `h264_vaapi` на Vega.
  Снести: `sudo rm -rf /usr/local/bin/{gpu-screen-recorder,gsr-cli,gsr-kms-server}
  /usr/local/share/gpu-screen-recorder /usr/local/include/gsr
  /usr/local/share/man/man1/{gpu-screen-recorder,gsr-cli,gsr-kms-server}.1
  /usr/local/lib/systemd/user/gpu-screen-recorder.service`.
- `wf-recorder` остаётся запасным бэкендом (скрипт переключится сам, если
  gpu-screen-recorder пропадёт).
