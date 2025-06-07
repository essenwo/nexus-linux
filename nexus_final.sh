#!/bin/bash

set -e  # 脚本中任意一步失败就退出

echo "=== [1] 更新系统并安装依赖 ==="
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential curl git cmake protobuf-compiler screen

echo "=== [2] 安装 Rust（非交互式） ==="
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

echo "=== [3] 添加 RISC-V 目标 ==="
rustup target add riscv32i-unknown-none-elf

echo "=== [4] 安装 Nexus CLI ==="
curl https://cli.nexus.xyz/ | sh

echo "=== [5] 请输入你的节点 ID（Node ID）：==="
read -p "Node ID: " NODE_ID

echo "=== [6] 启动 Nexus 节点到 screen（会话名：nexus-node） ==="
screen -dmS nexus-node bash -c "source ~/.nexus/env && nexus-network start --node-id $NODE_ID"

echo
echo "✅ 节点已启动并在后台运行。你可以使用以下命令查看日志："
echo "   screen -r nexus-node"
echo

