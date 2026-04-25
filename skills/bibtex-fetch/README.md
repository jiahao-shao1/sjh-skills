# bibtex-fetch

Fetch correct BibTeX entries from arXiv and Semantic Scholar. Eliminates citation hallucinations by pulling metadata directly from authoritative APIs.

## Install

```bash
npx skills add jiahao-shao1/sjh-skills --skill bibtex-fetch
```

## Usage

### Fetch by arXiv ID

```bash
python3 scripts/bibtex_fetch.py fetch 2312.14135
python3 scripts/bibtex_fetch.py fetch 2312.14135 2505.14362 --key vstar deepeyes
```

### Search by title

```bash
python3 scripts/bibtex_fetch.py search "V* Guided Visual Search"
```

## Requirements

- Python 3.10+ (stdlib only, no pip dependencies)

## Why

AI-generated BibTeX entries frequently contain hallucinated arXiv IDs, wrong titles, and incorrect authors. This tool fetches ground-truth metadata directly from arXiv and Semantic Scholar APIs.
