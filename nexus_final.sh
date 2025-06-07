#!/bin/bash
set -e

echo "=== [1] 更新系统并安装依赖 ==="
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential curl git cmake protobuf-compiler screen

echo "=== [2] 安装 Rust（非交互式） ==="
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

echo "=== [3] 添加 RISC-V 目标 ==="
rustup target add riscv32i-unknown-none-elf

echo "=== [4] 安装 Nexus CLI（自动确认） ==="
echo "Y" | curl https://cli.nexus.xyz/ | sh

echo "=== [5] 请输入你的节点 ID（Node ID）：==="
read -p "Node ID: " NODE_ID

LOGFILE="$HOME/nexus-node.log"
echo "=== [6] 启动 Nexus 节点到 screen，会话名 nexus-node，日志输出到 $LOGFILE ==="

screen -dmS nexus-node bash -c "source ~/.nexus/env && nexus-network start --node-id $NODE_ID | tee $LOGFILE"

echo
echo "✅ 节点已启动并在后台运行。"
echo "查看日志: tail -f $LOGFILE"
echo "恢复 screen 会话: screen -r nexus-node"
echo

