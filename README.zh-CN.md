# SJH Skills

[English](README.md) | 中文

> 一组用于科研工作流自动化的 Claude Code Skills。

## 技能列表

| Skill | 说明 |
|-------|------|
| [scholar-agent](skills/scholar-agent/) | 懂你品味的论文 Agent —— Scholar Inbox 发现论文 + NotebookLM 深度阅读 |
| [cmux](skills/cmux/) | 终端编排 —— 分屏、启动 Claude Code 实例、浏览器自动化 |
| [daily-summary](skills/daily-summary/) | 每日工作总结 —— 聚合 git commits、Claude sessions 和 Notion 任务 |
| [notion-lifeos](skills/notion-lifeos/) | Notion PARA 生活管理 + Make Time 日记系统 |
| [web-fetcher](skills/web-fetcher/) | 网页抓取 —— Jina → defuddle → markdown.new 三级 fallback |

## 安装

**安装全部：**

```bash
claude install-skill https://github.com/jiahao-shao1/sjh-skills
```

**安装单个：**

```bash
claude install-skill https://github.com/jiahao-shao1/sjh-skills --path skills/scholar-agent
```

## 项目结构

```
sjh_skills/
└── skills/
    ├── scholar-agent/     # Scholar Inbox API + NotebookLM 深度阅读
    ├── cmux/              # tmux 多路复用 + 浏览器面板
    ├── daily-summary/     # git + Claude sessions + Notion 聚合
    ├── notion-lifeos/     # PARA 方法 + Make Time 日记
    └── web-fetcher/       # Jina → defuddle → markdown.new fallback
```

每个 skill 都是独立的，包含 `SKILL.md`、`scripts/` 和 `references/`。可以单独安装，也可以作为合集安装。

## 许可证

[MIT](LICENSE)
