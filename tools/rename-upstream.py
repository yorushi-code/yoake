#!/usr/bin/env python3
"""serpantinum -> yoake: механическое переименование дерева апстрима.

Правила здесь -- те же, которыми форк переименовали руками один раз (коммит
af2e216). Записаны кодом потому, что теперь их надо применять к каждому
обновлению апстрима, а помнить исключения через полгода никто не будет.

Скрипт правит дерево на месте и ничего не знает про git: ему дают каталог,
он переименовывает содержимое и пути. Повторный запуск -- пустая операция,
искать в выводе нечего.

    tools/rename-upstream.py <каталог> [--dry-run]
"""

import argparse
import os
import re
import sys

# Три написания покрывают больше, чем выглядит. serpantinumd распадается в
# yoaked, а SERPANTINUM_DIR в YOAKE_DIR без отдельных правил: суффиксы всегда
# прикреплялись к имени, а не жили сами по себе.
#
# serpantinum-wallpapers не трогаем: это собственный flake-вход апстрима,
# указывающий на чужой репозиторий. Переименование молча подменило бы
# зависимость на несуществующую.
LOWER = re.compile(r"serpantinum(?!-wallpapers)")

# ilyamiro/yoake не существует. Ссылки на источник должны называть источник --
# слаг установщика, проверка версии, домашняя страница в nix, языковые файлы и
# ссылки на странице "О программе". Общий проход их ломает, поэтому после него
# слаг возвращается на место.
UPSTREAM_SLUG = ("ilyamiro/yoake", "ilyamiro/serpantinum")

# README апстрима -- не механический перевод. Наш написан руками и первой
# строкой говорит, что это форк; переименовать половину чужого текста значит
# сделать его неверным по-новому. На ветке апстрима он остаётся апстримовским,
# и слияние трогает его только когда апстрим сам его переписал -- что как раз
# стоит увидеть глазами.
SKIP_CONTENT = {"README.md"}

SKIP_DIRS = {".git"}


def rename_text(s):
    s = LOWER.sub("yoake", s)
    s = s.replace("Serpantinum", "Yoake")
    s = s.replace("SERPANTINUM", "YOAKE")
    return s.replace(*UPSTREAM_SLUG)


def rename_path(p):
    # В путях URL не встречаются, возвращать слаг незачем.
    p = LOWER.sub("yoake", p)
    return p.replace("Serpantinum", "Yoake").replace("SERPANTINUM", "YOAKE")


def walk(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            yield os.path.join(dirpath, name)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("root", help="каталог с деревом апстрима")
    ap.add_argument("--dry-run", action="store_true",
                    help="только показать, что изменится")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    if not os.path.isdir(root):
        sys.exit("не каталог: " + root)

    edited = []
    moved = []
    binary = 0

    for path in sorted(walk(root)):
        rel = os.path.relpath(path, root)

        with open(path, "rb") as f:
            raw = f.read()
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            # Картинки, шрифты, звуки: имя может быть и внутри, но переписывать
            # байты вслепую нельзя.
            text = None
            if LOWER.search(rel) or "Serpantinum" in rel:
                binary += 1

        if text is not None and os.path.basename(rel) not in SKIP_CONTENT:
            new_text = rename_text(text)
            if new_text != text:
                edited.append(rel)
                if not args.dry_run:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(new_text)

        new_rel = rename_path(rel)
        if new_rel != rel:
            moved.append((rel, new_rel))
            if not args.dry_run:
                dest = os.path.join(root, new_rel)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                os.rename(path, dest)

    if not args.dry_run:
        # Каталоги, опустевшие после переноса файлов.
        for dirpath, dirnames, filenames in os.walk(root, topdown=False):
            if os.path.basename(dirpath) in SKIP_DIRS:
                continue
            if dirpath != root and not os.listdir(dirpath):
                os.rmdir(dirpath)

    print("содержимое: %d файлов" % len(edited))
    print("пути: %d" % len(moved))
    for old, new in moved:
        print("  %s -> %s" % (old, new))
    if binary:
        print("двоичных с именем в пути: %d (содержимое не тронуто)" % binary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
