# Codex Review

[English](README.md) | 中文

> 跨模型审查 —— 将计划或代码 diff 发送给 OpenAI Codex 独立验证，Claude-Codex 迭代反馈直到通过（最多 5 轮）。

## 功能

- **自动检测模式** — 根据上下文判断是计划审查还是代码审查
- **迭代反馈** — Claude 根据 Codex 的意见修改后重新提交审查
- **双重审查视角** — 计划从目标对齐、完整性、风险评估；代码从正确性、安全性、边界情况
- **最多 5 轮** — 防止无限循环，同时确保审查充分

## 安装

```bash
npx skills add jiahao-shao1/sjh-skills --skill codex-review
```

## 前置条件

- `codex` CLI 已安装（`npm install -g @openai/codex`）
- OpenAI 凭据已配置（API key 或 ChatGPT 登录）

## 使用

```
/codex-review
```

或通过对话触发：

```
"让 codex 看看"
"交叉审查一下"
"second opinion"
"帮我 review 一下这个方案"
```

可选指定模型：

```
/codex-review gpt-5.4
```

## 工作原理

1. **检测** — 检查上下文中是否有计划（计划审查）或 git diff（代码审查）
2. **打包** — 将审查内容 + 项目上下文写入临时文件
3. **发送给 Codex** — 以只读模式运行 `codex exec`，附带结构化审查提示
4. **处理结果** — APPROVED 结束；REVISE 触发 Claude 修复问题并重新提交
5. **迭代** — 最多 5 轮，直到 Codex 通过或达到上限
6. **报告** — 最终摘要，包含结论和建议修复

## 许可证

MIT
