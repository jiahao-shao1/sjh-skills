---
name: bibtex-fetch
description: "Fetch BibTeX entries from arXiv / Semantic Scholar. Triggers: 'fetch bibtex', 'cite this paper', 'arXiv bibtex', '拉 bibtex', '获取引用', '引用这篇论文'. Not for citation format conversion (APA/MLA) or literature review."
---

# BibTeX Fetch

Fetch correct BibTeX entries from arXiv (by ID) or Semantic Scholar (by title search). Zero dependencies — uses only Python stdlib.

## Script

`scripts/bibtex_fetch.py` — single self-contained Python script.

## Commands

### Fetch by arXiv ID

Given one or more arXiv IDs, fetch metadata from the arXiv API and generate BibTeX.

```bash
python3 scripts/bibtex_fetch.py fetch <arxiv_id> [<arxiv_id> ...] [--key <bibkey> ...]
```

**Examples:**

```bash
# Single paper
python3 scripts/bibtex_fetch.py fetch 2312.14135

# Multiple papers
python3 scripts/bibtex_fetch.py fetch 2312.14135 2505.14362 2408.15556

# With custom bibkeys
python3 scripts/bibtex_fetch.py fetch 2312.14135 --key vstar

# Full URL also works
python3 scripts/bibtex_fetch.py fetch https://arxiv.org/abs/2312.14135
```

**Output:** Standard `@article{...}` BibTeX entries, ready to paste into `.bib` files.

### Search by title

Search Semantic Scholar for papers matching a query, then auto-fetch BibTeX for results that have arXiv IDs.

```bash
python3 scripts/bibtex_fetch.py search "<query>"
```

**Examples:**

```bash
python3 scripts/bibtex_fetch.py search "V* Guided Visual Search"
python3 scripts/bibtex_fetch.py search "DeepEyes Thinking with Images"
```

**Output:** Top 5 search results with author, year, and arXiv ID, followed by BibTeX for all results that have arXiv IDs.

## Workflow

When the user asks to cite a paper:

1. If they provide an arXiv ID or URL → use `fetch`
2. If they provide a paper title or description → use `search`
3. If they provide a `.bib` file and ask to check/fix entries → extract arXiv IDs from the file, `fetch` them, compare with existing entries

## Implementation Details

- **arXiv API**: Batches up to 20 IDs per request. 1s delay between batches.
- **Semantic Scholar API**: No auth key needed. 0.5s delay. 429 auto-retry with 5s backoff.
- **Bibkey generation**: `{first_author_last_name}{year}{first_significant_title_word}` (e.g., `wu2023guided`)
- **Author format**: `Last, First` style, max 5 authors then `and others`
- **URL cleaning**: Strips `https://arxiv.org/abs/` prefix and version suffixes (`v1`, `v2`)

## Error Handling

| Error | Behavior |
|-------|----------|
| arXiv ID not found | Prints `% NOT FOUND: <id>` to stderr, continues with next |
| Semantic Scholar 429 | Waits 5s and retries once |
| Network timeout | Prints error to stderr, continues with remaining IDs |
| Non-arXiv paper in search | Shows in results list but no BibTeX generated |
