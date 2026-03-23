"""Scholar Inbox CLI — command-line interface for Scholar Inbox.

Usage:
    scholar-inbox status
    scholar-inbox login [--cookie VALUE] [--browser]
    scholar-inbox digest [--limit N] [--min-score F] [--date YYYY-MM-DD] [--json]
    scholar-inbox paper PAPER_ID
    scholar-inbox rate PAPER_ID RATING
    scholar-inbox rate-batch RATING ID...
    scholar-inbox trending [--category CAT] [--days N] [--limit N]
    scholar-inbox collections
    scholar-inbox collect PAPER_ID COLLECTION
    scholar-inbox read PAPER_ID
    scholar-inbox config [set KEY VALUE]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import scholar_inbox
from scholar_inbox.api import RATING_MAP, APIError, ScholarInboxClient, SessionExpiredError
from scholar_inbox.auth import (
    extract_from_playwright_profile,
    extract_via_playwright_cli,
    open_browser_for_login,
)
from scholar_inbox.config import Config


def _get_config() -> Config:
    """Build Config from env or default path."""
    config_dir_env = os.environ.get("SCHOLAR_INBOX_CONFIG_DIR")
    if config_dir_env:
        return Config(config_dir=Path(config_dir_env))
    return Config()


def _get_client(config: Config | None = None) -> ScholarInboxClient:
    """Build a client with config-backed session."""
    if config is None:
        config = _get_config()
    return ScholarInboxClient(config=config)


def _parse_rating(value: str) -> int:
    """Parse rating from string — accepts 'up'/'down'/'reset' or '1'/'-1'/'0'."""
    if value in RATING_MAP:
        return RATING_MAP[value]
    try:
        r = int(value)
        if r in (1, -1, 0):
            return r
    except ValueError:
        pass
    print(f"Error: Invalid rating '{value}'. Use up/down/reset or 1/-1/0.", file=sys.stderr)
    sys.exit(1)


# --------------------------------------------------------------------------
# Command handlers
# --------------------------------------------------------------------------


def cmd_status(args):
    """Check login status."""
    config = _get_config()
    session = config.load_session()
    if not session:
        print("Not logged in. Run 'scholar-inbox login' first.")
        return

    try:
        client = _get_client(config)
        data = client.check_session()
        if data and data.get("is_logged_in"):
            print(f"Logged in as: {data.get('name', 'unknown')} (user_id: {data.get('user_id', '?')})")
        else:
            print("Session expired. Run 'scholar-inbox login' to refresh.")
    except SessionExpiredError:
        print("Session expired. Run 'scholar-inbox login' to refresh.")
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def cmd_login(args):
    """Extract or set session cookie."""
    config = _get_config()

    # Manual cookie provided
    if args.cookie:
        config.save_session(args.cookie)
        try:
            client = _get_client(config)
            data = client.check_session()
            if data and data.get("is_logged_in"):
                print(f"Logged in as: {data.get('name', 'unknown')}")
            else:
                print("Warning: Cookie saved but login check failed.", file=sys.stderr)
        except (APIError, Exception) as e:
            print(f"Warning: Cookie saved but verification failed: {e}", file=sys.stderr)
        return

    # Interactive browser login
    if args.browser:
        cookie = open_browser_for_login()
        if cookie:
            config.save_session(cookie)
            print(f"Session saved.", file=sys.stderr)
            try:
                client = _get_client(config)
                data = client.check_session()
                if data and data.get("is_logged_in"):
                    print(f"Logged in as: {data.get('name', 'unknown')}")
                    return
            except Exception:
                pass
            print("Cookie extracted but verification uncertain.", file=sys.stderr)
        else:
            print("Could not extract cookie from browser session.", file=sys.stderr)
            sys.exit(1)
        return

    # Auto-extract: try profile DB first, then playwright-cli
    cookie = extract_from_playwright_profile()
    if cookie:
        config.save_session(cookie)
        print(f"Session saved (from Playwright profile).", file=sys.stderr)
        try:
            client = _get_client(config)
            data = client.check_session()
            if data and data.get("is_logged_in"):
                print(f"Logged in as: {data.get('name', 'unknown')}")
                return
        except Exception:
            pass
        print("Warning: Cookie found but login check failed. May need to re-login.", file=sys.stderr)
        return

    # Fallback: playwright-cli
    print("Could not extract cookie from profile database (likely encrypted).", file=sys.stderr)
    print("Trying playwright-cli...", file=sys.stderr)
    cookie = extract_via_playwright_cli()
    if cookie:
        config.save_session(cookie)
        print(f"Session saved (via playwright-cli).", file=sys.stderr)
        try:
            client = _get_client(config)
            data = client.check_session()
            if data and data.get("is_logged_in"):
                print(f"Logged in as: {data.get('name', 'unknown')}")
                return
        except Exception:
            pass
        print("Cookie extracted but verification uncertain.", file=sys.stderr)
        return

    print("\nCould not extract cookie automatically.", file=sys.stderr)
    print("Options:", file=sys.stderr)
    print("  1. scholar-inbox login --browser    (open browser for OAuth)", file=sys.stderr)
    print("  2. scholar-inbox login --cookie VAL  (paste cookie manually)", file=sys.stderr)
    sys.exit(1)


def cmd_digest(args):
    """Fetch paper digest."""
    client = _get_client()
    try:
        data = client.get_digest(date=args.date)
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not data:
        print("Error: Failed to fetch digest.", file=sys.stderr)
        sys.exit(1)

    papers = data.get("digest_df", [])
    total = data.get("total_papers", len(papers))
    date_str = data.get("current_digest_date", "unknown")

    # Filter by min score
    if args.min_score is not None:
        papers = [p for p in papers if p.get("ranking_score", 0) >= args.min_score]

    # Limit output
    papers = papers[:args.limit]

    # JSON output
    if args.json:
        output = {
            "date": date_str,
            "total_papers": total,
            "showing": len(papers),
            "papers": [
                {
                    "paper_id": p["paper_id"],
                    "title": p["title"],
                    "authors": p.get("shortened_authors", ""),
                    "ranking_score": round(p.get("ranking_score", 0), 3),
                    "rating": p.get("rating"),
                    "arxiv_id": p.get("arxiv_id"),
                    "keywords": p.get("keywords_metadata", {}).get("keywords", ""),
                    "category": p.get("category", ""),
                    "affiliations": p.get("affiliations", []),
                    "publication_date": p.get("publication_date", ""),
                    "abstract": (
                        p.get("abstract", "")[:200] + "..."
                        if len(p.get("abstract", "")) > 200
                        else p.get("abstract", "")
                    ),
                    "contribution": (p.get("summaries") or {}).get(
                        "contributions_question", ""
                    ),
                }
                for p in papers
            ],
        }
        print(json.dumps(output, ensure_ascii=False, indent=2))
        return

    # Human-readable output
    print(f"# Scholar Inbox Digest -- {date_str}")
    print(f"# Total: {total} papers, showing top {len(papers)}\n")

    for i, p in enumerate(papers, 1):
        score = p.get("ranking_score", 0)
        rating = p.get("rating")
        rating_str = " [up]" if rating == 1 else " [down]" if rating == -1 else ""
        keywords = p.get("keywords_metadata", {}).get("keywords", "")
        affiliations = ", ".join((p.get("affiliations") or [])[:3])
        arxiv_id = p.get("arxiv_id", "")

        print(f"{i}. [{p['paper_id']}] {score:.3f}{rating_str} -- {p['title']}")
        print(f"   {p.get('shortened_authors', '')}")
        if affiliations:
            print(f"   Affiliations: {affiliations}")
        if keywords:
            print(f"   Keywords: {keywords}")
        if arxiv_id:
            print(f"   https://arxiv.org/abs/{arxiv_id}")

        summaries = p.get("summaries") or {}
        contrib = summaries.get("contributions_question", "")
        if contrib:
            first_line = contrib.strip().split("\n")[0].strip("- *")
            if first_line:
                print(f"   > {first_line[:120]}")
        print()


def cmd_paper(args):
    """Show paper details."""
    client = _get_client()
    try:
        data = client.get_paper(args.paper_id)
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not data:
        print(f"Paper {args.paper_id} not found.", file=sys.stderr)
        sys.exit(1)

    paper = data
    print(f"# {paper.get('title', 'Unknown')}")
    print(f"Authors: {paper.get('shortened_authors', '')}")
    print(f"Affiliations: {', '.join(paper.get('affiliations') or [])}")
    print(f"Published: {paper.get('publication_date', '')} | {paper.get('display_venue', '')}")
    print(f"Ranking Score: {paper.get('ranking_score', 0):.3f}")
    if paper.get("arxiv_id"):
        print(f"ArXiv: https://arxiv.org/abs/{paper['arxiv_id']}")
    if paper.get("github_url"):
        print(f"GitHub: {paper['github_url']}")
    print(f"Keywords: {paper.get('keywords_metadata', {}).get('keywords', '')}")
    print()

    print("## Abstract")
    print(paper.get("abstract", "N/A"))
    print()

    summaries = paper.get("summaries") or {}
    for key, label in [
        ("problem_definition_question", "Problem"),
        ("method_explanation_question", "Method"),
        ("contributions_question", "Contributions"),
        ("evaluation_question", "Evaluation"),
    ]:
        content = summaries.get(key, "")
        if content:
            print(f"## {label}")
            print(content)
            print()


def cmd_rate(args):
    """Rate a paper."""
    rating = _parse_rating(args.rating)
    client = _get_client()
    try:
        client.rate(args.paper_id, rating)
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    labels = {1: "upvoted", -1: "downvoted", 0: "reset"}
    print(f"Paper {args.paper_id}: {labels[rating]}")


def cmd_rate_batch(args):
    """Batch rate multiple papers."""
    rating = _parse_rating(args.rating)
    client = _get_client()
    try:
        client.rate_batch(args.paper_ids, rating)
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    labels = {1: "upvoted", -1: "downvoted", 0: "reset"}
    print(f"{len(args.paper_ids)} papers: {labels[rating]}")


def cmd_trending(args):
    """Show trending papers."""
    client = _get_client()
    try:
        data = client.get_trending(
            category=args.category,
            days=args.days,
        )
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not data or "trending_df" not in data:
        print("Error: Failed to fetch trending.", file=sys.stderr)
        sys.exit(1)

    papers = data["trending_df"][:args.limit]
    print(f"# Trending Papers (last {args.days} days, category: {args.category})\n")

    for i, p in enumerate(papers, 1):
        print(f"{i}. [{p.get('paper_id', '')}] {p.get('title', 'Unknown')}")
        print(f"   {p.get('shortened_authors', '')}")
        if p.get("arxiv_id"):
            print(f"   https://arxiv.org/abs/{p['arxiv_id']}")
        print()


def cmd_collections(args):
    """List user collections."""
    client = _get_client()
    try:
        collections = client.get_collections()
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not collections:
        print("No collections found.")
        return

    print("# Collections\n")
    for c in collections:
        cid = c.get("collection_id", c.get("id", "?"))
        name = c.get("collection_name", c.get("name", "Unnamed"))
        count = c.get("paper_count", "?")
        print(f"  [{cid}] {name} ({count} papers)")


def cmd_collect(args):
    """Add a paper to a collection."""
    client = _get_client()

    # Resolve collection: try as integer ID first, then as name
    collection_id = None
    try:
        collection_id = int(args.collection)
    except ValueError:
        # Look up by name
        try:
            collections = client.get_collections()
        except SessionExpiredError:
            print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
            sys.exit(1)
        except APIError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)

        name_lower = args.collection.lower()
        for c in collections:
            cname = c.get("collection_name", c.get("name", ""))
            if cname.lower() == name_lower:
                collection_id = c.get("collection_id", c.get("id"))
                break

        if collection_id is None:
            print(f"Error: Collection '{args.collection}' not found.", file=sys.stderr)
            print("Available collections:", file=sys.stderr)
            for c in collections:
                cid = c.get("collection_id", c.get("id", "?"))
                cname = c.get("collection_name", c.get("name", "Unnamed"))
                print(f"  [{cid}] {cname}", file=sys.stderr)
            sys.exit(1)

    try:
        result = client.add_to_collection(collection_id, args.paper_id)
        print(f"Paper {args.paper_id} added to collection {collection_id}")
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def cmd_read(args):
    """Mark a paper as read."""
    client = _get_client()
    try:
        client.mark_as_read(args.paper_id)
    except SessionExpiredError:
        print("Error: Session expired. Run 'scholar-inbox login' first.", file=sys.stderr)
        sys.exit(1)
    except APIError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Paper {args.paper_id}: marked as read")


def cmd_config(args):
    """Show or set configuration values."""
    config = _get_config()

    if args.action == "set":
        if not args.key or args.value is None:
            print("Usage: scholar-inbox config set KEY VALUE", file=sys.stderr)
            sys.exit(1)
        config.set(args.key, args.value)
        print(f"Set {args.key} = {args.value}")
    else:
        # Show all config
        data = config.all()
        if not data:
            print("No configuration set.")
            return
        for k, v in data.items():
            print(f"{k} = {v}")


# --------------------------------------------------------------------------
# Argument parser
# --------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    """Build the CLI argument parser."""
    parser = argparse.ArgumentParser(
        prog="scholar-inbox",
        description="Scholar Inbox CLI -- manage your daily paper digest from the terminal.",
    )
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {scholar_inbox.__version__}"
    )

    subparsers = parser.add_subparsers(dest="command")

    # status
    subparsers.add_parser("status", help="Check login status")

    # login
    login_p = subparsers.add_parser("login", help="Extract/set session cookie")
    login_p.add_argument("--cookie", help="Manually provide session cookie value")
    login_p.add_argument(
        "--browser", action="store_true", help="Open browser for interactive OAuth login"
    )

    # digest
    digest_p = subparsers.add_parser("digest", help="Fetch paper digest")
    digest_p.add_argument("--limit", type=int, default=10, help="Max papers to show (default: 10)")
    digest_p.add_argument("--min-score", type=float, help="Minimum ranking score filter")
    digest_p.add_argument("--date", help="Specific date (YYYY-MM-DD)")
    digest_p.add_argument("--json", action="store_true", help="Output as JSON")

    # paper
    paper_p = subparsers.add_parser("paper", help="Show paper details")
    paper_p.add_argument("paper_id", type=int, help="Paper ID")

    # rate
    rate_p = subparsers.add_parser("rate", help="Rate a paper (up/down/reset or 1/-1/0)")
    rate_p.add_argument("paper_id", type=int, help="Paper ID")
    rate_p.add_argument("rating", help="Rating: up/down/reset or 1/-1/0")

    # rate-batch
    batch_p = subparsers.add_parser("rate-batch", help="Batch rate papers")
    batch_p.add_argument("rating", help="Rating: up/down/reset or 1/-1/0")
    batch_p.add_argument("paper_ids", type=int, nargs="+", help="Paper IDs")

    # trending
    trending_p = subparsers.add_parser("trending", help="Show trending papers")
    trending_p.add_argument("--category", default="ALL", help="Category filter (default: ALL)")
    trending_p.add_argument("--days", type=int, default=7, help="Time range in days (default: 7)")
    trending_p.add_argument("--limit", type=int, default=10, help="Max papers (default: 10)")

    # collections
    subparsers.add_parser("collections", help="List collections")

    # collect
    collect_p = subparsers.add_parser("collect", help="Add paper to collection")
    collect_p.add_argument("paper_id", type=int, help="Paper ID")
    collect_p.add_argument("collection", help="Collection name or ID")

    # read
    read_p = subparsers.add_parser("read", help="Mark paper as read")
    read_p.add_argument("paper_id", type=int, help="Paper ID")

    # config
    config_p = subparsers.add_parser("config", help="Show or set configuration")
    config_p.add_argument("action", nargs="?", choices=["set"], help="Action (set)")
    config_p.add_argument("key", nargs="?", help="Config key")
    config_p.add_argument("value", nargs="?", help="Config value")

    return parser


def main(argv: list[str] | None = None):
    """CLI entry point."""
    parser = build_parser()
    args = parser.parse_args(argv)

    if not args.command:
        parser.print_help()
        sys.exit(0)

    commands = {
        "status": cmd_status,
        "login": cmd_login,
        "digest": cmd_digest,
        "paper": cmd_paper,
        "rate": cmd_rate,
        "rate-batch": cmd_rate_batch,
        "trending": cmd_trending,
        "collections": cmd_collections,
        "collect": cmd_collect,
        "read": cmd_read,
        "config": cmd_config,
    }

    handler = commands.get(args.command)
    if handler:
        handler(args)
    else:
        parser.print_help()
        sys.exit(1)
