#!/usr/bin/env python3
"""Fetch correct BibTeX entries from arXiv and Semantic Scholar.

Usage:
    bibtex_fetch.py fetch <arxiv_id> [<arxiv_id> ...] [--key <bibkey> ...]
    bibtex_fetch.py search "<query>"
"""

import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from typing import Optional

ARXIV_API = "https://export.arxiv.org/api/query"
S2_API = "https://api.semanticscholar.org/graph/v1/paper"
NS = {"a": "http://www.w3.org/2005/Atom"}
MAX_AUTHORS = 5
ARXIV_BATCH_SIZE = 20
ARXIV_DELAY = 1.0
S2_DELAY = 0.5


def _http_get(url: str, timeout: int = 30) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "bibtex-fetch/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def _clean_text(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip())


def _format_author(name: str) -> str:
    parts = name.strip().split()
    if len(parts) <= 1:
        return name.strip()
    return f"{parts[-1]}, {' '.join(parts[:-1])}"


def _make_bibkey(authors: list[str], year: str, title: str) -> str:
    last = authors[0].strip().split()[-1].lower() if authors else "unknown"
    last = re.sub(r"[^a-z]", "", last)
    words = re.sub(r"[^a-zA-Z0-9\s]", "", title).split()
    first_word = words[0].lower() if words else "paper"
    skip = {"a", "an", "the", "on", "of", "for", "in", "to", "and", "with", "via", "from"}
    for w in words:
        if w.lower() not in skip:
            first_word = w.lower()
            break
    return f"{last}{year}{first_word}"


def _authors_bibtex(authors: list[str]) -> str:
    formatted = [_format_author(a) for a in authors[:MAX_AUTHORS]]
    if len(authors) > MAX_AUTHORS:
        formatted.append("others")
    return " and ".join(formatted)


def _escape_bibtex(title: str) -> str:
    return title


def fetch_arxiv(arxiv_ids: list[str]) -> dict[str, dict]:
    results = {}
    for i in range(0, len(arxiv_ids), ARXIV_BATCH_SIZE):
        batch = arxiv_ids[i : i + ARXIV_BATCH_SIZE]
        id_list = ",".join(batch)
        url = f"{ARXIV_API}?id_list={id_list}&max_results={len(batch)}"
        try:
            data = _http_get(url)
        except Exception as e:
            print(f"ERROR: arXiv API request failed: {e}", file=sys.stderr)
            continue

        root = ET.fromstring(data)
        for entry in root.findall("a:entry", NS):
            id_url = entry.find("a:id", NS).text
            arxiv_id = id_url.split("/abs/")[-1].split("v")[0]

            title_el = entry.find("a:title", NS)
            if title_el is None or title_el.text is None:
                continue
            title = _clean_text(title_el.text)

            if title.startswith("Error"):
                continue

            authors = []
            for author_el in entry.findall("a:author", NS):
                name_el = author_el.find("a:name", NS)
                if name_el is not None and name_el.text:
                    authors.append(name_el.text)

            year = entry.find("a:published", NS).text[:4]

            cats = []
            for cat in entry.findall("a:category", NS):
                cats.append(cat.get("term", ""))
            primary_cat = cats[0] if cats else ""

            results[arxiv_id] = {
                "title": title,
                "authors": authors,
                "year": year,
                "arxiv_id": arxiv_id,
                "category": primary_cat,
            }

        if i + ARXIV_BATCH_SIZE < len(arxiv_ids):
            time.sleep(ARXIV_DELAY)

    return results


def format_bibtex(info: dict, bibkey: Optional[str] = None) -> str:
    if bibkey is None:
        bibkey = _make_bibkey(info["authors"], info["year"], info["title"])
    title = _escape_bibtex(info["title"])
    authors = _authors_bibtex(info["authors"])
    arxiv_id = info["arxiv_id"]
    year = info["year"]
    return (
        f"@article{{{bibkey},\n"
        f"  title={{{title}}},\n"
        f"  author={{{authors}}},\n"
        f"  journal={{arXiv preprint arXiv:{arxiv_id}}},\n"
        f"  year={{{year}}}\n"
        f"}}"
    )


def search_s2(query: str, limit: int = 5, max_retries: int = 3) -> list[dict]:
    params = urllib.parse.urlencode(
        {"query": query, "limit": limit, "fields": "title,authors,year,externalIds"}
    )
    url = f"{S2_API}/search?{params}"
    data = None
    for attempt in range(max_retries + 1):
        try:
            data = _http_get(url)
            break
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait = 5 * (2**attempt)
                print(f"Rate limited by Semantic Scholar. Waiting {wait}s (attempt {attempt + 1}/{max_retries + 1})...", file=sys.stderr)
                time.sleep(wait)
                if attempt == max_retries:
                    print("ERROR: Semantic Scholar rate limit exceeded after all retries.", file=sys.stderr)
                    return []
            else:
                raise
    if data is None:
        return []

    result = json.loads(data)
    papers = []
    for item in result.get("data", []):
        arxiv_id = None
        ext = item.get("externalIds", {})
        if ext and "ArXiv" in ext:
            arxiv_id = ext["ArXiv"]

        authors = [a.get("name", "") for a in item.get("authors", [])]
        papers.append(
            {
                "title": item.get("title", ""),
                "authors": authors,
                "year": str(item.get("year", "")),
                "arxiv_id": arxiv_id,
                "s2_id": item.get("paperId", ""),
            }
        )
    return papers


def cmd_fetch(args: list[str]):
    keys = []
    ids = []
    i = 0
    while i < len(args):
        if args[i] in ("--key", "--keys", "-k"):
            i += 1
            while i < len(args) and not args[i].startswith("-"):
                keys.append(args[i])
                i += 1
        else:
            ids.append(args[i].strip().rstrip("/"))
            i += 1

    if not ids:
        print("Usage: bibtex_fetch.py fetch <arxiv_id> [--key <bibkey>]", file=sys.stderr)
        sys.exit(1)

    clean_ids = []
    for aid in ids:
        aid = re.sub(r"^https?://arxiv\.org/abs/", "", aid)
        aid = re.sub(r"v\d+$", "", aid)
        clean_ids.append(aid)

    results = fetch_arxiv(clean_ids)

    for idx, arxiv_id in enumerate(clean_ids):
        if arxiv_id in results:
            key = keys[idx] if idx < len(keys) else None
            print(format_bibtex(results[arxiv_id], bibkey=key))
            print()
        else:
            print(f"% NOT FOUND: {arxiv_id}", file=sys.stderr)


def cmd_search(args: list[str]):
    query = " ".join(args)
    if not query:
        print("Usage: bibtex_fetch.py search <query>", file=sys.stderr)
        sys.exit(1)

    papers = search_s2(query)
    if not papers:
        print("No results found.")
        return

    print(f"Found {len(papers)} results:\n")
    for i, p in enumerate(papers, 1):
        arxiv_str = f"arXiv:{p['arxiv_id']}" if p["arxiv_id"] else "no arXiv ID"
        first_author = p["authors"][0] if p["authors"] else "?"
        print(f"  [{i}] {p['title']}")
        print(f"      {first_author} et al., {p['year']} ({arxiv_str})")
        print()

    has_arxiv = [p for p in papers if p["arxiv_id"]]
    if has_arxiv:
        print("--- BibTeX for papers with arXiv IDs ---\n")
        arxiv_ids = [p["arxiv_id"] for p in has_arxiv]
        fetched = fetch_arxiv(arxiv_ids)
        for p in has_arxiv:
            if p["arxiv_id"] in fetched:
                print(format_bibtex(fetched[p["arxiv_id"]]))
                print()
            else:
                print(format_bibtex(p))
                print()


def main():
    if len(sys.argv) < 2:
        print("Usage: bibtex_fetch.py {fetch|search} <args>", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    args = sys.argv[2:]

    if cmd == "fetch":
        cmd_fetch(args)
    elif cmd == "search":
        cmd_search(args)
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        print("Usage: bibtex_fetch.py {fetch|search} <args>", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
