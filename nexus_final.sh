#!/bin/bash

# Nexus Network 一键安装脚本 for Ubuntu 22.04
# 作者: AI Assistant
# 版本: 1.0

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

# 检查是否为root用户
if [ "$EUID" -eq 0 ]; then
    print_error "请不要使用root用户运行此脚本"
    exit 1
fi

# 检查系统版本
if ! grep -q "Ubuntu" /etc/os-release; then
    print_warning "此脚本专为Ubuntu系统设计，其他系统可能存在兼容性问题"
fi

# 更新系统包（可选）
read -p "是否更新系统包？(y/N): " update_system
if [[ $update_system =~ ^[Yy]$ ]]; then
    print_status "更新系统包..."
    sudo apt update && sudo apt upgrade -y
else
    print_status "跳过系统更新"
fi

# 检查并安装Docker
print_status "检查Docker安装状态..."
if ! command -v docker &> /dev/null; then
    print_status "Docker未安装，正在安装..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_warning "Docker安装完成，需要重新登录以生效用户组权限"
    print_warning "请退出当前会话，重新登录后再次运行此脚本"
    exit 0
else
    print_status "Docker已安装"
fi

# 检查并安装Docker Compose
print_status "检查Docker Compose安装状态..."
if ! command -v docker-compose &> /dev/null; then
    print_status "Docker Compose未安装，正在安装..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_status "Docker Compose安装完成"
else
    print_status "Docker Compose已安装"
fi

# 创建工作目录
WORK_DIR="nexus-network-docker"
print_status "创建工作目录: $WORK_DIR"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 创建Dockerfile
print_status "创建Dockerfile..."
cat > Dockerfile.nexus << 'EOF'
FROM ubuntu:22.04

# 设置非交互模式，避免安装过程中的提示
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

# 设置启动脚本
COPY --chown=nexus:nexus start_nexus.sh /home/nexus/
RUN chmod +x /home/nexus/start_nexus.sh

# 暴露可能需要的端口
EXPOSE 8080

CMD ["/home/nexus/start_nexus.sh"]
EOF

# 创建启动脚本
print_status "创建启动脚本..."
cat > start_nexus.sh << 'EOF'
#!/bin/bash

# Nexus Network 启动脚本

echo "开始启动 Nexus Network..."

# 检查 NODE_ID 环境变量
if [ -z "$NODE_ID" ]; then
    echo "错误: 请设置 NODE_ID 环境变量"
    echo "使用方法: docker run -e NODE_ID=你的ID ..."
    exit 1
fi

echo "使用Node ID: $NODE_ID"

# 启动Nexus Network
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
      dockerfile: Dockerfile.nexus
    container_name: nexus-node
    restart: unless-stopped
    environment:
      - NODE_ID=${NODE_ID}
    ports:
      - "8080:8080"
    volumes:
      - nexus_data:/home/nexus/.nexus_data
    networks:
      - nexus_network
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'
        reservations:
          memory: 512M
          cpus: '0.5'

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

case "$1" in
    start)
        echo "启动Nexus Network..."
        docker-compose up -d
        ;;
    stop)
        echo "停止Nexus Network..."
        docker-compose down
        ;;
    restart)
        echo "重启Nexus Network..."
        docker-compose restart
        ;;
    logs)
        echo "查看日志..."
        docker-compose logs -f
        ;;
    status)
        echo "查看状态..."
        docker-compose ps
        ;;
    shell)
        echo "进入容器..."
        docker exec -it nexus-node bash
        ;;
    *)
        echo "用法: $0 {start|stop|restart|logs|status|shell}"
        echo ""
        echo "  start   - 启动服务"
        echo "  stop    - 停止服务"
        echo "  restart - 重启服务"
        echo "  logs    - 查看实时日志"
        echo "  status  - 查看运行状态"
        echo "  shell   - 进入容器调试"
        exit 1
        ;;
esac
EOF

chmod +x manage.sh

# 获取Node ID
echo ""
while true; do
    read -p "请输入您的Node ID: " NODE_ID
    if [ -n "$NODE_ID" ]; then
        break
    else
        print_error "Node ID不能为空，请重新输入"
    fi
done

# 创建.env文件
echo "NODE_ID=$NODE_ID" > .env

# 构建Docker镜像
print_status "构建Docker镜像..."
docker-compose build

# 启动容器
print_status "启动容器..."
docker-compose up -d

echo ""
echo "=================================="
echo -e "${GREEN}✅ 安装完成！${NC}"
echo "=================================="
echo ""
echo -e "${BLUE}管理命令:${NC}"
echo "  ./manage.sh start    - 启动服务"
echo "  ./manage.sh stop     - 停止服务"
echo "  ./manage.sh restart  - 重启服务"
echo "  ./manage.sh logs     - 查看实时日志"
echo "  ./manage.sh status   - 查看运行状态"
echo "  ./manage.sh shell    - 进入容器调试"
echo ""
echo -e "${BLUE}状态信息:${NC}"
echo "  工作目录: $(pwd)"
echo "  Node ID: $NODE_ID"
echo "  容器名称: nexus-node"
echo ""
echo -e "${GREEN}✅ 容器已在后台运行，SSH断开不会影响服务${NC}"
echo ""
echo "查看实时日志: ./manage.sh logs"
