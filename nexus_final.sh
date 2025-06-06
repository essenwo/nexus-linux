#!/bin/bash

# Nexus Network CLI 一键安装脚本 - Ubuntu 22.04版本

set -e

echo "🚀 Nexus Network CLI - Ubuntu 22.04 一键安装脚本"
echo "================================================"

# 更新系统
echo "📦 更新系统包列表..."
sudo apt update

# 安装依赖 (对应 brew install cmake protobuf git + screen)
echo "🔧 安装系统依赖..."
sudo apt install -y build-essential cmake protobuf-compiler libprotobuf-dev git curl screen

# 安装 Rust 
echo "🦀 安装 Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 刷新环境变量
source ~/.cargo/env

# 添加 RISC-V 目标 
echo "🎯 添加 RISC-V 目标..."
rustup target add riscv32i-unknown-none-elf

# 安装 Nexus CLI 
echo "⚡ 安装 Nexus Network CLI..."
echo "y" | curl https://cli.nexus.xyz/ | sh

# 刷新环境变量 (对应 source /Users/macmini/.zshrc)
echo "🔄 刷新环境变量..."
echo "🔄 刷新环境变量..."
source ~/.bashrc

echo ""
echo "✅ 安装完成！"
echo ""

# 检查是否在交互式终端中
if [ -t 0 ]; then
    echo "🚀 即将启动 screen 会话..."
    echo "⚠️  在 screen 会话中，请输入你的 Node ID"
    echo "💡 获取 Node ID: https://app.nexus.xyz"
    echo "📝 退出 screen: Ctrl+A 然后按 D"
    echo "🔄 重新连接: screen -r nexus-prover"
    echo ""
    read -p "按 Enter 继续启动 screen 会话..." 
    
    # 创建 screen 会话并运行 nexus-network
    screen -S nexus-prover -d -m bash -c "source ~/.bashrc; nexus-network start --node-id"
    echo "✅ Screen 会话 'nexus-prover' 已启动"
    echo "🔗 连接到会话: screen -r nexus-prover"
else
    echo "🎯 接下来手动运行："
    echo "screen -S nexus-prover"
    echo "然后在 screen 中运行:"
    echo "source ~/.bashrc"
    echo "nexus-network start --node-id 你的ID"
    echo ""
    echo "💡 获取你的 Node ID: https://app.nexus.xyz"
    echo "📝 退出 screen: Ctrl+A 然后按 D" 
    echo "🔄 重新连接: screen -r nexus-prover"
fi

echo ""
