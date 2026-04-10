# SJH Skills

A collection of Claude Code skills for research workflow automation. Each skill is self-contained under `skills/<name>/` with its own `SKILL.md`, `scripts/`, and `references/`.

## Repository Structure

```
sjh_skills/
├── skills/
│   ├── scholar-agent/     # Scholar Inbox + NotebookLM deep reading
│   ├── cmux/              # Ghostty terminal orchestration + multi-agent
│   ├── daily-summary/     # Git + Claude sessions + Notion aggregation
│   ├── notion-lifeos/     # PARA method + Make Time via Notion API
│   ├── web-fetcher/       # 5-layer fallback web content extraction
│   ├── init-project/      # Claude Code project initialization
│   ├── project-review/    # 5-dimension strategy review snapshot
│   ├── remote-cluster-agent/ # Remote GPU cluster ops via persistent SSH agent
│   ├── codex-review/          # Cross-model plan/code review via OpenAI Codex
│   └── paper-analyzer/        # Deep critical paper analysis with causal chain methodology
├── CHANGELOG.md           # Version history (must be updated on every change)
├── README.md              # English
└── README.zh-CN.md        # Chinese
```

## Conventions

### Skill Anatomy

Every skill follows this structure:

```
skill-name/
├── SKILL.md          # Required — frontmatter (name, description) + instructions
├── README.md         # English documentation
├── README.zh-CN.md   # Chinese documentation (if applicable)
├── scripts/          # Executable scripts
├── references/       # Docs loaded into context as needed
└── assets/           # Templates, icons, fonts
```

### Language

- **SKILL.md** — Written in English. Chinese trigger words preserved in the `description` field.
- **README.md** — English.
- **README.zh-CN.md** — Chinese (use `zh-CN` suffix, not `zh`).

### Install Commands

All install commands must use the shorthand format:

```bash
npx skills add jiahao-shao1/sjh-skills --skill <name>
```

Never use full `https://github.com/...` URLs or point to standalone repos that no longer exist.

## Behavior Boundaries

### Always Do

- Read the existing SKILL.md before modifying a skill
- Update `CHANGELOG.md` for every change — group entries under the skill name, use [Keep a Changelog](https://keepachangelog.com/) format
- Bump `.claude-plugin/plugin.json` version on every skill change — minor for new features, patch for fixes/improvements
- Keep install commands consistent across all READMEs (root, English, Chinese) when adding or renaming a skill
- Update the skill table in both `README.md` and `README.zh-CN.md` when adding a new skill
- Test skill triggering by reviewing the `description` field — it's the primary mechanism Claude uses to decide whether to invoke a skill

### Ask First

- Renaming a skill directory (breaks existing installs)
- Removing a skill from the monorepo
- Changing the `description` field format or triggering strategy
- Adding external dependencies to a skill's `scripts/`

### Never Do

- Hardcode API keys, tokens, or user-specific paths in SKILL.md or scripts
- Write SKILL.md body in Chinese (description trigger words are fine)
- Use `README.zh.md` naming — always use `README.zh-CN.md`
- Use full GitHub URLs in install commands — use `jiahao-shao1/sjh-skills --skill <name>`
- Point install commands to standalone repos (e.g., `jiahao-shao1/notion-lifeos-skill`) — everything is in the monorepo now

## Changelog

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/). Every change must be recorded before committing:

- **Added** — new skills, features, scripts
- **Changed** — rewrites, refactors, behavior changes
- **Fixed** — bug fixes
- **Improved** — optimization, description tuning
- **Removed** — deleted features or skills

Bump the version number when releasing a coherent set of changes. Use semver: major (breaking), minor (new skill or feature), patch (fixes and improvements).
