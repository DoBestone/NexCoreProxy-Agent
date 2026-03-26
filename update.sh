#!/bin/bash

# 3x-ui Agent 更新脚本

set -e

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

INSTALL_DIR="/usr/local/x-ui"

echo -e "${green}========================================${plain}"
echo -e "${green}  3X-UI Agent 更新脚本${plain}"
echo -e "${green}========================================${plain}"

# 检查 root
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}请使用 root 用户运行此脚本${plain}"
    exit 1
fi

# 获取最新版本
echo -e "${yellow}检查最新版本...${plain}"
LATEST_VERSION=$(curl -s https://api.github.com/repos/MHSanaei/3x-ui/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$LATEST_VERSION" ]]; then
    LATEST_VERSION="v2.8.11"
fi

echo "最新版本: $LATEST_VERSION"

# 停止服务
echo -e "${yellow}停止服务...${plain}"
systemctl stop x-ui 2>/dev/null || true

# 备份数据库和配置
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${yellow}备份数据...${plain}"
    mkdir -p /tmp/x-ui-backup
    cp -f $INSTALL_DIR/db/x-ui.db /tmp/x-ui-backup/ 2>/dev/null || true
    cp -f $INSTALL_DIR/bin/config.json /tmp/x-ui-backup/ 2>/dev/null || true
fi

# 下载最新版本
cd /usr/local/
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    ARCH="arm64"
fi

echo -e "${yellow}下载 3X-UI $LATEST_VERSION...${plain}"
wget -q -O x-ui.tar.gz "https://github.com/MHSanaei/3x-ui/releases/download/${LATEST_VERSION}/x-ui-linux-${ARCH}.tar.gz" || {
    echo -e "${red}下载失败${plain}"
    exit 1
}

# 解压
tar -xzf x-ui.tar.gz
rm -f x-ui.tar.gz

# 恢复数据
if [[ -f /tmp/x-ui-backup/x-ui.db ]]; then
    echo -e "${yellow}恢复数据...${plain}"
    cp -f /tmp/x-ui-backup/x-ui.db $INSTALL_DIR/db/
    rm -rf /tmp/x-ui-backup
fi

# 写入版本
echo "$LATEST_VERSION" > $INSTALL_DIR/VERSION

# 设置权限
chmod +x $INSTALL_DIR/x-ui
chmod +x $INSTALL_DIR/bin/xray-linux-${ARCH} 2>/dev/null || true

# 重启服务
systemctl daemon-reload
systemctl start x-ui

sleep 2

if systemctl is-active --quiet x-ui; then
    echo ""
    echo -e "${green}========================================${plain}"
    echo -e "${green}  更新成功!${plain}"
    echo -e "${green}========================================${plain}"
    echo ""
    echo -e "当前版本: ${green}$LATEST_VERSION${plain}"
    echo ""
else
    echo -e "${red}更新失败，请检查日志${plain}"
    journalctl -u x-ui --no-pager -n 20
    exit 1
fi