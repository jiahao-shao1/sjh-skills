# Mutagen 故障排查与部署经验

## Daemon 卡死恢复

`mutagen sync terminate` 卡住或 `mutagen daemon start` 失败时：

```bash
# 1. 杀掉所有 mutagen 进程
pkill -9 mutagen

# 2. 清理 socket 和 lock（关键！只杀进程不够）
rm ~/.mutagen/daemon/daemon.sock ~/.mutagen/daemon/daemon.lock

# 3. 重启 daemon
mutagen daemon start

# 4. 验证
mutagen sync list
```

## 修改同步模式

mutagen 不支持原地修改模式。必须先 terminate 再 create：

```bash
# 先记录完整参数
mutagen sync list <name> --long

# 删除再重建
mutagen sync terminate <name>
mutagen sync create --mode=one-way-replica --name=<name> ...
```

重建时 ignore 参数一个都不能漏。

## 容器化集群常见问题

很多团队的集群是"容器化工作站"——登录节点是短生命周期容器，`$HOME` 会随容器重启被清空。部署 mutagen 要额外注意几点：

1. **Agent 二进制必须放在持久化存储**：容器 `$HOME` 在重启后消失，mutagen agent 二进制也跟着消失。把 agent 安装到挂载的持久路径（例如 `/shared/.mutagen/`），然后在容器启动脚本里 `ln -sf /shared/.mutagen ~/.mutagen`。

2. **SSH 代理可能污染 stdout**：如果你的 SSH 走 jump host / tunnel / 企业代理，某些代理会把警告写到 stdout，污染 mutagen 的二进制协议。在 `~/.ssh/config` 里对应节点加 `LogLevel ERROR` 可以屏蔽大部分噪音。

3. **`SCP` 连接不关闭 / stderr 混入 stdout**：如果你的 SSH 代理有 bug 导致 SCP 行为异常，mutagen 自动部署 agent 会失败。解决：手动把 agent 二进制放到持久路径，然后通过软链接暴露。

4. **共享文件系统 + 多容器**：所有容器共享同一份 CPFS/NFS 时，代码同步**只需一个 session** 指向任意一个容器。多容器同步到同一路径会互相覆盖。

**症状**：mutagen 连接后立即报 `server magic number incorrect`。
**诊断**：检查目标容器 `~/.mutagen` 是否存在（或已软链接到持久化路径），agent 二进制版本是否匹配本地 mutagen。

## one-way-safe 已弃用

之前使用 `one-way-safe` 模式，Beta 端有独立修改时会产生冲突，导致 mutagen 卡死。现已全面迁移到 `one-way-replica` 模式——Alpha 端是唯一 source of truth，Beta 端被完全覆写，永不冲突。

如果遇到旧的 `one-way-safe` session，直接 terminate 后用 `one-way-replica` 重建：

```bash
mutagen sync terminate <name>
mutagen sync create --mode one-way-replica --name <name> \
  --ignore "outputs/" --ignore "__pycache__" --ignore ".git" --ignore "*.pyc" \
  --ignore ".venv" --ignore "wandb" --ignore ".pytest_cache" --ignore ".worktrees" \
  <alpha-url> <beta-url>
```

### 使用 one-way-replica 的约定

- **代码同步**：Mac（Alpha）→ 集群（Beta），只在 Mac 编辑代码
- **输出同步**：集群（Alpha）→ 本地（Beta），本地 outputs/ 是只读镜像
- Beta 端的任何本地修改会被 Alpha 覆写，这是预期行为
