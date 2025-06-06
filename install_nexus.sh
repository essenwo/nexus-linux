#!/bin/bash

# =======================================================
# Nexus Network CLI 一键安装脚本
# 适用于 Ubuntu/Debian Linux 系统
# 作者: Essen的节点日记
# =======================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 安装系统依赖
install_dependencies() {
    print_info "更新系统包..."
    sudo apt update && sudo apt upgrade -y
    print_success "系统更新完成"
    
    print_info "安装必要依赖..."
    sudo apt install -y build-essential pkg-config libssl-dev git-all curl cmake protobuf-compiler libprotobuf-dev screen
    print_success "依赖安装完成"
}

# 安装 Rust
install_rust() {
    print_info "安装 Rust 编程语言..."
    
    if command -v rustc &> /dev/null; then
        print_warning "Rust 已安装，跳过此步骤"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
        print_success "Rust 安装完成"
    fi
    
    print_info "添加 RISC-V 目标..."
    rustup target add riscv32i-unknown-none-elf
    print_success "RISC-V 目标添加完成"
}

# 安装 Nexus CLI
install_nexus_cli() {
    print_info "安装 Nexus Network CLI..."
    curl https://cli.nexus.xyz/ | sh
    
    # 更新环境变量
    source ~/.bashrc 2>/dev/null || source ~/.profile 2>/dev/null || true
    
    print_success "Nexus CLI 安装完成"
}

# 验证安装
verify_installation() {
    print_info "验证安装..."
    
    if command -v nexus-network &> /dev/null; then
        nexus-network --help > /dev/null
        print_success "Nexus Network CLI 安装验证成功"
    else
        print_error "Nexus Network CLI 安装失败"
        exit 1
    fi
}

# 获取用户输入
get_node_id() {
    echo ""
    print_info "请访问 https://app.nexus.xyz 创建账户并获取你的 Node ID"
    echo ""
    
    while true; do
        read -p "请输入你的 Node ID: " NODE_ID
        if [[ -n "$NODE_ID" ]] && [[ "$NODE_ID" -gt 0 ]] 2>/dev/null; then
            break
        else
            print_error "请输入有效的 Node ID（数字）"
        fi
    done
}

# 启动服务
start_nexus() {
    print_info "准备启动 Nexus Network..."
    
    echo ""
    print_warning "即将在 screen 会话中启动 Nexus Network"
    print_info "使用以下命令管理 screen 会话:"
    echo "  - 查看会话: screen -ls"
    echo "  - 重新连接: screen -r nexus-prover"
    echo "  - 脱离会话: Ctrl+A 然后按 D"
    echo ""
    
    read -p "按 Enter 键继续..."
    
    print_success "正在创建 screen 会话 'nexus-prover'..."
    print_info "程序启动后，请按 Ctrl+A 然后按 D 来脱离会话"
    
    sleep 2
    screen -S nexus-prover -dm nexus-network start --node-id $NODE_ID
    
    sleep 3
    print_success "Nexus Network 已在后台启动！"
    print_info "使用 'screen -r nexus-prover' 查看运行状态"
}

# 显示完成信息
show_completion_info() {
    echo ""
    print_success "🎉 Nexus Network CLI 安装完成！"
    echo ""
    print_info "管理命令:"
    echo "  查看运行状态: screen -r nexus-prover"
    echo "  查看所有会话: screen -ls"
    echo "  停止程序: screen -r nexus-prover 然后按 Ctrl+C"
    echo ""
    print_info "重要链接:"
    echo "  Nexus 官网: https://nexus.xyz"
    echo "  用户面板: https://app.nexus.xyz"
    echo "  文档: https://docs.nexus.xyz"
    echo ""
    print_warning "程序正在后台运行并赚取 NEX Points！"
}

# 主函数
main() {
    echo ""
    print_info "🚀 Nexus Network CLI 一键安装脚本"
    print_info "适用于 Ubuntu/Debian Linux 系统"
    echo ""
    
    check_system
    install_dependencies
    install_rust
    install_nexus_cli
    verify_installation
    get_node_id
    start_nexus
    show_completion_info
}

# 错误处理
trap 'print_error "安装过程中发生错误，请检查上述输出"; exit 1' ERR

# 运行主函数
main "$@"
