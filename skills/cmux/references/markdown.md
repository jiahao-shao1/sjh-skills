# cmux Markdown Viewer — Full Reference

## Core Usage

```bash
cmux markdown open plan.md                         # open in current workspace
cmux markdown open /path/to/PLAN.md                # absolute path
cmux markdown open design.md --workspace workspace:2
cmux markdown open plan.md --surface surface:5
cmux markdown open plan.md --window window:1
```

## Live File Watching

The panel automatically re-renders when the file changes on disk:

- Direct writes (`echo "..." >> plan.md`)
- Editor saves (vim, nano, VS Code)
- Atomic file replacement (write to temp, rename over original)
- Agent-generated plan files updated progressively

If the file is deleted, the panel shows "file unavailable". Close and reopen if the file returns later.

## Agent Integration

### Write plan, then open preview

```bash
cat > plan.md << 'EOF'
# Task Plan
## Steps
1. Analyze the codebase
2. Implement the feature
3. Write tests
EOF

cmux markdown open plan.md
```

### Update in real-time

```bash
# Panel auto-refreshes when the file changes
echo "## Step 1: Complete ✓" >> plan.md
```

## Rendering Support

The markdown panel renders: headings (h1-h6) with dividers, fenced code blocks, inline code, tables with alternating rows, ordered/unordered lists (nested), blockquotes, bold/italic/strikethrough, clickable links, horizontal rules, inline images. Supports light and dark mode.
