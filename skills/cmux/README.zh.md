# cmux Skill

[English](README.md) | 中文

> Claude Code 技能：在 [cmux](https://github.com/nicholasgasior/cmux) 中编排终端会话 — 分屏、启动子 Agent、自动化浏览器、预览 Markdown。

## 功能

- **终端编排** — 分屏、创建工作区、向任意 surface 发送命令
- **子 Agent 启动** — 在并行分屏中启动 Claude Code 实例
- **浏览器自动化** — 在 cmux 内置浏览器中打开 URL、点击元素、填写表单、截图
- **Markdown 预览** — 终端旁实时刷新的 Markdown 面板
- **侧边栏状态** — 进度条、状态徽章、日志条目

## 安装

```bash
# 添加到 Claude Code skills
cp -r cmux ~/.claude/skills/
```

或通过 [dotfiles + stow](https://github.com/jiahao-shao1/dotfiles) 管理：

```bash
git submodule add <repo-url> agents/.agents/skills/cmux
```

## 使用

在 cmux 会话内（`CMUX_WORKSPACE_ID` 已设置）自动激活。

```
# 分屏并行跑任务
"这两个测试并行跑"

# 在 cmux 浏览器中打开网页
"打开那个链接"

# 终端旁边预览文档
"预览 plan.md"
```

## 许可证

MIT
