---
name: sync-docs
description: Check whether documentation needs updating after code changes. Triggered when user says "sync docs", "文档同步", or "检查文档".
---

Check recent code changes (`git diff HEAD~5 --name-only`), scan the project's documentation system, and report what needs updating.

Checklist items (detect based on directories that actually exist in the project):

1. **Knowledge base** — Does `docs/knowledge/` have new learnings to record?
2. **Experiment registry** — Are new experiments registered in the registry?
3. **Project instructions** — Does the `CLAUDE.md` index table cover all knowledge files?
4. **Rules** — Are there new hard constraints to codify in `.claude/rules/`?
5. **README** — Does the project README match the current code structure?
6. **Strategy docs** *(only if `docs/strategy/` exists)* — Do vision, roadmap, or paper-outline reflect recent changes? Compare `git log` activity against strategy doc last-modified dates. Flag docs that haven't been updated in 5+ commits of relevant code changes. Pair with `/project-review` for full strategic analysis.

Output a checklist marking each item as "needs update" or "up to date". Report only — do NOT auto-modify.
