---
name: sync-docs
description: Update the project's documentation to match recent code changes, then commit. Triggered when user says "sync docs", "文档同步", or "检查文档".
---

Find where this project's docs have fallen out of sync with its code, bring them back in line, and commit the result.

Start from what actually changed (`git log`, `git diff`), then read the docs that claim to describe that area. Every project organizes documentation differently — discover this one's layout instead of assuming a standard set of files.

Judge each gap by what a reader would now get wrong. Sync goes both ways: a doc can be missing something the code now does, or still asserting something it no longer does. Stale text is as much a gap as absent text, so rewrite and delete as readily as you add.

Write the fixes in the voice of the surrounding docs. Stage only the files you edited — never `commit -a`, since the working tree may hold unrelated code changes — and keep docs in their own commit. Then report what you changed, and separately anything you left alone because the diff didn't say enough to answer it.
