#!/bin/bash

# Nexus Network 宿主机直接安装脚本
# 避免Docker容器问题，直接在系统上安装

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
print_error() { echo -e "${RED}[错误]${NC} $1"; exit 1; }

print_header() {
    echo
    echo -e "${CYAN}=================================${NC}"
    echo -e "${PURPLE}  Nexus Network 宿主机安装${NC}"
    echo -e "${PURPLE}  直接安装，避免容器问题${NC}"
    echo -e "${CYAN}=================================${NC}"
    echo
}

# 检查系统
check_system() {
    print_step "检查系统环境..."
    
    # 检查Ubuntu版本
    if ! grep -q "22.04\|24.04" /etc/os-release; then
        print_error "仅支持Ubuntu 22.04或24.04"
    fi
    
    # 检查glibc版本
    GLIBC_VERSION=$(ldd --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+')
    echo "检测到GLIBC版本: $GLIBC_VERSION"
    
    if [ "$GLIBC_VERSION" != "2.39" ] && [ "$GLIBC_VERSION" != "2.40" ]; then
        print_error "需要GLIBC 2.39+，当前版本: $GLIBC_VERSION。请使用Docker方案。"
    fi
    
    print_success "系统兼容性检查通过"
}

# 安装依赖
install_deps() {
    print_step "安装系统依赖..."
    apt-get update
    apt-get install -y curl build-essential cmake pkg-config libssl-dev screen
    print_success "依赖安装完成"
}

# 安装Rust
install_rust() {
    print_step "安装Rust..."
    if command -v rustc &> /dev/null; then
        print_success "Rust已安装: $(rustc --version)"
        return
    fi
    
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    rustup target add riscv32i-unknown-none-elf
    print_success "Rust安装完成"
}

# 安装Nexus CLI
install_nexus() {
    print_step "安装Nexus CLI..."
    if command -v nexus-network &> /dev/null; then
        print_success "Nexus CLI已安装: $(nexus-network --version)"
        return
    fi
    
    echo "y" | curl https://cli.nexus.xyz/ | sh
    source ~/.profile
    
    # 验证安装
    if command -v nexus-network &> /dev/null; then
        print_success "Nexus CLI安装成功: $(nexus-network --version)"
    else
        print_error "Nexus CLI安装失败"
    fi
}

# 获取Node ID
get_node_id() {
    echo
    echo -e "${YELLOW}请访问 https://app.nexus.xyz 获取 Node ID${NC}"
    echo
    while true; do
        read -p "请输入Node ID: " NODE_ID
        if [[ "$NODE_ID" =~ ^[0-9]+$ ]]; then
            break
        else
            print_error "请输入有效数字"
        fi
    done
}

# 创建服务脚本
create_service() {
    print_step "创建Nexus服务..."
    
    # 创建启动脚本
    cat > /usr/local/bin/nexus-start.sh << EOF
#!/bin/bash
export PATH="/root/.nexus/bin:/root/.cargo/bin:\$PATH"
cd /root
echo "启动Nexus网络节点..."
echo "Node ID: $NODE_ID"
echo "时间: \$(date)"
exec nexus-network start --node-id $NODE_ID
EOF
    chmod +x /usr/local/bin/nexus-start.sh
    
    # 创建systemd服务
    cat > /etc/systemd/system/nexus.service << EOF
[Unit]
Description=Nexus Network Node
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/nexus-start.sh
Restart=always
RestartSec=10
Environment=PATH=/root/.nexus/bin:/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载并启动服务
    systemctl daemon-reload
    systemctl enable nexus.service
    systemctl start nexus.service
    
    print_success "Nexus服务已创建并启动"
}

# 显示状态
show_status() {
    echo
    echo -e "${CYAN}📋 安装完成信息:${NC}"
    echo "  Node ID: $NODE_ID"
    echo "  服务名: nexus.service"
    echo "  状态: $(systemctl is-active nexus.service)"
    echo
    echo -e "${CYAN}📖 管理命令:${NC}"
    echo "  查看状态: systemctl status nexus"
    echo "  查看日志: journalctl -u nexus -f"
    echo "  重启服务: systemctl restart nexus"
    echo "  停止服务: systemctl stop nexus"
    echo "  启动服务: systemctl start nexus"
    echo
    
    sleep 3
    echo -e "${CYAN}📄 运行日志:${NC}"
    journalctl -u nexus --no-pager --lines=10
}

# 主函数
main() {
    print_header
    check_system
    install_deps
    install_rust
    install_nexus
    get_node_id
    create_service
    show_status
    
    echo
    echo -e "${GREEN}🎉 安装完成！Nexus节点正在后台运行${NC}"
    echo -e "${YELLOW}💡 使用 'journalctl -u nexus -f' 查看实时日志${NC}"
}

main
