#!/bin/bash

# =======================================================
# Nexus Network CLI 一键安装脚本 v2.0
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
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_success() {
    print_message $GREEN "✅ $1"
}

print_error() {
    print_message $RED "❌ $1"
}

print_warning() {
    print_message $YELLOW "⚠️  $1"
}

print_info() {
    print_message $BLUE "ℹ️  $1"
}

print_step() {
    print_message $PURPLE "🚀 $1"
}

# 显示脚本标题
show_banner() {
    echo ""
    print_step "========================================="
    print_step "   Nexus Network CLI 一键安装脚本 v2.0"
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
    
    # 检查是否为 root 用户或有 sudo 权限
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        print_error "此脚本需要 root 权限或 sudo 权限"
        exit 1
    fi
    
    print_success "系统检查通过"
}

# 清理 APT 锁定
cleanup_apt_locks() {
    print_info "检查并清理 APT 锁定..."
    
    # 检查是否有 apt 进程在运行
    if pgrep -f "apt|dpkg" > /dev/null; then
        print_warning "检测到 APT/DPKG 进程正在运行，尝试等待..."
        
        # 等待最多 60 秒
        local wait_time=0
        while pgrep -f "apt|dpkg" > /dev/null && [ $wait_time -lt 60 ]; do
            sleep 5
            wait_time=$((wait_time + 5))
            print_info "等待中... (${wait_time}s/60s)"
        done
        
        # 如果仍在运行，强制清理
        if pgrep -f "apt|dpkg" > /dev/null; then
            print_warning "强制终止 APT/DPKG 进程..."
            sudo pkill -f "apt|dpkg" || true
            sleep 2
        fi
    fi
    
    # 清理锁文件
    sudo rm -f /var/lib/dpkg/lock-frontend
    sudo rm -f /var/lib/dpkg/lock
    sudo rm -f /var/cache/apt/archives/lock
    sudo rm -f /var/lib/apt/lists/lock
    
    # 修复可能的包管理器问题
    sudo dpkg --configure -a || true
    
    print_success "APT 锁定清理完成"
}

# 安装系统依赖
install_dependencies() {
    print_info "更新系统包..."
    
    # 确保 APT 锁定已清理
    cleanup_apt_locks
    
    # 更新包列表
    sudo DEBIAN_FRONTEND=noninteractive apt update -y
    
    print_info "升级系统包..."
    sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew"
    
    print_success "系统更新完成"
    
    print_info "安装必要依赖..."
    
    # 定义需要安装的包
    local packages=(
        build-essential
        pkg-config
        libssl-dev
        git
        curl
        cmake
        protobuf-compiler
        libprotobuf-dev
        screen
        wget
        unzip
        ca-certificates
    )
    
    # 安装包
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "${packages[@]}" \
        --no-install-recommends \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew"
    
    print_success "依赖安装完成"
}

# 安装 Rust
install_rust() {
    print_info "检查 Rust 安装状态..."
    
    if command -v rustc &> /dev/null; then
        local rust_version=$(rustc --version | cut -d' ' -f2)
        print_warning "Rust 已安装 (版本: $rust_version)，跳过安装步骤"
    else
        print_info "安装 Rust 编程语言..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        
        # 重新加载环境
        source ~/.cargo/env || export PATH="$HOME/.cargo/bin:$PATH"
        print_success "Rust 安装完成"
    fi
    
    # 确保 Rust 在 PATH 中
    if ! command -v rustc &> /dev/null; then
        export PATH="$HOME/.cargo/bin:$PATH"
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    fi
    
    print_info "添加 RISC-V 目标..."
    rustup target add riscv32i-unknown-none-elf
    print_success "RISC-V 目标添加完成"
}

# 安装 Nexus CLI
install_nexus_cli() {
    print_info "安装 Nexus Network CLI..."
    
    # 使用 wget 下载安装脚本，避免管道问题
    local install_script="/tmp/nexus_install.sh"
    wget -q -O "$install_script" https://cli.nexus.xyz/
    
    if [[ ! -f "$install_script" ]]; then
        print_error "下载 Nexus 安装脚本失败"
        exit 1
    fi
    
    # 设置执行权限并运行
    chmod +x "$install_script"
    
    # 自动回答安装问题
    echo "Y" | bash "$install_script"
    
    # 清理临时文件
    rm -f "$install_script"
    
    print_success "Nexus CLI 安装完成"
}

# 配置环境变量
setup_environment() {
    print_info "配置环境变量..."
    
    # 可能的安装路径
    local possible_paths=(
        "$HOME/.local/bin"
        "/usr/local/bin"
        "$HOME/bin"
        "/opt/nexus"
    )
    
    local nexus_path=""
    
    # 查找 nexus-network 二进制文件
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path/nexus-network" ]]; then
            nexus_path="$path"
            break
        fi
    done
    
    # 如果没找到，使用 find 命令搜索
    if [[ -z "$nexus_path" ]]; then
        nexus_path=$(find /home /opt /usr -name "nexus-network" -type f 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
    fi
    
    if [[ -n "$nexus_path" ]]; then
        print_info "找到 Nexus CLI 路径: $nexus_path"
        
        # 添加到 PATH
        if [[ ":$PATH:" != *":$nexus_path:"* ]]; then
            export PATH="$nexus_path:$PATH"
            echo "export PATH=\"$nexus_path:\$PATH\"" >> ~/.bashrc
            print_success "PATH 环境变量已更新"
        fi
    else
        print_warning "未找到 nexus-network 二进制文件，将使用默认路径"
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    
    # 重新加载环境
    source ~/.bashrc 2>/dev/null || true
}

# 验证安装
verify_installation() {
    print_info "验证安装..."
    
    # 尝试多种方法查找和运行 nexus-network
    local nexus_cmd=""
    
    if command -v nexus-network &> /dev/null; then
        nexus_cmd="nexus-network"
    elif [[ -f "$HOME/.local/bin/nexus-network" ]]; then
        nexus_cmd="$HOME/.local/bin/nexus-network"
    elif [[ -f "/usr/local/bin/nexus-network" ]]; then
        nexus_cmd="/usr/local/bin/nexus-network"
    else
        # 最后的搜索尝试
        nexus_cmd=$(find /home /opt /usr -name "nexus-network" -type f -executable 2>/dev/null | head -1)
    fi
    
    if [[ -n "$nexus_cmd" ]] && [[ -x "$nexus_cmd" ]]; then
        print_success "找到 Nexus Network CLI: $nexus_cmd"
        
        # 测试运行
        if "$nexus_cmd" --help >/dev/null 2>&1; then
            print_success "Nexus Network CLI 验证成功"
            
            # 创建符号链接到 /usr/local/bin（如果需要）
            if [[ "$nexus_cmd" != "nexus-network" ]] && [[ ! -L "/usr/local/bin/nexus-network" ]]; then
                sudo ln -sf "$nexus_cmd" /usr/local/bin/nexus-network 2>/dev/null || true
            fi
            
            return 0
        else
            print_error "Nexus Network CLI 无法正常运行"
            return 1
        fi
    else
        print_error "未找到可执行的 Nexus Network CLI"
        return 1
    fi
}

# 获取用户输入
get_node_id() {
    echo ""
    print_step "配置 Nexus Network 节点"
    echo ""
    print_info "请访问 https://app.nexus.xyz 完成以下步骤："
    echo "  1. 创建账户并登录"
    echo "  2. 在控制面板中找到你的 Node ID"
    echo "  3. 复制 Node ID 并粘贴到下面"
    echo ""
    
    while true; do
        read -p "请输入你的 Node ID: " NODE_ID
        if [[ -n "$NODE_ID" ]] && [[ "$NODE_ID" =~ ^[0-9]+$ ]]; then
            print_success "Node ID 验证通过: $NODE_ID"
            break
        else
            print_error "请输入有效的 Node ID（纯数字）"
        fi
    done
}

# 启动服务
start_nexus() {
    print_step "启动 Nexus Network"
    
    # 确定 nexus-network 命令
    local nexus_cmd="nexus-network"
    if ! command -v nexus-network &> /dev/null; then
        if [[ -f "$HOME/.local/bin/nexus-network" ]]; then
            nexus_cmd="$HOME/.local/bin/nexus-network"
        elif [[ -f "/usr/local/bin/nexus-network" ]]; then
            nexus_cmd="/usr/local/bin/nexus-network"
        fi
    fi
    
    echo ""
    print_warning "即将在 screen 会话中启动 Nexus Network"
    print_info "Screen 会话管理命令:"
    echo "  - 查看会话: screen -ls"
    echo "  - 重新连接: screen -r nexus-prover"
    echo "  - 脱离会话: Ctrl+A 然后按 D"
    echo "  - 停止程序: screen -r nexus-prover 然后按 Ctrl+C"
    echo ""
    
    read -p "按 Enter 键继续启动..."
    
    # 检查是否已有同名会话
    if screen -list | grep -q "nexus-prover"; then
        print_warning "检测到已有 nexus-prover 会话，正在终止..."
        screen -S nexus-prover -X quit 2>/dev/null || true
        sleep 2
    fi
    
    print_success "正在创建 screen 会话 'nexus-prover'..."
    
    # 启动 screen 会话
    screen -dmS nexus-prover bash -c "
        echo '启动 Nexus Network CLI...'
        echo '使用 Ctrl+A 然后按 D 来脱离会话'
        echo '使用 screen -r nexus-prover 重新连接'
        echo ''
        $nexus_cmd start --node-id $NODE_ID
    "
    
    sleep 3
    
    # 验证会话是否启动
    if screen -list | grep -q "nexus-prover"; then
        print_success "Nexus Network 已在后台启动！"
        print_info "使用 'screen -r nexus-prover' 查看运行状态"
    else
        print_error "启动 screen 会话失败"
        print_info "尝试手动启动: $nexus_cmd start --node-id $NODE_ID"
    fi
}

# 显示完成信息
show_completion_info() {
    echo ""
    print_step "🎉 安装完成！"
    echo ""
    print_success "Nexus Network CLI 已成功安装并启动"
    echo ""
    print_info "管理命令:"
    echo "  查看运行状态: screen -r nexus-prover"
    echo "  查看所有会话: screen -ls"
    echo "  停止程序: screen -r nexus-prover 然后按 Ctrl+C"
    echo "  重新启动: screen -dmS nexus-prover nexus-network start --node-id $NODE_ID"
    echo ""
    print_info "重要链接:"
    echo "  Nexus 官网: https://nexus.xyz"
    echo "  用户面板: https://app.nexus.xyz"
    echo "  官方文档: https://docs.nexus.xyz"
    echo "  GitHub 项目: https://github.com/essenwo/nexus-linux"
    echo ""
    print_warning "你的节点正在后台运行并赚取 NEX Points！"
    print_info "建议定期检查运行状态，确保节点正常工作。"
    echo ""
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    print_error "安装过程中发生错误 (退出代码: $exit_code, 行号: $line_number)"
    print_info "请检查上述输出信息，或访问 GitHub 项目页面寻求帮助"
    print_info "GitHub: https://github.com/essenwo/nexus-linux"
    exit $exit_code
}

# 设置错误处理
trap 'handle_error $LINENO' ERR

# 主函数
main() {
    show_banner
    check_system
    cleanup_apt_locks
    install_dependencies
    install_rust
    install_nexus_cli
    setup_environment
    
    if verify_installation; then
        get_node_id
        start_nexus
        show_completion_info
    else
        print_error "验证失败，但安装可能已完成"
        print_info "请尝试手动运行: nexus-network --help"
        print_info "或联系支持获取帮助"
        exit 1
    fi
}

# 运行主函数
main "$@"
