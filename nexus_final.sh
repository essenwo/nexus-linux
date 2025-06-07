#!/bin/bash

# Nexus Network CLI Docker 一键安装脚本
# 基于 Docker 容器化部署，更稳定可靠

set -e

CONTAINER_NAME="nexus-prover"
IMAGE_NAME="nexus-network:latest"
LOG_FILE="/root/nexus-prover.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 检查并安装 Docker
install_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log_info "检测到未安装 Docker，正在安装..."
        apt update
        apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io
        systemctl enable docker
        systemctl start docker
        log_success "Docker 安装完成"
    else
        log_success "Docker 已安装"
    fi
}

# 构建 Nexus Docker 镜像
build_nexus_image() {
    log_info "构建 Nexus Docker 镜像..."
    
    WORKDIR=$(mktemp -d)
    cd "$WORKDIR"

    # 创建 Dockerfile
    cat > Dockerfile <<'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ID_FILE=/root/.nexus/node-id

# 安装依赖
RUN apt-get update && apt-get install -y \
    curl \
    screen \
    bash \
    build-essential \
    cmake \
    protobuf-compiler \
    libprotobuf-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# 安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# 添加 RISC-V 目标
RUN /root/.cargo/bin/rustup target add riscv32i-unknown-none-elf

# 安装 Nexus CLI (自动确认条款)
RUN echo "y" | curl -fsSL https://cli.nexus.xyz/ | sh

# 添加到 PATH
ENV PATH="/root/.nexus:${PATH}"

# 复制启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
EOF

    # 创建启动脚本
    cat > entrypoint.sh <<'EOF'
#!/bin/bash
set -e

NODE_ID_FILE="/root/.nexus/node-id"
LOG_FILE="/root/nexus-prover.log"

# 检查 Node ID 环境变量
if [ -z "$NODE_ID" ]; then
    echo "❌ 错误：未设置 NODE_ID 环境变量"
    exit 1
fi

# 保存 Node ID
mkdir -p /root/.nexus
echo "$NODE_ID" > "$NODE_ID_FILE"
echo "✅ 使用 Node ID: $NODE_ID"

# 检查 nexus-network 命令
if ! command -v nexus-network >/dev/null 2>&1; then
    echo "❌ 错误：nexus-network 命令不可用"
    exit 1
fi

# 清理旧的 screen 会话
screen -S nexus-prover -X quit >/dev/null 2>&1 || true

echo "🚀 启动 Nexus Network 节点..."

# 在 screen 中启动 nexus-network
screen -dmS nexus-prover bash -c "nexus-network start --node-id $NODE_ID 2>&1 | tee -a $LOG_FILE"

sleep 5

# 检查是否启动成功
if screen -list | grep -q "nexus-prover"; then
    echo "✅ 节点已成功启动并运行在后台"
    echo "📋 Node ID: $NODE_ID"
    echo "📄 日志文件: $LOG_FILE"
    echo "🔗 查看实时日志: docker logs -f $HOSTNAME"
else
    echo "❌ 节点启动失败，查看错误日志:"
    cat "$LOG_FILE" || echo "无法读取日志文件"
    exit 1
fi

# 持续输出日志
tail -f "$LOG_FILE"
EOF

    # 构建镜像
    docker build -t "$IMAGE_NAME" . --no-cache
    
    cd - >/dev/null
    rm -rf "$WORKDIR"
    
    log_success "Docker 镜像构建完成"
}

# 启动 Nexus 容器
start_nexus_container() {
    local node_id="$1"
    
    # 停止并删除旧容器
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        log_warning "检测到旧容器，正在删除..."
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
    fi

    # 确保日志文件存在
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    log_info "启动 Nexus 容器..."
    
    # 启动新容器
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -e NODE_ID="$node_id" \
        -v "$LOG_FILE":/root/nexus-prover.log \
        "$IMAGE_NAME"

    sleep 3
    
    # 检查容器状态
    if docker ps --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        log_success "容器启动成功！"
        return 0
    else
        log_error "容器启动失败"
        docker logs "$CONTAINER_NAME" 2>/dev/null || true
        return 1
    fi
}

# 显示节点状态
show_status() {
    if docker ps --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        echo -e "${GREEN}🟢 节点状态: 运行中${NC}"
        
        # 获取 Node ID
        NODE_ID=$(docker exec "$CONTAINER_NAME" cat /root/.nexus/node-id 2>/dev/null || echo "未知")
        echo -e "${BLUE}📋 Node ID: $NODE_ID${NC}"
        
        # 获取容器启动时间
        START_TIME=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER_NAME" 2>/dev/null | cut -d'T' -f1)
        echo -e "${BLUE}⏰ 启动时间: $START_TIME${NC}"
        
        echo -e "${BLUE}📄 日志文件: $LOG_FILE${NC}"
    else
        echo -e "${RED}🔴 节点状态: 未运行${NC}"
    fi
}

# 查看日志
show_logs() {
    if docker ps --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        echo "📄 实时日志 (按 Ctrl+C 退出):"
        docker logs -f "$CONTAINER_NAME"
    else
        log_error "容器未运行"
        if [ -f "$LOG_FILE" ]; then
            echo "📄 历史日志:"
            tail -50 "$LOG_FILE"
        fi
    fi
}

# 停止并删除节点
remove_nexus() {
    log_info "停止并删除 Nexus 节点..."
    
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
        log_success "容器已删除"
    fi
    
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -qw "$IMAGE_NAME"; then
        docker rmi "$IMAGE_NAME" >/dev/null 2>&1
        log_success "镜像已删除"
    fi
    
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
        log_success "日志文件已删除"
    fi
    
    log_success "Nexus 节点完全卸载"
}

# 主菜单
show_menu() {
    clear
    echo -e "${GREEN}🚀 =========================================${NC}"
    echo -e "${GREEN}🚀    Nexus Network CLI Docker 管理器${NC}"
    echo -e "${GREEN}🚀    Ubuntu 22.04 - Docker 容器化部署${NC}"
    echo -e "${GREEN}🚀 =========================================${NC}"
    echo ""
    echo "1. 🚀 安装并启动节点"
    echo "2. 📊 查看节点状态"
    echo "3. 📄 查看节点日志"
    echo "4. 🗑️  停止并删除节点"
    echo "5. 🚪 退出"
    echo ""
}

# 主循环
main() {
    while true; do
        show_menu
        read -p "请选择操作 (1-5): " choice
        
        case $choice in
            1)
                install_docker
                read -p "请输入你的 Node ID: " NODE_ID
                if [ -z "$NODE_ID" ]; then
                    log_error "Node ID 不能为空"
                    read -p "按回车继续..."
                    continue
                fi
                build_nexus_image
                if start_nexus_container "$NODE_ID"; then
                    log_success "节点安装完成！"
                    echo ""
                    echo "💡 管理命令:"
                    echo "   查看状态: docker ps"
                    echo "   查看日志: docker logs -f $CONTAINER_NAME"
                    echo "   进入容器: docker exec -it $CONTAINER_NAME bash"
                fi
                read -p "按回车返回菜单..."
                ;;
            2)
                show_status
                read -p "按回车返回菜单..."
                ;;
            3)
                show_logs
                ;;
            4)
                read -p "确定要删除节点吗? (y/N): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    remove_nexus
                fi
                read -p "按回车返回菜单..."
                ;;
            5)
                log_success "感谢使用！"
                exit 0
                ;;
            *)
                log_error "无效选择，请重新输入"
                read -p "按回车继续..."
                ;;
        esac
    done
}

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   log_error "此脚本需要 root 权限运行"
   exit 1
fi

# 启动主程序
main
