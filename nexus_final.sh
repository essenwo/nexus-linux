#!/bin/bash

# Nexus Network 一键安装脚本
# 自动安装所有依赖，最后提示输入Node ID并启动

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 显示带颜色的消息
print_step() {
    echo -e "${BLUE}[步骤] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[成功] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[警告] $1${NC}"
}

print_error() {
    echo -e "${RED}[错误] $1${NC}"
    exit 1
}

echo ""
echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}  Nexus Network 一键安装脚本${NC}"
echo -e "${GREEN}  适用于 Ubuntu 22.04+ 系统${NC}"  
echo -e "${GREEN}=================================${NC}"
echo ""

# 检查系统
print_step "检查系统环境..."
if [[ $EUID -ne 0 ]]; then
    print_error "请使用 root 权限运行此脚本"
fi

if ! command -v apt &> /dev/null; then
    print_error "此脚本仅支持 Ubuntu/Debian 系统"
fi

print_success "系统检查通过"

# 更新系统
print_step "更新系统包列表..."
export DEBIAN_FRONTEND=noninteractive
apt update -y
print_success "系统更新完成"

# 安装基础依赖
print_step "安装基础依赖包..."
apt install -y \
    curl \
    wget \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    libprotobuf-dev \
    protobuf-compiler \
    git \
    screen \
    unzip
print_success "基础依赖安装完成"

# 安装 Rust
print_step "安装 Rust 编程环境..."
if command -v rustc &> /dev/null; then
    print_warning "Rust 已安装，跳过"
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    print_success "Rust 安装完成"
fi

# 确保 Rust 环境可用
export PATH="$HOME/.cargo/bin:$PATH"
source ~/.cargo/env 2>/dev/null || true

# 添加 RISC-V 目标
print_step "添加 RISC-V 编译目标..."
rustup target add riscv32i-unknown-none-elf
print_success "RISC-V 目标添加完成"

# 安装 Nexus CLI
print_step "安装 Nexus Network CLI..."
echo "y" | curl -fsSL https://cli.nexus.xyz/ | sh

# 添加 Nexus 到 PATH
if ! grep -q 'export PATH="$PATH:~/.nexus"' ~/.bashrc; then
    echo 'export PATH="$PATH:~/.nexus"' >> ~/.bashrc
fi

# 立即应用 PATH
export PATH="$PATH:~/.nexus"
source ~/.bashrc 2>/dev/null || true

print_success "Nexus CLI 安装完成"

# 验证安装
print_step "验证安装结果..."
if [ -f ~/.nexus/nexus-network ] || command -v nexus-network &> /dev/null; then
    print_success "Nexus Network 安装验证成功"
else
    print_warning "二进制文件可能未在标准路径，但不影响使用"
fi

echo ""
echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}     🎉 安装完成！🎉${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""

# 提示用户输入 Node ID - 修复输入问题
echo -e "${YELLOW}请访问 https://app.nexus.xyz 获取你的 Node ID${NC}"
echo ""

# 使用 /dev/tty 确保能正确读取用户输入
while true; do
    if [ -t 0 ]; then
        # 标准输入是终端
        read -p "请输入你的 Node ID: " NODE_ID
    else
        # 标准输入不是终端（通过 curl | bash 运行）
        echo -n "请输入你的 Node ID: "
        read NODE_ID < /dev/tty
    fi
    
    if [[ -z "$NODE_ID" ]]; then
        echo -e "${RED}Node ID 不能为空，请重新输入${NC}"
        continue
    fi
    
    # 验证 Node ID 格式（假设是数字）
    if [[ "$NODE_ID" =~ ^[0-9]+$ ]]; then
        break
    else
        echo -e "${RED}Node ID 格式不正确，请输入纯数字${NC}"
        continue
    fi
done

echo ""
print_step "准备启动 Nexus Network 节点..."

# 检查是否有旧的 screen 会话
if screen -list | grep -q "nexus"; then
    print_warning "检测到旧的 screen 会话，正在清理..."
    screen -S nexus -X quit 2>/dev/null || true
    sleep 2
fi

print_step "在 screen 会话中启动节点..."

# 创建启动脚本
cat > /tmp/start_nexus.sh << EOF
#!/bin/bash
source ~/.bashrc
export PATH="\$PATH:~/.nexus"

echo "正在启动 Nexus Network..."
echo "Node ID: $NODE_ID"
echo ""

# 尝试不同的路径
if command -v nexus-network &> /dev/null; then
    nexus-network start --node-id $NODE_ID
elif [ -f ~/.nexus/nexus-network ]; then
    ~/.nexus/nexus-network start --node-id $NODE_ID
else
    echo "未找到 nexus-network 命令"
    exit 1
fi
EOF

chmod +x /tmp/start_nexus.sh

# 启动 screen 会话
screen -dmS nexus bash /tmp/start_nexus.sh

# 等待一下让程序启动
sleep 3

# 检查 screen 会话是否存在
if screen -list | grep -q "nexus"; then
    print_success "节点已成功启动！"
    echo ""
    echo -e "${GREEN}🚀 节点信息:${NC}"
    echo -e "   Node ID: ${YELLOW}$NODE_ID${NC}"
    echo -e "   Screen 会话: ${YELLOW}nexus${NC}"
    echo ""
    echo -e "${BLUE}📋 管理命令:${NC}"
    echo -e "   查看运行状态: ${YELLOW}screen -r nexus${NC}"
    echo -e "   退出但保持运行: ${YELLOW}Ctrl+A 然后按 D${NC}"
    echo -e "   查看所有会话: ${YELLOW}screen -ls${NC}"
    echo -e "   完全停止节点: ${YELLOW}screen -S nexus -X quit${NC}"
    echo ""
    echo -e "${GREEN}✨ 节点正在后台运行中，开始挖矿！${NC}"
else
    print_error "节点启动失败，请检查日志"
fi

# 清理临时文件
rm -f /tmp/start_nexus.sh

echo ""
echo -e "${GREEN}安装和启动完成！${NC}"
