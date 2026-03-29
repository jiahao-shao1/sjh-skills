#!/bin/bash
# Initialize an Obsidian Second Brain vault with dual-zone structure.
# Usage: ./init-vault.sh [vault-path]
# Default: ~/second-brain

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
VAULT_ROOT="${1:-$HOME/second-brain}"

if [ -d "$VAULT_ROOT/.obsidian" ]; then
  echo "Vault already exists at $VAULT_ROOT"
  exit 0
fi

echo "Creating vault at $VAULT_ROOT..."

# Human zone directories (AI: read-only)
mkdir -p "$VAULT_ROOT/notes"
mkdir -p "$VAULT_ROOT/projects"
mkdir -p "$VAULT_ROOT/tasks"
mkdir -p "$VAULT_ROOT/resources"
mkdir -p "$VAULT_ROOT/contexts"
mkdir -p "$VAULT_ROOT/daily"
mkdir -p "$VAULT_ROOT/people"

# AI zone directories (AI: read-write)
mkdir -p "$VAULT_ROOT/ops/drafts"
mkdir -p "$VAULT_ROOT/ops/meetings"
mkdir -p "$VAULT_ROOT/ops/research"

# System directories
mkdir -p "$VAULT_ROOT/templates"
mkdir -p "$VAULT_ROOT/.obsidian"

# Copy templates from skill
if [ -d "$SKILL_DIR/templates" ]; then
  cp "$SKILL_DIR/templates/"*.md "$VAULT_ROOT/templates/" 2>/dev/null || true
fi

# Initialize git
cd "$VAULT_ROOT"
if [ ! -d ".git" ]; then
  git init
  cat > .gitignore << 'GITIGNORE'
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.trash/
GITIGNORE
  git add -A
  git commit -m "init: obsidian second brain vault"
fi

echo "Vault initialized at $VAULT_ROOT"
echo "  Human zone: notes/ projects/ tasks/ resources/ contexts/ daily/ people/"
echo "  AI zone:    ops/"
echo "  Templates:  templates/"
echo ""
echo "Open this folder in Obsidian to start using it."
