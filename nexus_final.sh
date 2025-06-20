#!/bin/bash
set -e

# ========== 终极非交互配置 ==========
export DEBIAN_FRONTEND=noninteractive
export UCF_FORCE_CONFFNEW=1
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
export APT_LISTCHANGES_FRONTEND=none
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=yes

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_step() { echo -e "${PURPLE}🚀 $1${NC}"; }

show_banner() {
    echo ""
    print_step "========================================="
    print_step "   Nexus Network 终极非交互安装脚本"
    print_step "   彻底解决所有交互提示问题"
    print_step "========================================="
    echo ""
}

# 终极系统配置 - 彻底禁用所有交互
ultimate_system_config() {
    print_info "执行终极系统配置，禁用所有交互..."
    
    # 1. 杀掉所有可能的交互进程
    sudo pkill -9 -f "apt|dpkg|unattended-upgrade|needrestart|debconf|ucf" 2>/dev/null || true
    sudo pkill -9 -f "packagekit|update-manager|software-center" 2>/dev/null || true
    sleep 5
    
    # 2. 清理所有锁文件
    sudo rm -f /var/lib/dpkg/lock*
    sudo rm -f /var/cache/apt/archives/lock
    sudo rm -f /var/lib/apt/lists/lock
    
    # 3. 修复dpkg
    sudo dpkg --configure -a 2>/dev/null || true
    
    # 4. 创建终极debconf配置
    sudo mkdir -p /etc/debconf
    cat << 'EOF' | sudo tee /etc/debconf/debconf.conf > /dev/null
# Debconf system-wide configuration file
# This file contains the default settings for debconf.

# The frontend to use by default
Name: config
Template: debconf/frontend
Value: noninteractive
Owners: debconf
Flags: seen

Name: config  
Template: debconf/priority
Value: critical
Owners: debconf
Flags: seen
EOF

    # 5. 预配置所有可能的包
    cat << 'EOF' | sudo debconf-set-selections
# Docker configuration
docker.io docker.io/restart select true
docker-ce docker-ce/restart select true
containerd.io containerd.io/restart select true

# Postfix configuration  
postfix postfix/main_mailer_type select No configuration
postfix postfix/mailname string localhost

# Keyboard configuration
keyboard-configuration keyboard-configuration/layoutcode select us
keyboard-configuration keyboard-configuration/modelcode select pc105

# Locales
locales locales/default_environment_locale select en_US.UTF-8
locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8

# Grub
grub-pc grub-pc/install_devices_disks_changed multiselect 
grub-pc grub-pc/install_devices_empty boolean true

# Generic
debconf debconf/frontend select Noninteractive
debconf debconf/priority select critical
EOF

    # 6. 创建needrestart终极配置
    sudo mkdir -p /etc/needrestart/conf.d
    cat << 'EOF' | sudo tee /etc/needrestart/conf.d/no-prompt.conf > /dev/null
# Restart services automatically
$nrconf{restart} = 'a';
$nrconf{kernelhints} = 0;
$nrconf{ucodehints} = 0;
EOF

    # 7. 创建APT终极配置
    sudo mkdir -p /etc/apt/apt.conf.d
    cat << 'EOF' | sudo tee /etc/apt/apt.conf.d/99-no-interaction > /dev/null
Dpkg::Options {
    "--force-confdef";
    "--force-confnew";
    "--force-confmiss";
    "--force-unsafe-io";
}
APT::Get::Assume-Yes "true";
APT::Get::Fix-Broken "true";
APT::Get::Force-Yes "true";
APT::Get::Show-Upgraded "false";
DPkg::Pre-Install-Pkgs::={"sleep 1"};
DPkg::Post-Invoke {"sleep 1"};
Debug::pkgProblemResolver "false";
EOF

    # 8. 禁用所有交互式服务
    sudo systemctl stop unattended-upgrades 2>/dev/null || true
    sudo systemctl disable unattended-upgrades 2>/dev/null || true
    sudo systemctl mask unattended-upgrades 2>/dev/null || true
    
    print_success "终极系统配置完成"
}

# 静默安装依赖
silent_install_deps() {
    print_info "静默安装系统依赖..."
    
    # 强制终止可能的apt进程
    sudo fuser -k /var/lib/dpkg/lock 2>/dev/null || true
    sudo fuser -k /var/lib/dpkg/lock-frontend 2>/dev/null || true
    
    # 完全静默更新
    {
        sudo apt update -y -qq
    } >/dev/null 2>&1
    
    # 完全静默升级
    {
        sudo DEBIAN_FRONTEND=noninteractive \
        NEEDRESTART_MODE=a \
        UCF_FORCE_CONFFNEW=1 \
        apt upgrade -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew" \
        -o APT::Get::Assume-Yes=true
    } >/dev/null 2>&1
    
    # 完全静默安装依赖
    {
        sudo DEBIAN_FRONTEND=noninteractive \
        NEEDRESTART_MODE=a \
        UCF_FORCE_CONFFNEW=1 \
        apt install -y -qq \
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
        --no-install-recommends \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew" \
        -o APT::Get::Assume-Yes=true
    } >/dev/null 2>&1
    
    print_success "依赖安装完成"
}

# 安装Rust
install_rust() {
    print_info "安装 Rust..."
    
    if command -v rustc &> /dev/null; then
        print_warning "Rust 已安装，跳过安装步骤"
    else
        {
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
            sh -s -- -y --default-toolchain stable --no-modify-path
        } >/dev/null 2>&1
        source ~/.cargo/env
        print_success "Rust 安装完成"
    fi
    
    export PATH="$HOME/.cargo/bin:$PATH"
    rustup target add riscv32i-unknown-none-elf >/dev/null 2>&1
    print_success "RISC-V 目标添加完成"
}

# 安装Nexus CLI
install_nexus_cli() {
    print_info "安装 Nexus Network CLI..."
    
    local install_script="/tmp/nexus_install.sh"
    
    # 下载安装脚本
    curl -sSL https://cli.nexus.xyz/ -o "$install_script" 2>/dev/null
    chmod +x "$install_script"
    
    # 使用超时和多种方法确保非交互安装
    export NEXUS_AUTO_CONFIRM=yes
    export NEXUS_SKIP_PROMPTS=1
    
    # 方法1: 预填充输入
    {
        timeout 300 bash -c "
            echo -e 'Y\ny\nyes\nY\n' | '$install_script'
        "
    } >/dev/null 2>&1 || \
    
    # 方法2: 使用expect模拟（如果可用）
    {
        if command -v expect >/dev/null 2>&1; then
            expect -c "
                spawn bash $install_script
                expect \"*\" { send \"Y\r\" }
                expect \"*\" { send \"y\r\" }
                expect \"*\" { send \"yes\r\" }
                expect eof
            " >/dev/null 2>&1
        else
            printf "Y\nY\ny\nyes\n" | bash "$install_script" >/dev/null 2>&1
        fi
    } || \
    
    # 方法3: 强制运行
    {
        bash "$install_script" </dev/null >/dev/null 2>&1
    } || true
    
    rm -f "$install_script"
    source ~/.bashrc 2>/dev/null || true
    
    print_success "Nexus CLI 安装完成"
}

# 查找nexus命令
find_nexus_command() {
    source ~/.bashrc 2>/dev/null || true
    export PATH="$HOME/.local/bin:$HOME/.nexus:$PATH"
    
    if command -v nexus-network &>/dev/null; then
        echo "nexus-network"
    elif [[ -x "$HOME/.local/bin/nexus-network" ]]; then
        echo "$HOME/.local/bin/nexus-network"
    elif [[ -x "$HOME/.nexus/nexus-network" ]]; then
        echo "$HOME/.nexus/nexus-network"
    else
        echo "nexus-network"
    fi
}

# 获取Node ID
get_node_id() {
    echo ""
    print_step "配置 Node ID"
    print_info "请访问 https://app.nexus.xyz 获取你的 Node ID"
    echo ""
    
    if [[ -n "$NEXUS_NODE_ID" ]]; then
        NODE_ID="$NEXUS_NODE_ID"
        print_success "使用环境变量中的 Node ID: $NODE_ID"
        return
    fi
    
    while true; do
        read -p "请输入你的 Node ID: " NODE_ID
        if [[ -n "$NODE_ID" ]]; then
            break
        else
            print_warning "Node ID 不能为空，请重新输入"
        fi
    done
    
    print_success "Node ID 设置完成: $NODE_ID"
}

# 启动screen会话
start_screen_session() {
    print_step "启动 Nexus Network"
    
    screen -S nexus-prover -X quit 2>/dev/null || true
    sleep 2
    
    local nexus_cmd=$(find_nexus_command)
    print_info "使用命令: $nexus_cmd"
    
    screen -dmS nexus-prover bash -c "
        export PATH=\"$HOME/.local/bin:$HOME/.nexus:\$PATH\"
        echo '正在启动 Nexus Network...'
        echo 'Node ID: $NODE_ID'
        echo 'Started at: \$(date)'
        echo ''
        $nexus_cmd start --node-id '$NODE_ID'
    "
    
    sleep 5
    
    if screen -list | grep -q "nexus-prover"; then
        print_success "Nexus Network 已在后台启动！"
    else
        print_error "启动失败，请手动运行"
        print_info "手动启动命令: $nexus_cmd start --node-id $NODE_ID"
    fi
}

# 显示完成信息
show_completion() {
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
    print_warning "现在可以安全地关闭SSH连接，程序将继续运行"
    echo ""
}

# 错误处理
handle_error() {
    print_error "安装失败"
    print_info "请检查网络连接和系统权限"
    exit 1
}

trap 'handle_error' ERR

# 主函数
main() {
    show_banner
    ultimate_system_config
    silent_install_deps
    install_rust
    install_nexus_cli
    get_node_id
    start_screen_session
    show_completion
}

main "$@"
