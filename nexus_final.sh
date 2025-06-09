#!/bin/bash

# Nexus Network Docker 一键安装脚本 (修复版)
# 解决GLIBC兼容性问题和后台运行问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 打印函数
print_step() {
    echo -e "${BLUE}[步骤]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_header() {
    echo
    echo -e "${CYAN}=================================${NC}"
    echo -e "${PURPLE}  Nexus Network Docker 一键安装${NC}"
    echo -e "${PURPLE}  修复版 - 解决所有已知问题${NC}"
    echo -e "${CYAN}=================================${NC}"
    echo
}

# 系统检查
check_system() {
    print_step "检查系统环境..."
    
    if ! command -v curl &> /dev/null; then
        print_error "curl 未安装，请先安装 curl"
        exit 1
    fi
    
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 root 权限运行此脚本"
        exit 1
    fi
    
    print_success "系统检查通过"
}

# 安装Docker
install_docker() {
    print_step "检查并安装 Docker..."
    
    if command -v docker &> /dev/null; then
        print_success "Docker 已安装"
        return
    fi
    
    print_step "正在安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    print_success "Docker 安装完成"
}

# 创建修复后的Dockerfile
create_dockerfile() {
    print_step "创建 Nexus Docker 镜像..."
    
    cat > Dockerfile << 'EOF'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装系统依赖
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

# 安装 Nexus CLI (修复版)
RUN curl https://cli.nexus.xyz/ > /tmp/install.sh && \
    echo "y" | bash /tmp/install.sh && \
    rm /tmp/install.sh

# 确保PATH正确
ENV PATH="/root/.nexus/bin:${PATH}"

# 创建修复后的启动脚本
COPY start_fixed.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
EOF
}

# 创建修复后的启动脚本
create_start_script() {
    cat > start_fixed.sh << 'EOF'
#!/bin/bash

echo "🚀 Nexus Network 节点启动中..."
echo "Node ID: ${NODE_ID}"
echo "时间: $(date)"
echo

# 确保环境变量正确
export PATH="/root/.nexus/bin:/root/.cargo/bin:${PATH}"

# 检查nexus-network是否存在
if ! command -v nexus-network &> /dev/null; then
    echo "❌ 错误: nexus-network 未找到"
    echo "PATH: $PATH"
    echo "查找nexus-network..."
    find /root -name "nexus-network" -type f 2>/dev/null || echo "未找到nexus-network文件"
    exit 1
fi

echo "✅ 找到 nexus-network: $(which nexus-network)"
echo "📍 版本: $(nexus-network --version)"
echo

# 检查Node ID
if [ -z "$NODE_ID" ]; then
    echo "❌ 错误: NODE_ID 环境变量未设置"
    exit 1
fi

echo "🎯 启动 Nexus Network 挖矿..."
echo "📊 使用Node ID: $NODE_ID"
echo

# 创建日志目录
mkdir -p /var/log/nexus

# 启动nexus-network (无限重试)
while true; do
    echo "$(date): 启动 Nexus Network..."
    
    # 使用nohup在后台运行，并重定向输出
    nexus-network start --node-id "$NODE_ID" 2>&1 | tee -a /var/log/nexus/nexus.log
    
    exit_code=$?
    echo "$(date): Nexus Network 退出，代码: $exit_code"
    
    if [ $exit_code -eq 0 ]; then
        echo "$(date): 正常退出"
        break
    else
        echo "$(date): 异常退出，5秒后重试..."
        sleep 5
    fi
done
EOF
}

# 构建Docker镜像
build_image() {
    print_step "构建 Docker 镜像（可能需要几分钟）..."
    
    create_dockerfile
    create_start_script
    
    if docker build -t nexus-network:fixed . > docker_build.log 2>&1; then
        print_success "Docker 镜像构建完成"
        rm -f Dockerfile start_fixed.sh docker_build.log
    else
        print_error "Docker 镜像构建失败，查看 docker_build.log 了解详情"
        exit 1
    fi
}

# 获取Node ID
get_node_id() {
    echo
    echo -e "${CYAN}=================================${NC}"
    echo -e "${PURPLE}     🎉 安装完成！🎉${NC}"
    echo -e "${CYAN}=================================${NC}"
    echo
    echo -e "${YELLOW}请访问 https://app.nexus.xyz 获取你的 Node ID${NC}"
    echo
    
    while true; do
        read -p "请输入你的 Node ID: " NODE_ID < /dev/tty
        if [[ "$NODE_ID" =~ ^[0-9]+$ ]]; then
            break
        else
            print_error "请输入有效的数字 Node ID"
        fi
    done
}

# 启动容器
start_container() {
    print_step "启动 Nexus Docker 容器..."
    
    # 停止并删除现有容器
    docker stop nexus-prover 2>/dev/null || true
    docker rm nexus-prover 2>/dev/null || true
    docker stop nexus-debug 2>/dev/null || true
    docker rm nexus-debug 2>/dev/null || true
    
    # 启动新容器
    CONTAINER_ID=$(docker run -d \
        --name nexus-prover \
        --network host \
        --restart unless-stopped \
        -e NODE_ID="$NODE_ID" \
        nexus-network:fixed)
    
    if [ $? -eq 0 ]; then
        print_success "🚀 Nexus 节点已成功启动！"
        echo
        echo -e "${CYAN}📋 节点信息:${NC}"
        echo "   Node ID: $NODE_ID"
        echo "   容器名称: nexus-prover"
        echo "   容器ID: ${CONTAINER_ID:0:12}"
        echo "   状态: 运行中"
        echo
        echo -e "${CYAN}📖 管理命令:${NC}"
        echo "   查看实时日志: docker logs -f nexus-prover"
        echo "   查看容器状态: docker ps"
        echo "   重启容器: docker restart nexus-prover"
        echo "   停止容器: docker stop nexus-prover"
        echo "   删除容器: docker rm -f nexus-prover"
        echo
        echo -e "${GREEN}✨ 节点正在后台运行中，开始挖矿！${NC}"
        echo
        echo -e "${YELLOW}💡 提示: 使用 docker logs -f nexus-prover 查看实时运行日志${NC}"
        
        # 等待几秒钟让容器启动
        sleep 3
        
        echo
        echo -e "${CYAN}📄 最新日志预览:${NC}"
        docker logs --tail 10 nexus-prover
        
    else
        print_error "容器启动失败"
        exit 1
    fi
}

# 显示最终信息
show_final_info() {
    echo
    echo -e "${GREEN}🎉 安装和启动完成！${NC}"
    echo
    echo -e "${YELLOW}重要提示:${NC}"
    echo "1. 节点现在在后台运行，即使关闭终端也会继续挖矿"
    echo "2. 容器会自动重启，服务器重启后也会自动运行"
    echo "3. 使用 'docker logs -f nexus-prover' 查看实时日志"
    echo "4. 如需停止挖矿，使用 'docker stop nexus-prover'"
    echo
}

# 主函数
main() {
    print_header
    check_system
    install_docker
    build_image
    get_node_id
    start_container
    show_final_info
}

# 运行主函数
main
