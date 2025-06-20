#!/bin/bash

# Nexus Network 一键安装脚本 for Ubuntu 22.04
# 支持root和普通用户
# 版本: 2.0

set -e

echo "=================================="
echo "    Nexus Network 一键安装脚本    "
echo "=================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 检测用户类型
if [ "$EUID" -eq 0 ]; then
    print_warning "检测到root用户，将以root权限运行"
    IS_ROOT=true
    DOCKER_CMD="docker"
    COMPOSE_CMD="docker-compose"
else
    print_status "检测到普通用户"
    IS_ROOT=false
    DOCKER_CMD="docker"
    COMPOSE_CMD="docker-compose"
fi

# 检查系统版本
print_status "检查系统版本..."
if command -v lsb_release &> /dev/null; then
    OS_VERSION=$(lsb_release -d | cut -f2)
    print_status "系统版本: $OS_VERSION"
elif [ -f /etc/os-release ]; then
    OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    print_status "系统版本: $OS_VERSION"
else
    print_warning "无法检测系统版本，继续安装..."
fi

# 更新系统包（可选）
echo ""
read -p "是否更新系统包？建议选择N以节省时间 (y/N): " update_system
if [[ $update_system =~ ^[Yy]$ ]]; then
    print_status "更新系统包..."
    if [ "$IS_ROOT" = true ]; then
        apt update && apt upgrade -y
    else
        sudo apt update && sudo apt upgrade -y
    fi
else
    print_status "跳过系统更新"
fi

# 安装基础依赖
print_status "安装基础依赖..."
if [ "$IS_ROOT" = true ]; then
    apt update
    apt install -y curl wget git apt-transport-https ca-certificates gnupg lsb-release
else
    sudo apt update
    sudo apt install -y curl wget git apt-transport-https ca-certificates gnupg lsb-release
fi

# 检查并安装Docker
print_status "检查Docker安装状态..."
if ! command -v docker &> /dev/null; then
    print_status "Docker未安装，正在安装..."
    
    # 添加Docker官方GPG密钥
    if [ "$IS_ROOT" = true ]; then
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    else
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    fi
    
    # 添加Docker仓库
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | \
    $([ "$IS_ROOT" = true ] && echo "tee" || echo "sudo tee") /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 安装Docker
    if [ "$IS_ROOT" = true ]; then
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    
    # 启动Docker服务
    if [ "$IS_ROOT" = true ]; then
        systemctl start docker
        systemctl enable docker
    else
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    # 将用户添加到docker组（仅非root用户）
    if [ "$IS_ROOT" = false ]; then
        sudo usermod -aG docker $USER
        print_warning "用户已添加到docker组，建议重新登录以生效权限"
        print_warning "如果后续出现权限问题，请执行: newgrp docker"
    fi
    
    print_success "Docker安装完成"
else
    print_success "Docker已安装"
fi

# 检查Docker Compose
print_status "检查Docker Compose..."
if ! docker compose version &> /dev/null; then
    print_status "安装Docker Compose Plugin..."
    if [ "$IS_ROOT" = true ]; then
        apt install -y docker-compose-plugin
    else
        sudo apt install -y docker-compose-plugin
    fi
fi

# 设置Docker Compose命令
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    print_error "Docker Compose安装失败"
    exit 1
fi

print_success "Docker Compose就绪"

# 创建工作目录
WORK_DIR="nexus-network-docker"
print_status "创建工作目录: $WORK_DIR"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 创建Dockerfile
print_status "创建Dockerfile..."
cat > Dockerfile << 'EOF'
FROM ubuntu:22.04

# 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive
ENV RUST_VERSION=stable

# 安装必要依赖
RUN apt update && apt install -y \
    curl \
    wget \
    git \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    libprotobuf-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 创建工作用户
RUN useradd -m -s /bin/bash nexus
USER nexus
WORKDIR /home/nexus

# 安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/nexus/.cargo/bin:${PATH}"

# 添加 RISC-V 目标
RUN /home/nexus/.cargo/bin/rustup target add riscv32i-unknown-none-elf

# 安装 Nexus CLI
RUN curl https://cli.nexus.xyz/ | sh

# 添加 Nexus CLI 到 PATH
ENV PATH="/home/nexus/.nexus:${PATH}"

# 复制启动脚本
COPY --chown=nexus:nexus entrypoint.sh /home/nexus/
RUN chmod +x /home/nexus/entrypoint.sh

# 创建数据目录
RUN mkdir -p /home/nexus/.nexus_data

EXPOSE 8080

CMD ["/home/nexus/entrypoint.sh"]
EOF

# 创建容器启动脚本
print_status "创建容器启动脚本..."
cat > entrypoint.sh << 'EOF'
#!/bin/bash

echo "=================================="
echo "     Nexus Network 容器启动      "
echo "=================================="

# 检查 NODE_ID 环境变量
if [ -z "$NODE_ID" ]; then
    echo "❌ 错误: 未设置 NODE_ID 环境变量"
    echo "请在启动容器时设置: -e NODE_ID=你的节点ID"
    exit 1
fi

echo "🚀 Node ID: $NODE_ID"
echo "📅 启动时间: $(date)"
echo "=================================="

# 检查网络连接
echo "🔍 检查网络连接..."
if curl -s --connect-timeout 5 https://cli.nexus.xyz/ > /dev/null; then
    echo "✅ 网络连接正常"
else
    echo "⚠️  网络连接可能存在问题，但继续启动..."
fi

# 启动Nexus Network
echo "🚀 启动 Nexus Network..."
exec nexus-network start --node-id "$NODE_ID"
EOF

# 创建docker-compose.yml
print_status "创建Docker Compose配置..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  nexus-network:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nexus-node
    restart: unless-stopped
    environment:
      - NODE_ID=${NODE_ID}
      - TZ=Asia/Shanghai
    ports:
      - "8080:8080"
    volumes:
      - nexus_data:/home/nexus/.nexus_data
      - ./logs:/home/nexus/logs
    networks:
      - nexus_network
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'
        reservations:
          memory: 512M
          cpus: '0.5'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health", "||", "exit", "1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  nexus_data:
    driver: local

networks:
  nexus_network:
    driver: bridge
EOF

# 创建管理脚本
print_status "创建管理脚本..."
cat > manage.sh << 'EOF'
#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检测Docker Compose命令
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}错误: 未找到Docker Compose${NC}"
    exit 1
fi

case "$1" in
    start)
        echo -e "${GREEN}🚀 启动Nexus Network...${NC}"
        $COMPOSE_CMD up -d
        echo -e "${GREEN}✅ 启动完成${NC}"
        ;;
    stop)
        echo -e "${YELLOW}⏹️  停止Nexus Network...${NC}"
        $COMPOSE_CMD down
        echo -e "${YELLOW}✅ 停止完成${NC}"
        ;;
    restart)
        echo -e "${BLUE}🔄 重启Nexus Network...${NC}"
        $COMPOSE_CMD restart
        echo -e "${BLUE}✅ 重启完成${NC}"
        ;;
    logs)
        echo -e "${BLUE}📋 查看实时日志 (按Ctrl+C退出)...${NC}"
        $COMPOSE_CMD logs -f --tail=100
        ;;
    status)
        echo -e "${BLUE}📊 服务状态:${NC}"
        $COMPOSE_CMD ps
        echo ""
        echo -e "${BLUE}💾 资源使用:${NC}"
        docker stats nexus-node --no-stream 2>/dev/null || echo "容器未运行"
        ;;
    shell)
        echo -e "${BLUE}🐚 进入容器...${NC}"
        docker exec -it nexus-node bash
        ;;
    update)
        echo -e "${BLUE}⬆️  更新容器...${NC}"
        $COMPOSE_CMD pull
        $COMPOSE_CMD up -d --build
        echo -e "${GREEN}✅ 更新完成${NC}"
        ;;
    clean)
        echo -e "${YELLOW}🧹 清理未使用的Docker资源...${NC}"
        docker system prune -f
        echo -e "${GREEN}✅ 清理完成${NC}"
        ;;
    *)
        echo -e "${GREEN}Nexus Network 管理脚本${NC}"
        echo ""
        echo "用法: $0 {start|stop|restart|logs|status|shell|update|clean}"
        echo ""
        echo -e "${BLUE}命令说明:${NC}"
        echo "  start   - 🚀 启动服务"
        echo "  stop    - ⏹️  停止服务"
        echo "  restart - 🔄 重启服务"
        echo "  logs    - 📋 查看实时日志"
        echo "  status  - 📊 查看运行状态和资源使用"
        echo "  shell   - 🐚 进入容器调试"
        echo "  update  - ⬆️  更新容器镜像"
        echo "  clean   - 🧹 清理Docker缓存"
        echo ""
        echo -e "${YELLOW}示例:${NC}"
        echo "  ./manage.sh start"
        echo "  ./manage.sh logs"
        exit 1
        ;;
esac
EOF

chmod +x manage.sh

# 创建日志目录
mkdir -p logs

# 获取Node ID
echo ""
echo -e "${BLUE}请输入您的Node ID:${NC}"
while true; do
    read -p "Node ID: " NODE_ID
    if [ -n "$NODE_ID" ]; then
        break
    else
        print_error "Node ID不能为空，请重新输入"
    fi
done

# 创建.env文件
echo "NODE_ID=$NODE_ID" > .env

# 构建Docker镜像
print_status "构建Docker镜像 (可能需要几分钟)..."
if ! $COMPOSE_CMD build; then
    print_error "Docker镜像构建失败"
    exit 1
fi

# 启动容器
print_status "启动容器..."
if ! $COMPOSE_CMD up -d; then
    print_error "容器启动失败"
    exit 1
fi

# 等待容器启动
print_status "等待容器完全启动..."
sleep 5

# 检查容器状态
if docker ps | grep -q nexus-node; then
    CONTAINER_STATUS="运行中"
    STATUS_COLOR=$GREEN
else
    CONTAINER_STATUS="异常"
    STATUS_COLOR=$RED
fi

echo ""
echo "=================================="
echo -e "${GREEN}🎉 安装完成！${NC}"
echo "=================================="
echo ""
echo -e "${BLUE}📋 安装信息:${NC}"
echo -e "  工作目录: ${YELLOW}$(pwd)${NC}"
echo -e "  Node ID: ${YELLOW}$NODE_ID${NC}"
echo -e "  容器名称: ${YELLOW}nexus-node${NC}"
echo -e "  容器状态: ${STATUS_COLOR}$CONTAINER_STATUS${NC}"
echo ""
echo -e "${BLUE}🛠️  管理命令:${NC}"
echo -e "  ${GREEN}./manage.sh start${NC}    - 🚀 启动服务"
echo -e "  ${YELLOW}./manage.sh stop${NC}     - ⏹️  停止服务"
echo -e "  ${BLUE}./manage.sh restart${NC}  - 🔄 重启服务"
echo -e "  ${BLUE}./manage.sh logs${NC}     - 📋 查看实时日志"
echo -e "  ${BLUE}./manage.sh status${NC}   - 📊 查看运行状态"
echo -e "  ${BLUE}./manage.sh shell${NC}    - 🐚 进入容器调试"
echo ""
echo -e "${GREEN}✅ 容器已在后台运行，SSH断开不会影响服务${NC}"
echo -e "${GREEN}🔍 查看实时日志: ${YELLOW}./manage.sh logs${NC}"
echo ""

# 显示初始日志
print_status "显示启动日志 (5秒后自动退出)..."
timeout 5 $COMPOSE_CMD logs -f || true

echo ""
print_success "Nexus Network 节点已成功启动！"
