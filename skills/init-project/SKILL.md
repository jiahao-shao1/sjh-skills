---
name: init-project
description: 初始化新项目的 Claude Code 配置。用户说"初始化项目"、"init project"、"配置 Claude Code"时触发。
---

# Init Project

Automatically configure Claude Code best practices for new projects: directory skeleton, general-purpose agents, hooks, and CLAUDE.md.

## Execution Flow

1. **Phase 1: Generate Skeleton** (deterministic script)
   → Run `scripts/init-skeleton.sh` to create directory structure + boilerplate files
   → Output which files were created

2. **Phase 2: Interactive CLAUDE.md Fill** (LLM + AskUserQuestion)
   → Process `<!-- init-project: 待填充 -->` placeholders section by section
   → For each section: read codebase → generate draft → AskUserQuestion to confirm → write
   → User can reply "skip" to skip any section
   → Detailed guide templates in `details/claude-md-sections.md`

3. **Phase 3: Profile Overlay** (optional)
   → AskUserQuestion: "Want to overlay an additional profile? Currently supported: research"
   → If research selected → run `scripts/init-research-profile.sh`
   → Profile details in `details/research-profile.md`

4. **Output Summary**
   → List all generated/modified files
   → Suggest next steps: review content, git add, start developing

## Phase 2 Section Processing Strategy

| Section | Auto-exploration | User prompt |
|---------|-----------------|-------------|
| Project overview | Read README, pyproject.toml, package.json | "One-line description of this project's core goal?" |
| Models / Key dependencies | Detect imports, API keys, model configs | "What models or external services does this project depend on?" |
| Directory structure | ls + read key file docstrings | "Does this directory layout look correct? Anything to adjust?" |
| Dev workflow | Detect CI, Makefile, scripts/ | "Use the default brainstorming→plans→dev→verify flow?" |
| Dev guide | Detect venv, .env, Dockerfile | "Any special environment setup steps?" |
| Always Do (project-specific) | Read rules/, lint config | "Any cross-module consistency requirements?" |
| Ask First | Scan core files (interfaces, config) | "Which files/dirs require confirmation before modifying?" |
| Never Do | Detect third_party/, .env | "Any absolute don't-touch conventions?" |
| Knowledge quick reference | Scan .claude/knowledge/ | Auto-generate scenario→file mapping table |
| Progressive references | Scan docs/, skills, agents | "Any additional task→reference file mappings to add?" |

## Constraints

- **Idempotent**: existing files are never overwritten, only gaps are filled
- **No auto git add/commit**: user decides when to commit
- **No existing content modification**: only `<!-- init-project: 待填充 -->` placeholders are touched
- **Scripts run standalone**: `init-skeleton.sh` and `init-research-profile.sh` work independently of the skill

## References

- Skeleton file manifest: `details/skeleton-manifest.md`
- CLAUDE.md section guide: `details/claude-md-sections.md`
- Agent templates: `details/agent-templates.md`
- Research profile: `details/research-profile.md`
