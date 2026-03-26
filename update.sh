#!/bin/bash

# NexCoreProxy Agent 更新脚本

set -e

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

INSTALL_DIR="/usr/local/nexcore-agent"

echo -e "${green}========================================${plain}"
echo -e "${green}  NexCoreProxy Agent 更新脚本${plain}"
echo -e "${green}========================================${plain}"

# 检查 root
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}请使用 root 用户运行此脚本${plain}"
    exit 1
fi

# 获取最新版本
echo -e "${yellow}检查最新版本...${plain}"
LATEST_VERSION=$(curl -s https://api.github.com/repos/DoBestone/NexCoreProxy-Agent/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$LATEST_VERSION" ]]; then
    LATEST_VERSION="v1.0.0"
fi

echo "最新版本: $LATEST_VERSION"

# 停止服务
echo -e "${yellow}停止服务...${plain}"
systemctl stop nexcore-agent 2>/dev/null || true

# 备份配置
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${yellow}备份配置...${plain}"
    cp -f $INSTALL_DIR/config/config.json /tmp/nexcore-config-backup.json 2>/dev/null || true
    cp -f $INSTALL_DIR/database/x-ui.db /tmp/nexcore-db-backup.db 2>/dev/null || true
fi

# 下载最新版本
cd /usr/local/
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    ARCH="arm64"
fi

echo -e "${yellow}下载 NexCoreProxy-Agent $LATEST_VERSION...${plain}"
DOWNLOAD_URL="https://github.com/DoBestone/NexCoreProxy-Agent/releases/download/${LATEST_VERSION}/nexcore-agent-linux-${ARCH}.tar.gz"

# 尝试下载预编译版本，如果不存在则从源码构建
if ! wget -q -O nexcore-agent.tar.gz "$DOWNLOAD_URL" 2>/dev/null; then
    echo -e "${yellow}预编译版本不存在，从源码构建...${plain}"
    
    # 安装 Go (如果没有)
    if ! command -v go &> /dev/null; then
        echo -e "${yellow}安装 Go...${plain}"
        wget -q -O /tmp/go.tar.gz https://go.dev/dl/go1.21.5.linux-${ARCH}.tar.gz
        tar -C /usr/local -xzf /tmp/go.tar.gz
        export PATH=$PATH:/usr/local/go/bin
    fi
    
    # 克隆并构建
    git clone https://github.com/DoBestone/NexCoreProxy-Agent.git /tmp/nexcore-agent-src
    cd /tmp/nexcore-agent-src
    go build -o nexcore-agent .
    mkdir -p $INSTALL_DIR
    cp nexcore-agent $INSTALL_DIR/
    cd /usr/local
    rm -rf /tmp/nexcore-agent-src
else
    # 解压
    tar -xzf nexcore-agent.tar.gz
    rm -f nexcore-agent.tar.gz
fi

# 创建 VERSION 文件
echo "$LATEST_VERSION" > $INSTALL_DIR/VERSION

# 恢复配置
if [[ -f /tmp/nexcore-config-backup.json ]]; then
    cp -f /tmp/nexcore-config-backup.json $INSTALL_DIR/config/config.json
    rm -f /tmp/nexcore-config-backup.json
fi
if [[ -f /tmp/nexcore-db-backup.db ]]; then
    cp -f /tmp/nexcore-db-backup.db $INSTALL_DIR/database/x-ui.db
    rm -f /tmp/nexcore-db-backup.db
fi

# 设置权限
chmod +x $INSTALL_DIR/nexcore-agent
chown -R root:root $INSTALL_DIR

# 重启服务
systemctl daemon-reload
systemctl enable nexcore-agent
systemctl start nexcore-agent

sleep 2

if systemctl is-active --quiet nexcore-agent; then
    echo ""
    echo -e "${green}========================================${plain}"
    echo -e "${green}  更新成功!${plain}"
    echo -e "${green}========================================${plain}"
    echo ""
    echo -e "当前版本: ${green}$LATEST_VERSION${plain}"
    echo ""
else
    echo -e "${red}更新失败，请检查日志${plain}"
    journalctl -u nexcore-agent --no-pager -n 20
    exit 1
fi