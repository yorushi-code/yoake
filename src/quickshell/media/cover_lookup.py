#!/usr/bin/env python3
"""Finds a cover for a track that came without artwork.

Browsers export artwork only when the page supplies it through the Media
Session API, and many sites do not, so tracks played in Firefox usually arrive
with a title and artist but no mpris:artUrl. This looks the cover up by name:
Deezer's public search first, then the iTunes Search API (neither needs a key).

A result is accepted only if its artist matches one of the track's artists:
a same-titled song by someone else is common, and a wrong cover is worse than
none.

usage: cover_lookup.py TITLE ARTIST   -> prints an image URL, or nothing
"""
import json
import re
import sys
import urllib.parse
import urllib.request

TIMEOUT = 4
# Suffixes that are edits of the same recording and hide it from search.
EDIT_SUFFIX = re.compile(
    r"\s+[-–—]\s+(slowed|sped\s*up|speed\s*up|reverb|nightcore|remaster|live|lyrics?|official|audio|video|phonk|bass\s*boosted).*$",
    re.IGNORECASE)
BRACKETS = re.compile(r"\s*[(\[][^)\]]*[)\]]")


def clean_title(title):
    title = BRACKETS.sub("", title)
    title = EDIT_SUFFIX.sub("", title)
    return title.strip()


def split_artists(artist):
    parts = re.split(r",|&|\bfeat\.?|\bft\.?|\bx\b|;", artist, flags=re.IGNORECASE)
    return [p.strip().lower() for p in parts if p.strip()]


def artist_matches(candidate, wanted):
    candidate = candidate.lower()
    return any(w in candidate or candidate in w for w in wanted)


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "yoake-shell"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.load(resp)


def deezer(query, wanted):
    data = fetch_json("https://api.deezer.com/search?limit=10&q=" + urllib.parse.quote(query))
    for hit in data.get("data", []):
        names = [hit.get("artist", {}).get("name", "")]
        names += [c.get("name", "") for c in hit.get("contributors", [])]
        if any(artist_matches(n, wanted) for n in names if n):
            cover = hit.get("album", {}).get("cover_xl") or hit.get("album", {}).get("cover_big")
            if cover:
                return cover
    return None


def itunes(query, wanted):
    data = fetch_json("https://itunes.apple.com/search?entity=song&limit=10&term=" + urllib.parse.quote(query))
    for hit in data.get("results", []):
        if artist_matches(hit.get("artistName", ""), wanted) and hit.get("artworkUrl100"):
            return hit["artworkUrl100"].replace("100x100bb", "1000x1000bb")
    return None


def main():
    if len(sys.argv) < 3:
        return
    title, artist = clean_title(sys.argv[1]), sys.argv[2].strip()
    wanted = split_artists(artist)
    if not title or not wanted:
        return
    first = wanted[0]
    attempts = [
        (deezer, f'artist:"{first}" track:"{title}"'),
        (deezer, f"{first} {title}"),
        (itunes, f"{first} {title}"),
    ]
    for search, query in attempts:
        try:
            url = search(query, wanted)
        except Exception:
            continue
        if url:
            print(url)
            return


if __name__ == "__main__":
    main()
