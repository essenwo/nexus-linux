#!/bin/bash

# Nexus Network 快速安装脚本
# 优化版本 - 大幅缩短安装时间

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "${BLUE}[步骤]${NC} $1"; }
print_success() { echo -e "${GREEN}[成功]${NC} $1"; }
print_error() { echo -e "${RED}[错误]${NC} $1"; }

print_header() {
    echo
    echo -e "${CYAN}=================================${NC}"
    echo -e "${PURPLE}  Nexus Network 快速安装器${NC}"
    echo -e "${PURPLE}  优化版 - 2分钟完成安装${NC}"
    echo -e "${CYAN}=================================${NC}"
    echo
}

# 检查Docker
check_docker() {
    print_step "检查Docker环境..."
    if ! command -v docker &> /dev/null; then
        print_step "安装Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
    fi
    print_success "Docker准备就绪"
}

# 创建轻量化Dockerfile
create_fast_dockerfile() {
    print_step "创建优化镜像..."
    
cat > Dockerfile << 'EOF'
# 使用更小的基础镜像
FROM ubuntu:24.04

# 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive

# 一次性安装所有依赖（减少层数）
RUN apt-get update && apt-get install -y curl && \
    # 安装Rust（一步完成）
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    # 设置PATH
    . /root/.cargo/env && \
    # 添加RISC-V目标
    rustup target add riscv32i-unknown-none-elf && \
    # 安装Nexus CLI
    curl https://cli.nexus.xyz/ | sh && \
    # 清理缓存
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 设置环境变量
ENV PATH="/root/.nexus/bin:/root/.cargo/bin:${PATH}"

# 创建启动脚本
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "🚀 启动Nexus节点 - Node ID: $NODE_ID"' >> /start.sh && \
    echo 'exec nexus-network start --node-id "$NODE_ID"' >> /start.sh && \
    chmod +x /start.sh

CMD ["/start.sh"]
EOF
}

# 快速构建
fast_build() {
    print_step "快速构建镜像（约2分钟）..."
    create_fast_dockerfile
    
    # 使用BuildKit加速构建
    export DOCKER_BUILDKIT=1
    
    if docker build -t nexus-fast . --progress=plain; then
        print_success "镜像构建完成！"
        rm -f Dockerfile
    else
        print_error "构建失败"
        exit 1
    fi
}

# 获取Node ID
get_node_id() {
    echo
    echo -e "${YELLOW}请访问 https://app.nexus.xyz 获取 Node ID${NC}"
    echo
    while true; do
        read -p "请输入Node ID: " NODE_ID < /dev/tty
        if [[ "$NODE_ID" =~ ^[0-9]+$ ]]; then
            break
        else
            print_error "请输入有效数字"
        fi
    done
}

# 启动节点
start_node() {
    print_step "启动Nexus节点..."
    
    # 清理旧容器
    docker stop nexus-node 2>/dev/null || true
    docker rm nexus-node 2>/dev/null || true
    
    # 启动新容器
    docker run -d \
        --name nexus-node \
        --restart unless-stopped \
        --network host \
        -e NODE_ID="$NODE_ID" \
        nexus-fast
    
    print_success "🎉 节点启动成功！"
    echo
    echo -e "${CYAN}管理命令:${NC}"
    echo "  查看日志: docker logs -f nexus-node"
    echo "  重启节点: docker restart nexus-node"
    echo "  停止节点: docker stop nexus-node"
    echo
    
    sleep 2
    echo -e "${CYAN}📄 运行状态:${NC}"
    docker logs nexus-node
}

# 主函数
main() {
    print_header
    check_docker
    fast_build
    get_node_id
    start_node
    
    echo
    echo -e "${GREEN}✅ 快速安装完成！节点正在后台挖矿...${NC}"
}

main
