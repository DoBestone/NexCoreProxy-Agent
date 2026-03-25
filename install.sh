#!/bin/bash

# NexCoreProxy Agent 一键安装脚本
# 使用方法: 
#   bash <(curl -Ls https://raw.githubusercontent.com/DoBestone/NexCoreProxy-Agent/main/install.sh) -u admin -pass YourPassword

set -e

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

APP_NAME="NexCoreProxy Agent"
INSTALL_DIR="/usr/local/x-ui"
SERVICE_PORT=54321

# 默认配置
ADMIN_USER="ncp_admin"
ADMIN_PASS=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            ADMIN_USER="$2"
            shift 2
            ;;
        -pass|--password)
            ADMIN_PASS="$2"
            shift 2
            ;;
        -h|--help)
            echo "使用方法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  -u, --user USER       管理员用户名 (默认: ncp_admin)"
            echo "  -pass, --password     管理员密码 (必填)"
            echo ""
            echo "示例:"
            echo "  $0 -u admin -pass MyPassword123"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${green}========================================${plain}"
echo -e "${green}  $APP_NAME 安装脚本${plain}"
echo -e "${green}========================================${plain}"

# 检查必填参数
if [[ -z "$ADMIN_PASS" ]]; then
    echo -e "${red}错误: 请通过 -pass 参数设置管理员密码${plain}"
    echo "示例: $0 -pass YourPassword123"
    exit 1
fi

# 检查 root
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}请使用 root 用户运行此脚本${plain}"
    exit 1
fi

# 检测系统
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${red}无法检测系统版本${plain}"
    exit 1
fi

echo "系统: $OS"

# 安装依赖
echo -e "${yellow}安装依赖...${plain}"
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    apt update && apt install -y wget curl
elif [[ "$OS" == "centos" ]]; then
    yum install -y wget curl
else
    echo -e "${red}不支持的系统: $OS${plain}"
    exit 1
fi

# 停止旧服务
systemctl stop x-ui 2>/dev/null || true

# 下载最新版本
cd /usr/local/
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    ARCH="arm64"
fi

echo -e "${yellow}下载 x-ui...${plain}"
last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ ! -n "$last_version" ]]; then
    last_version="0.3.2"
fi

wget -q -O x-ui-linux-${ARCH}.tar.gz "https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${ARCH}.tar.gz" || {
    echo -e "${red}下载失败${plain}"
    exit 1
}

# 解压安装
rm -rf $INSTALL_DIR
tar -xzf x-ui-linux-${ARCH}.tar.gz
rm -f x-ui-linux-${ARCH}.tar.gz
cd x-ui
chmod +x x-ui bin/xray-linux-${ARCH}

# 复制服务文件
cp -f x-ui.service /etc/systemd/system/

# 下载管理脚本
wget -q -O /usr/bin/x-ui "https://raw.githubusercontent.com/vaxilu/x-ui/main/x-ui.sh"
chmod +x /usr/bin/x-ui
chmod +x x-ui.sh

# 配置固定端口和账号密码
echo -e "${yellow}配置服务...${plain}"
./x-ui setting -port ${SERVICE_PORT}
./x-ui setting -username "${ADMIN_USER}"
./x-ui setting -password "${ADMIN_PASS}"

# 开放防火墙
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=${SERVICE_PORT}/tcp
    firewall-cmd --reload 2>/dev/null
fi
if command -v ufw &> /dev/null; then
    ufw allow ${SERVICE_PORT}/tcp
fi

# 启动服务
systemctl daemon-reload
systemctl enable x-ui
systemctl start x-ui

# 获取服务器 IP
SERVER_IP=$(curl -s ifconfig.me || curl -s ip.sb || echo "YOUR_IP")

sleep 2

if systemctl is-active --quiet x-ui; then
    echo ""
    echo -e "${green}========================================${plain}"
    echo -e "${green}  安装成功!${plain}"
    echo -e "${green}========================================${plain}"
    echo ""
    echo -e "面板地址: ${green}http://${SERVER_IP}:${SERVICE_PORT}${plain}"
    echo -e "用户名:   ${green}${ADMIN_USER}${plain}"
    echo -e "密码:     ${green}${ADMIN_PASS}${plain}"
    echo ""
    echo -e "${yellow}主控面板配置信息:${plain}"
    echo "  IP: ${SERVER_IP}"
    echo "  端口: ${SERVICE_PORT}"
    echo "  用户名: ${ADMIN_USER}"
    echo "  密码: ${ADMIN_PASS}"
    echo ""
else
    echo -e "${red}安装失败，请检查日志${plain}"
    journalctl -u x-ui --no-pager -n 20
    exit 1
fi