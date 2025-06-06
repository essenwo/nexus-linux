#!/bin/bash

# =======================================================
# Nexus Network CLI 一键安装脚本
# 适用于 Ubuntu/Debian Linux 系统
# 作者: essenwo
# GitHub: https://github.com/essenwo/nexus-linux
# =======================================================

set -e  # 遇到错误立即退出

# 设置非交互模式，避免安装过程中的交互式提示
export DEBIAN_FRONTEND=noninteractive
export UCF_FORCE_CONFFNEW=1

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
    print_step "   适用于 Ubuntu/Debian Linux 系统"
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

# 清理 APT 锁定
cleanup_apt_locks() {
    print_info "清理 APT 锁定..."
    
    # 终止可能的 apt 进程
    sudo pkill -f "apt|dpkg" 2>/dev/null || true
    sleep 2
    
    # 清理锁文件
    sudo rm -f /var/lib/dpkg/lock-frontend
    sudo rm -f /var/lib/dpkg/lock
    sudo rm -f /var/cache/apt/archives/lock
    sudo rm -f /var/lib/apt/lists/lock
    
    # 修复可能的包管理器问题
    sudo dpkg --configure -a 2>/dev/null || true
    
    print_success "APT 锁定清理完成"
}

# 安装系统依赖
install_dependencies() {
    print_info "更新系统和安装依赖..."
    
    cleanup_apt_locks
    
    # 更新系统
    sudo DEBIAN_FRONTEND=noninteractive apt update -y
    sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew"
    
    # 安装必要依赖
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
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
        --no-install-recommends \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew"
    
    print_success "依赖安装完成"
}

# 安装 Rust
install_rust() {
    print_info "安装 Rust..."
    
    if command -v rustc &> /dev/null; then
        print_warning "Rust 已安装，跳过安装步骤"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        source ~/.cargo/env
        print_success "Rust 安装完成"
    fi
    
    # 确保 Rust 在 PATH 中
    export PATH="$HOME/.cargo/bin:$PATH"
    
    # 添加 RISC-V 目标
    rustup target add riscv32i-unknown-none-elf
    print_success "RISC-V 目标添加完成"
}

# 安装 Nexus CLI
install_nexus_cli() {
    print_info "安装 Nexus Network CLI..."
    
    # 下载并运行安装脚本
    local install_script="/tmp/nexus_install.sh"
    wget -q -O "$install_script" https://cli.nexus.xyz/
    chmod +x "$install_script"
    
    # 自动回答 Y
    echo "Y" | bash "$install_script"
    
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
    export PATH="$HOME/.local/bin:$PATH"
    
    # 按优先级检查路径
    if command -v nexus-network &> /dev/null; then
        nexus_cmd="nexus-network"
    elif [[ -x "$HOME/.local/bin/nexus-network" ]]; then
        nexus_cmd="$HOME/.local/bin/nexus-network"
    elif [[ -x "/usr/local/bin/nexus-network" ]]; then
        nexus_cmd="/usr/local/bin/nexus-network"
    else
        # 快速搜索（限制时间避免卡住）
        nexus_cmd=$(timeout 10 find /root /home /opt /usr/local -name "nexus-network" -type f -executable 2>/dev/null | head -1)
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

# 启动 Screen 会话
start_screen_session() {
    echo ""
    print_step "准备启动 Nexus Network"
    echo ""
    print_info "安装完成！即将启动 screen 会话"
    print_warning "在 screen 会话中："
    echo "  1. 程序会提示你输入 Node ID"
    echo "  2. 请访问 https://app.nexus.xyz 获取你的 Node ID"
    echo "  3. 输入 Node ID 后程序开始运行"
    echo "  4. 使用 Ctrl+A 然后按 D 来退出 screen 会话"
    echo "  5. 使用 'screen -r nexus-prover' 重新连接"
    echo ""
    
    # 终止可能存在的旧会话
    screen -S nexus-prover -X quit 2>/dev/null || true
    sleep 1
    
    print_success "正在启动 screen 会话..."
    print_warning "现在进入 screen 会话，请按照提示操作"
    echo ""
    
    # 查找 nexus-network 命令
    local nexus_cmd=$(find_nexus_command)
    
    if [[ -z "$nexus_cmd" ]]; then
        nexus_cmd="nexus-network"  # 使用默认值
        print_warning "使用默认命令: nexus-network"
    else
        print_info "使用命令: $nexus_cmd"
    fi
    
    # 启动 screen 会话并运行 nexus-network
    screen -S nexus-prover "$nexus_cmd" start
}

# 显示安装完成信息
show_completion_info() {
    echo ""
    print_step "🎉 Nexus Network 已启动！"
    echo ""
    print_success "如果你已经退出了 screen 会话，可以使用以下命令："
    echo ""
    print_info "管理命令:"
    echo "  重新连接: screen -r nexus-prover"
    echo "  查看会话: screen -ls"
    echo "  停止程序: screen -r nexus-prover (然后按 Ctrl+C)"
    echo ""
    print_info "重要提醒:"
    echo "  • 程序正在后台运行并赚取 NEX Points"
    echo "  • 定期检查运行状态确保正常工作"
    echo "  • 访问 https://app.nexus.xyz 查看收益"
    echo ""
}

# 错误处理
handle_error() {
    print_error "安装过程中发生错误"
    print_info "请检查网络连接和系统权限"
    exit 1
}

trap 'handle_error' ERR

# 主函数
main() {
    show_banner
    check_system
    install_dependencies
    install_rust
    install_nexus_cli
    verify_installation
    start_screen_session
    show_completion_info
}

# 运行主函数
main "$@"
