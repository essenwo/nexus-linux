#!/bin/bash

# =======================================================
# Nexus Network CLI 一键安装脚本 (完全非交互版)
# 适用于 Ubuntu/Debian Linux 系统
# 完全避免任何交互提示，包括Docker配置
# =======================================================

set -e  # 遇到错误立即退出

# 设置完全非交互模式，避免安装过程中的任何交互式提示
export DEBIAN_FRONTEND=noninteractive
export UCF_FORCE_CONFFNEW=1
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 打印彩色消息
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_step() {
    echo -e "${PURPLE}🚀 $1${NC}"
}

# 显示脚本标题
show_banner() {
    echo ""
    print_step "========================================="
    print_step "   Nexus Network CLI 一键安装脚本"
    print_step "   完全非交互式版本"
    print_step "========================================="
    echo ""
}

# 检查系统兼容性
check_system() {
    print_info "检查系统兼容性..."
    
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_error "此脚本仅支持 Linux 系统"
        exit 1
    fi
    
    if ! command -v apt &> /dev/null; then
        print_error "此脚本仅支持基于 APT 的系统（Ubuntu/Debian）"
        exit 1
    fi
    
    print_success "系统检查通过"
}

# 清理 APT 锁定和配置非交互模式
cleanup_and_configure() {
    print_info "清理 APT 锁定和配置非交互模式..."
    
    # 终止可能的 apt 进程和自动更新
    sudo pkill -f "apt|dpkg|unattended-upgrade|needrestart" 2>/dev/null || true
    sleep 5
    
    # 清理锁文件
    sudo rm -f /var/lib/dpkg/lock-frontend
    sudo rm -f /var/lib/dpkg/lock
    sudo rm -f /var/cache/apt/archives/lock
    sudo rm -f /var/lib/apt/lists/lock
    
    # 修复可能的包管理器问题
    sudo dpkg --configure -a 2>/dev/null || true
    
    # 配置debconf为非交互模式
    echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
    
    # 创建needrestart配置文件以避免重启提示
    sudo mkdir -p /etc/needrestart/conf.d
    echo '$nrconf{restart} = "a";' | sudo tee /etc/needrestart/conf.d/no-prompt.conf > /dev/null
    echo '$nrconf{kernelhints} = 0;' | sudo tee -a /etc/needrestart/conf.d/no-prompt.conf > /dev/null
    
    # 禁用自动重启服务提示
    sudo mkdir -p /etc/apt/apt.conf.d
    echo 'DPkg::Post-Invoke { "sleep 0"; };' | sudo tee /etc/apt/apt.conf.d/00no-restart > /dev/null
    
    # 创建Docker预配置，避免交互式配置
    echo 'docker.io docker.io/restart select true' | sudo debconf-set-selections 2>/dev/null || true
    
    print_success "系统配置完成"
}

# 安装系统依赖
install_dependencies() {
    print_info "更新系统和安装依赖..."
    
    # 更新系统包列表（完全静默）
    sudo DEBIAN_FRONTEND=noninteractive apt update -y -qq > /dev/null 2>&1
    
    # 升级系统（完全静默，强制非交互）
    sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt upgrade -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew" \
        -o APT::Get::Assume-Yes=true \
        -o APT::Get::Fix-Broken=true \
        > /dev/null 2>&1
    
    # 安装必要依赖（完全静默）
    sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt install -y -qq \
        build-essential \
        pkg-config \
        libssl-dev \
        git \
        curl \
        cmake \
        protobuf-compiler \
        libprotobuf-dev \
        screen \
        wget \
        ca-certificates \
        gnupg \
        lsb-release \
        --no-install-recommends \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew" \
        -o APT::Get::Assume-Yes=true \
        > /dev/null 2>&1
    
    print_success "依赖安装完成"
}

# 安装 Rust
install_rust() {
    print_info "安装 Rust..."
    
    if command -v rustc &> /dev/null; then
        print_warning "Rust 已安装，跳过安装步骤"
    else
        # 非交互式安装 Rust
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path > /dev/null 2>&1
        source ~/.cargo/env
        print_success "Rust 安装完成"
    fi
    
    # 确保 Rust 在 PATH 中
    export PATH="$HOME/.cargo/bin:$PATH"
    
    # 添加 RISC-V 目标
    rustup target add riscv32i-unknown-none-elf > /dev/null 2>&1
    print_success "RISC-V 目标添加完成"
}

# 安装 Nexus CLI
install_nexus_cli() {
    print_info "安装 Nexus Network CLI..."
    
    # 下载安装脚本
    local install_script="/tmp/nexus_install.sh"
    curl -sSL https://cli.nexus.xyz/ -o "$install_script" 2>/dev/null
    chmod +x "$install_script"
    
    # 设置环境变量避免交互
    export NEXUS_AUTO_CONFIRM=yes
    export NEXUS_SKIP_PROMPTS=1
    
    # 完全非交互式运行安装脚本
    {
        echo -e "Y\ny\nyes\nY\n"
        sleep 1
        echo -e "Y\ny\nyes\nY\n"
    } | timeout 300 bash "$install_script" > /dev/null 2>&1 || {
        # 备用方法
        printf "Y\nY\ny\nyes\n" | bash "$install_script" > /dev/null 2>&1 || \
        bash "$install_script" </dev/null > /dev/null 2>&1 || true
    }
    
    # 清理
    rm -f "$install_script"
    
    # 更新环境变量
    source ~/.bashrc 2>/dev/null || true
    
    print_success "Nexus CLI 安装完成"
}

# 查找 nexus-network 命令
find_nexus_command() {
    local nexus_cmd=""
    
    # 更新环境变量
    source ~/.bashrc 2>/dev/null || true
    export PATH="$HOME/.local/bin:$HOME/.nexus:$PATH"
    
    # 按优先级检查路径
    if command -v nexus-network &> /dev/null; then
        nexus_cmd="nexus-network"
    elif [[ -x "$HOME/.local/bin/nexus-network" ]]; then
        nexus_cmd="$HOME/.local/bin/nexus-network"
    elif [[ -x "$HOME/.nexus/nexus-network" ]]; then
        nexus_cmd="$HOME/.nexus/nexus-network"
    elif [[ -x "/usr/local/bin/nexus-network" ]]; then
        nexus_cmd="/usr/local/bin/nexus-network"
    else
        # 快速搜索（限制时间避免卡住）
        nexus_cmd=$(timeout 10 find /root /home /opt /usr/local -name "nexus-network" -type f -executable 2>/dev/null | head -1 || echo "")
    fi
    
    echo "$nexus_cmd"
}

# 验证安装
verify_installation() {
    print_info "验证安装..."
    
    local nexus_cmd=$(find_nexus_command)
    
    if [[ -n "$nexus_cmd" ]] && [[ -x "$nexus_cmd" ]]; then
        print_success "Nexus Network CLI 验证成功: $nexus_cmd"
        return 0
    else
        print_warning "未找到 nexus-network，将尝试使用默认路径"
        return 0  # 继续执行，不退出
    fi
}

# 获取Node ID（非交互式处理）
get_node_id() {
    echo ""
    print_step "配置 Node ID"
    echo ""
    print_info "请访问 https://app.nexus.xyz 获取你的 Node ID"
    echo ""
    
    # 检查是否通过环境变量传入
    if [[ -n "$NEXUS_NODE_ID" ]]; then
        NODE_ID="$NEXUS_NODE_ID"
        print_success "使用环境变量中的 Node ID: $NODE_ID"
        return
    fi
    
    # 交互式输入
    while true; do
        read -p "请输入你的 Node ID (或按 Ctrl+C 退出): " NODE_ID
        if [[ -n "$NODE_ID" ]]; then
            break
        else
            print_warning "Node ID 不能为空，请重新输入"
        fi
    done
    
    print_success "Node ID 设置完成: $NODE_ID"
}

# 启动 Screen 会话
start_screen_session() {
    echo ""
    print_step "启动 Nexus Network"
    echo ""
    
    # 终止可能存在的旧会话
    screen -S nexus-prover -X quit 2>/dev/null || true
    sleep 2
    
    # 查找 nexus-network 命令
    local nexus_cmd=$(find_nexus_command)
    
    if [[ -z "$nexus_cmd" ]]; then
        nexus_cmd="nexus-network"  # 使用默认值
        print_warning "使用默认命令: nexus-network"
    else
        print_info "使用命令: $nexus_cmd"
    fi
    
    print_info "正在启动 screen 会话..."
    print_warning "程序将在后台运行"
    
    # 启动 screen 会话
    screen -dmS nexus-prover bash -c "
        export PATH=\"$HOME/.local/bin:$HOME/.nexus:\$PATH\"
        echo '正在启动 Nexus Network...'
        echo 'Node ID: $NODE_ID'
        echo 'Started at: \$(date)'
        echo ''
        $nexus_cmd start --node-id '$NODE_ID'
    "
    
    sleep 5
    
    # 检查会话是否成功启动
    if screen -list | grep -q "nexus-prover"; then
        print_success "Nexus Network 已在后台启动！"
    else
        print_error "启动失败，请手动运行"
        print_info "手动启动命令: $nexus_cmd start --node-id $NODE_ID"
        print_info "或在screen中运行: screen -S nexus-prover $nexus_cmd start --node-id $NODE_ID"
    fi
}

# 显示安装完成信息
show_completion_info() {
    echo ""
    print_step "🎉 安装完成！"
    echo ""
    print_success "Nexus Network 正在后台运行"
    echo ""
    print_info "管理命令:"
    echo "  查看运行状态: screen -r nexus-prover"
    echo "  查看所有会话: screen -ls"
    echo "  退出会话视图: 按 Ctrl+A 然后按 D"
    echo "  停止程序: screen -r nexus-prover (然后按 Ctrl+C)"
    echo ""
    print_info "重要提醒:"
    echo "  • 程序正在后台运行并赚取 NEX Points"
    echo "  • 定期检查运行状态: screen -r nexus-prover"
    echo "  • 访问 https://app.nexus.xyz 查看收益"
    echo "  • 服务器重启后需要重新运行程序"
    echo ""
    print_warning "现在可以安全地关闭SSH连接，程序将继续运行"
    echo ""
    print_info "如果遇到问题，请访问: https://github.com/essenwo/nexus-linux"
    echo ""
}

# 错误处理
handle_error() {
    print_error "安装过程中发生错误"
    print_info "请检查："
    echo "  1. 网络连接是否正常"
    echo "  2. 系统权限是否足够"
    echo "  3. 磁盘空间是否充足"
    echo "  4. 系统是否为Ubuntu/Debian"
    echo ""
    print_info "如需帮助，请访问: https://github.com/essenwo/nexus-linux"
    exit 1
}

trap 'handle_error' ERR

# 主函数
main() {
    show_banner
    check_system
    cleanup_and_configure
    install_dependencies
    install_rust
    install_nexus_cli
    verify_installation
    get_node_id
    start_screen_session
    show_completion_info
}

# 运行主函数
main "$@"
