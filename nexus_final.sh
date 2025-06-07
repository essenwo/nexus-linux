#!/bin/bash

# Nexus Network Docker 一键安装脚本
# 解决 GLIBC 兼容性问题，自动安装后提示输入Node ID

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
echo -e "${GREEN}  Nexus Network Docker 一键安装${NC}"
echo -e "${GREEN}  解决系统兼容性问题${NC}"  
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

# 安装 Docker
print_step "检查并安装 Docker..."
if ! command -v docker &> /dev/null; then
    print_step "安装 Docker..."
    apt update
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
    systemctl enable docker
    systemctl start docker
    print_success "Docker 安装完成"
else
    print_success "Docker 已安装"
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

print_step "创建 Nexus Docker 镜像..."

# 创建 Dockerfile
cat > Dockerfile << 'EOF'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    libprotobuf-dev \
    protobuf-compiler \
    git \
    && rm -rf /var/lib/apt/lists/*

# 安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# 添加 RISC-V 目标
RUN /root/.cargo/bin/rustup target add riscv32i-unknown-none-elf

# 安装 Nexus CLI (自动确认条款)
RUN echo "y" | curl -fsSL https://cli.nexus.xyz/ | sh

# 设置PATH
ENV PATH="/root/.nexus/bin:${PATH}"

# 创建启动脚本
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
EOF

# 创建启动脚本
cat > start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Nexus Network 节点启动中..."
echo "Node ID: $NODE_ID"
echo "时间: $(date)"
echo ""

# 检查 Node ID
if [ -z "$NODE_ID" ]; then
    echo "❌ 错误: 未设置 NODE_ID 环境变量"
    exit 1
fi

# 寻找 nexus-network 可执行文件
NEXUS_BIN=""
if command -v nexus-network >/dev/null 2>&1; then
    NEXUS_BIN="nexus-network"
elif [ -f /root/.nexus/bin/nexus-network ]; then
    NEXUS_BIN="/root/.nexus/bin/nexus-network"
elif [ -f /root/.nexus/nexus-network ]; then
    NEXUS_BIN="/root/.nexus/nexus-network"
else
    echo "❌ 错误: 找不到 nexus-network 可执行文件"
    echo "检查的路径:"
    echo "  command -v nexus-network: $(command -v nexus-network 2>/dev/null || echo '未找到')"
    echo "  /root/.nexus/bin/nexus-network: $(ls -la /root/.nexus/bin/nexus-network 2>/dev/null || echo '不存在')"
    echo "  /root/.nexus/nexus-network: $(ls -la /root/.nexus/nexus-network 2>/dev/null || echo '不存在')"
    exit 1
fi

echo "✅ 找到 nexus-network: $NEXUS_BIN"
echo ""

# 启动 Nexus Network
echo "🎯 启动 Nexus Network 挖矿..."
exec $NEXUS_BIN start --node-id $NODE_ID
EOF

# 构建 Docker 镜像
print_step "构建 Docker 镜像（可能需要几分钟）..."
docker build -t nexus-network:latest . --no-cache

print_success "Docker 镜像构建完成"

# 清理临时文件
cd - >/dev/null
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}     🎉 安装完成！🎉${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""

# 提示用户输入 Node ID
echo -e "${YELLOW}请访问 https://app.nexus.xyz 获取你的 Node ID${NC}"
echo ""

# 输入 Node ID
while true; do
    if [ -t 0 ]; then
        read -p "请输入你的 Node ID: " NODE_ID
    else
        echo -n "请输入你的 Node ID: "
        read NODE_ID < /dev/tty
    fi
    
    if [[ -z "$NODE_ID" ]]; then
        echo -e "${RED}Node ID 不能为空，请重新输入${NC}"
        continue
    fi
    
    if [[ "$NODE_ID" =~ ^[0-9]+$ ]]; then
        break
    else
        echo -e "${RED}Node ID 格式不正确，请输入纯数字${NC}"
        continue
    fi
done

echo ""
print_step "启动 Nexus Docker 容器..."

# 停止旧容器
if docker ps -a --format '{{.Names}}' | grep -qw "nexus-prover"; then
    print_warning "检测到旧容器，正在删除..."
    docker rm -f nexus-prover >/dev/null 2>&1
fi

# 启动新容器
docker run -d \
    --name nexus-prover \
    --restart unless-stopped \
    -e NODE_ID="$NODE_ID" \
    nexus-network:latest

# 等待容器启动
sleep 3

# 检查容器状态
if docker ps --format '{{.Names}}' | grep -qw "nexus-prover"; then
    print_success "🚀 Nexus 节点已成功启动！"
    echo ""
    echo -e "${GREEN}📋 节点信息:${NC}"
    echo -e "   Node ID: ${YELLOW}$NODE_ID${NC}"
    echo -e "   容器名称: ${YELLOW}nexus-prover${NC}"
    echo -e "   状态: ${GREEN}运行中${NC}"
    echo ""
    echo -e "${BLUE}📖 管理命令:${NC}"
    echo -e "   查看实时日志: ${YELLOW}docker logs -f nexus-prover${NC}"
    echo -e "   查看容器状态: ${YELLOW}docker ps${NC}"
    echo -e "   重启容器: ${YELLOW}docker restart nexus-prover${NC}"
    echo -e "   停止容器: ${YELLOW}docker stop nexus-prover${NC}"
    echo -e "   删除容器: ${YELLOW}docker rm -f nexus-prover${NC}"
    echo ""
    echo -e "${GREEN}✨ 节点正在后台运行中，开始挖矿！${NC}"
    echo ""
    echo -e "${BLUE}💡 提示: 使用 ${YELLOW}docker logs -f nexus-prover${NC} ${BLUE}查看实时运行日志${NC}"
    
    # 显示最新日志
    echo ""
    echo -e "${BLUE}📄 最新日志预览:${NC}"
    docker logs nexus-prover 2>/dev/null | tail -10 || echo "日志稍后显示..."
    
else
    print_error "容器启动失败，请检查 Docker 日志: docker logs nexus-prover"
fi

echo ""
echo -e "${GREEN}🎉 安装和启动完成！${NC}"
