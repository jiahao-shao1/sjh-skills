---
name: sync-docs
description: Check whether documentation needs updating after code changes. Triggered when user says "sync docs", "文档同步", or "检查文档".
---

Find where this project's docs have fallen out of sync with its code, and report it.

Start from what actually changed (`git log`, `git diff`), then read the docs that claim to describe that area. Every project organizes documentation differently — discover this one's layout instead of assuming a standard set of files.

Judge each gap by what a reader would now get wrong. Sync goes both ways: a doc can be missing something the code now does, or still asserting something it no longer does. Stale and redundant text is as much a gap as absent text.

Report only — do not modify anything.
