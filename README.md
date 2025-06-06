# 🚀 Nexus Network CLI One-Click Installer

一键安装脚本，用于在 Ubuntu/Debian Linux 系统上部署 Nexus Network CLI。

## 📋 项目简介

Nexus Network 是一个去中心化的零知识证明网络，通过贡献计算资源来获得 NEX Points 奖励。本脚本可以帮助你快速在 Linux 服务器上部署和运行 Nexus Network CLI。

## ⚡ 快速开始

### 一键安装命令

```bash
curl -fsSL https://raw.githubusercontent.com/essenwo/nexus-linux/main/install_nexus.sh | bash
```

## 🖥️ 系统要求

- **操作系统**: Ubuntu 18.04+ 或 Debian 10+
- **内存**: 建议 4GB+
- **存储**: 建议 20GB+ 可用空间
- **网络**: 稳定的互联网连接
- **权限**: sudo 权限

## 📦 安装内容

脚本将自动安装以下组件：

- [x] 系统依赖包（build-essential, cmake, 等）
- [x] Rust 编程语言环境
- [x] Protocol Buffers
- [x] Nexus Network CLI
- [x] Screen（用于后台运行）

## 🔧 安装步骤

1. **系统检查**: 验证系统兼容性
2. **更新系统**: 更新包管理器和系统包
3. **安装依赖**: 安装必要的开发工具和库
4. **安装 Rust**: 安装 Rust 编程语言环境
5. **安装 Nexus CLI**: 下载并安装 Nexus Network CLI
6. **验证安装**: 确认安装成功
7. **配置账户**: 输入你的 Node ID
8. **后台运行**: 在 screen 会话中启动程序

## 📱 获取 Node ID

1. 访问 [app.nexus.xyz](https://app.nexus.xyz)
2. 创建账户并登录
3. 在控制面板中找到你的 Node ID
4. 在脚本提示时输入该 ID

## 🎮 管理命令

### Screen 会话管理

```bash
# 查看所有会话
screen -ls

# 连接到 Nexus 会话
screen -r nexus-prover

# 脱离会话（程序继续后台运行）
# 在 screen 会话中按: Ctrl+A，然后按 D

# 停止程序
screen -r nexus-prover
# 然后按 Ctrl+C
```

### 重新启动

```bash
# 手动启动（替换为你的实际 Node ID）
screen -S nexus-prover
nexus-network start --node-id YOUR_NODE_ID
```

## 📊 监控和管理

### 查看运行状态
- 使用 `screen -r nexus-prover` 查看实时日志
- 访问 [app.nexus.xyz](https://app.nexus.xyz) 查看 NEX Points 和排名

### 系统资源监控
```bash
# 查看 CPU 和内存使用
top

# 查看磁盘使用
df -h

# 查看网络连接
netstat -an | grep nexus
```

## ❓ 常见问题

### Q: 安装失败怎么办？
**A**: 检查以下几点：
- 确保有 sudo 权限
- 确保网络连接正常
- 检查系统是否为 Ubuntu/Debian
- 查看错误信息并根据提示解决

### Q: 如何更新 Nexus CLI？
**A**: 重新运行安装脚本，或手动更新：
```bash
curl https://cli.nexus.xyz/ | sh
source ~/.bashrc
```

### Q: 程序意外停止了怎么办？
**A**: 使用以下命令重新启动：
```bash
screen -S nexus-prover -dm nexus-network start --node-id YOUR_NODE_ID
```

### Q: 如何完全卸载？
**A**: 运行以下命令：
```bash
# 停止程序
screen -S nexus-prover -X quit

# 移除二进制文件
rm -f ~/.local/bin/nexus-network

# 可选：移除 Rust（如果不需要）
rustup self uninstall
```

## 🛡️ 安全注意事项

- 妥善保管你的 Node ID
- 定期检查程序运行状态
- 保持系统和依赖更新
- 监控系统资源使用情况

## 📈 收益追踪

- 访问 [app.nexus.xyz](https://app.nexus.xyz) 查看：
  - NEX Points 余额
  - 排行榜排名
  - 节点运行统计
  - 收益历史记录

## 🔗 相关链接

- [Nexus 官网](https://nexus.xyz)
- [用户控制面板](https://app.nexus.xyz)
- [官方文档](https://docs.nexus.xyz)
- [GitHub 仓库](https://github.com/nexus-xyz)
- [Discord 社区](https://discord.gg/nexus)

## 📄 许可证

本项目基于 MIT 许可证开源。详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## ⭐ 支持项目

如果这个脚本对你有帮助，请给个 Star ⭐！

---

**免责声明**: 本脚本仅用于教育和学习目的。使用前请仔细阅读 Nexus Network 的服务条款。# nexus-linux
