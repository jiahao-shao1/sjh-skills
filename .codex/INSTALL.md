# Installing SJH Skills for Codex

Enable sjh-skills in Codex via native skill discovery.

## Prerequisites

- Git
- OpenAI Codex CLI

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/jiahao-shao1/sjh-skills.git ~/.codex/sjh-skills
   ```

2. **Create the skills symlinks:**
   ```bash
   mkdir -p ~/.agents/skills
   for skill in ~/.codex/sjh-skills/skills/*/; do
     name=$(basename "$skill")
     ln -sf "$skill" ~/.agents/skills/"$name"
   done
   ```

   This creates one symlink per skill so Codex discovers each skill individually.

3. **Restart Codex** to discover the skills.

## Install a single skill

If you only want specific skills:

```bash
git clone https://github.com/jiahao-shao1/sjh-skills.git ~/.codex/sjh-skills
mkdir -p ~/.agents/skills
ln -sf ~/.codex/sjh-skills/skills/scholar-agent ~/.agents/skills/scholar-agent
ln -sf ~/.codex/sjh-skills/skills/web-fetcher ~/.agents/skills/web-fetcher
```

## Verify

```bash
ls -la ~/.agents/skills/
```

You should see symlinks pointing to skill directories under `~/.codex/sjh-skills/skills/`.

## Updating

```bash
cd ~/.codex/sjh-skills && git pull
```

Skills update instantly through the symlinks.

## Uninstalling

Remove symlinks:

```bash
for skill in ~/.agents/skills/*; do
  case "$(readlink "$skill")" in *sjh-skills*) rm "$skill" ;; esac
done
```

Optionally delete the clone: `rm -rf ~/.codex/sjh-skills`.
