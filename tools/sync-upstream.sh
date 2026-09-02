#!/usr/bin/env bash
# Тянет обновления апстрима в форк: переименовывает их и вливает.
#
# Апстрим нельзя вливать напрямую. Форк переименован целиком, поэтому любая
# строка, которой апстрим коснулся, расходится с нашей ещё и по имени -- при
# переходе на 2.0.4 так получилось шестнадцать конфликтов, почти все пустые.
#
# Поэтому между нами и апстримом стоит ветка-посредник (upstream-renamed). На
# ней лежит дерево апстрима, уже переименованное, и ничего нашего. Сливая её,
# git сравнивает переименованное с переименованным, и конфликт остаётся только
# там, где мы и апстрим правили одно и то же место по существу.
#
# Коммиты посредника нарочно однородительские: если сделать их слияниями с
# апстримом, его сырые коммиты станут общими предками, база следующего слияния
# уедет к неперeименованному дереву, и конфликты вернутся.
#
# Слияние сначала пробуется в отдельном worktree. Рабочая копия здесь -- живая
# оболочка, quickshell следит за файлами и перечитывает их сам; увидеть QML с
# маркерами конфликта он не должен ни на секунду.
#
#     tools/sync-upstream.sh [--dry-run]

set -euo pipefail

VENDOR="upstream-renamed"
UPSTREAM_REF="upstream/master"
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

die() { echo "  ошибка: $*" >&2; exit 1; }
say() { echo "  $*"; }

command -v git >/dev/null || die "нет git"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "здесь нет репозитория"
cd "$REPO_ROOT"
GIT_DIR_ABS=$(git rev-parse --absolute-git-dir)

git remote get-url upstream >/dev/null 2>&1 || die "нет удалённого 'upstream'"
[ -x tools/rename-upstream.py ] || die "нет tools/rename-upstream.py"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "master" ] || die "нужно быть на master, сейчас: $BRANCH"
[ -z "$(git status --porcelain)" ] || die "рабочая копия не чиста -- сначала закоммить или спрячь правки"

say "забираю апстрим..."
git fetch upstream --quiet

UPSTREAM_SHA=$(git rev-parse "$UPSTREAM_REF")
UPSTREAM_VER=$(git show "$UPSTREAM_REF:version.txt" 2>/dev/null | tr -d '[:space:]')
[ -n "$UPSTREAM_VER" ] || UPSTREAM_VER="неизвестна"

# Родитель для коммита посредника. Впервые -- последний коммит апстрима,
# который уже влит в master напрямую: только тогда база слияния встанет верно.
if git rev-parse --verify --quiet "$VENDOR" >/dev/null; then
    PARENT=$(git rev-parse "$VENDOR")
    LAST_SYNCED=$(git log -1 --format=%B "$VENDOR" | sed -n 's/^Upstream-commit: //p' | head -1)
else
    PARENT=$(git merge-base master "$UPSTREAM_REF") || die "нет общей истории с апстримом"
    LAST_SYNCED=""
    say "ветки $VENDOR ещё нет, начинаю от $(git rev-parse --short "$PARENT")"
fi

if [ "$LAST_SYNCED" = "$UPSTREAM_SHA" ]; then
    say "апстрим не двигался с прошлой синхронизации ($UPSTREAM_VER)"
    exit 0
fi

say "апстрим: $UPSTREAM_VER ($(git rev-parse --short "$UPSTREAM_SHA"))"
if [ -n "$LAST_SYNCED" ]; then
    say "новых коммитов: $(git rev-list --count "$LAST_SYNCED".."$UPSTREAM_SHA" 2>/dev/null || echo '?')"
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Дерево апстрима целиком, затем переименование. Рабочей копии это не касается.
# Дерево лежит в своём подкаталоге: временный индекс git рядом с ним попал бы
# под "add -A" и уехал в коммит -- .sync-index.lock так и уехал однажды.
TREEDIR="$WORK/tree"
mkdir -p "$TREEDIR"
say "переименовываю дерево апстрима..."
git archive "$UPSTREAM_SHA" | tar -x -C "$TREEDIR"
python3 tools/rename-upstream.py "$TREEDIR" | sed 's/^/    /'

if [ "$DRY_RUN" = true ]; then
    say "--dry-run: коммит посредника не создан"
    exit 0
fi

INDEX="$WORK/sync-index"
TREE=$(cd "$TREEDIR" && GIT_DIR="$GIT_DIR_ABS" GIT_INDEX_FILE="$INDEX" \
    sh -c 'git --work-tree="$PWD" add -A . && git --work-tree="$PWD" write-tree')
[ -n "$TREE" ] || die "не удалось собрать дерево"

if [ "$TREE" = "$(git rev-parse "$PARENT^{tree}" 2>/dev/null)" ]; then
    say "переименованное дерево совпало с прошлым, коммитить нечего"
    exit 0
fi

COMMIT=$(git commit-tree "$TREE" -p "$PARENT" <<MSG
upstream $UPSTREAM_VER, renamed

Mechanical: upstream's tree re-materialized and put through
tools/rename-upstream.py. Nothing here is hand-written -- everything of
ours lives on master and arrives by merging this branch into it.

Upstream-commit: $UPSTREAM_SHA
Upstream-version: $UPSTREAM_VER
MSG
)
git update-ref "refs/heads/$VENDOR" "$COMMIT"
say "посредник: $(git rev-parse --short "$COMMIT")"

# Пробное слияние в стороне. Рабочая копия не трогается, пока не станет ясно,
# что конфликтов нет.
say "пробую слить в стороне..."
TRY="$WORK/merge"
git worktree add --quiet --detach "$TRY" master
CONFLICTED=""
# Слияние идёт в отсоединённой голове, и git подписал бы его "into HEAD".
MERGE_MSG="upstream $UPSTREAM_VER

$(git rev-parse --short "$UPSTREAM_SHA"), through $VENDOR."
if ( cd "$TRY" && git merge --no-ff -m "$MERGE_MSG" "$VENDOR" >/dev/null 2>&1 ); then
    MERGED=$(cd "$TRY" && git rev-parse HEAD)
else
    CONFLICTED=$(cd "$TRY" && git diff --name-only --diff-filter=U || true)
    ( cd "$TRY" && git merge --abort >/dev/null 2>&1 || true )
fi
git worktree remove --force "$TRY" >/dev/null 2>&1 || true

if [ -n "$CONFLICTED" ]; then
    echo
    say "конфликты -- рабочая копия не тронута. Файлы:"
    echo "$CONFLICTED" | sed 's/^/    /'
    echo
    say "разбирать так:"
    say "    git merge $VENDOR"
    say "  и после правок -- git commit"
    say "README всегда наш: git checkout --ours README.md"
    exit 2
fi

say "конфликтов нет, перевожу master..."
git merge --ff-only "$MERGED" >/dev/null
say "готово: $(git rev-parse --short HEAD), версия $(cat version.txt 2>/dev/null | tr -d '[:space:]')"
say "оболочка перечитает файлы сама; проверь бар и панели"
