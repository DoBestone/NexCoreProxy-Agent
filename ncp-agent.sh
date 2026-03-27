#!/bin/bash

# NexCoreProxy Agent SSH 管理脚本
# 用于 Master 通过 SSH 直接控制节点

INSTALL_DIR="/usr/local/x-ui"
DB_FILE="$INSTALL_DIR/db/x-ui.db"

# 显示帮助
show_help() {
    echo "NexCoreProxy Agent SSH 管理工具"
    echo ""
    echo "用法: ncp-agent <命令> [参数]"
    echo ""
    echo "命令:"
    echo "  status              查看服务状态"
    echo "  info                查看面板信息"
    echo "  restart             重启面板服务"
    echo "  restart-xray        重启 Xray"
    echo "  set-port <端口>      设置面板端口"
    echo "  set-user <用户名>    设置管理员用户名"
    echo "  set-pass <密码>      设置管理员密码"
    echo "  get-port            获取面板端口"
    echo "  get-user            获取管理员用户名"
    echo "  list-inbounds       列出所有入站"
    echo "  add-inbound <json>  添加入站 (JSON格式)"
    echo "  del-inbound <id>    删除入站"
    echo "  enable-inbound <id> 启用入站"
    echo "  disable-inbound <id> 禁用入站"
    echo "  update              更新到最新版本"
    echo "  version             查看版本"
    echo ""
    echo "示例:"
    echo "  ncp-agent status"
    echo "  ncp-agent set-port 54321"
    echo "  ncp-agent set-user admin"
    echo "  ncp-agent set-pass MyPassword123"
}

# 检查服务状态
cmd_status() {
    if systemctl is-active --quiet x-ui; then
        echo "状态: 运行中"
        echo "端口: $(get_port)"
        echo "用户: $(get_username)"
    else
        echo "状态: 未运行"
    fi
}

# 查看面板信息
cmd_info() {
    echo "=== NexCoreProxy Agent 信息 ==="
    echo ""
    echo "版本: $(cat $INSTALL_DIR/VERSION 2>/dev/null || echo '未知')"
    echo "服务状态: $(systemctl is-active x-ui 2>/dev/null || echo '未知')"
    echo "面板端口: $(get_port)"
    echo "管理员: $(get_username)"
    echo ""
    echo "安装目录: $INSTALL_DIR"
    echo "数据库: $DB_FILE"
}

# 获取端口
get_port() {
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "SELECT value FROM settings WHERE key='webPort';" 2>/dev/null || echo "54321"
    else
        echo "54321"
    fi
}

# 获取用户名
get_username() {
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "SELECT value FROM settings WHERE key='webUsername';" 2>/dev/null || echo "admin"
    else
        echo "admin"
    fi
}

# 重启服务
cmd_restart() {
    systemctl restart x-ui
    sleep 2
    if systemctl is-active --quiet x-ui; then
        echo "面板重启成功"
    else
        echo "面板重启失败"
        exit 1
    fi
}

# 重启 Xray
cmd_restart_xray() {
    # 通过 x-ui 命令重启 xray
    if command -v x-ui &> /dev/null; then
        x-ui restart
        echo "Xray 重启成功"
    else
        # 直接 kill xray 进程，让面板自动重启
        pkill -f xray-linux
        echo "Xray 已重启"
    fi
}

# 设置端口
cmd_set_port() {
    local port=$1
    if [[ -z "$port" ]]; then
        echo "错误: 请指定端口"
        exit 1
    fi
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE settings SET value='$port' WHERE key='webPort';"
        echo "端口已设置为: $port"
        echo "需要重启服务生效: ncp-agent restart"
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 设置用户名
cmd_set_user() {
    local user=$1
    if [[ -z "$user" ]]; then
        echo "错误: 请指定用户名"
        exit 1
    fi
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE settings SET value='$user' WHERE key='webUsername';"
        echo "用户名已设置为: $user"
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 设置密码
cmd_set_pass() {
    local pass=$1
    if [[ -z "$pass" ]]; then
        echo "错误: 请指定密码"
        exit 1
    fi
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE settings SET value='$pass' WHERE key='webPassword';"
        echo "密码已设置"
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 列出入站
cmd_list_inbounds() {
    if [[ -f "$DB_FILE" ]]; then
        echo "ID  | 端口  | 协议      | 启用 | 备注"
        echo "----|-------|-----------|------|------"
        sqlite3 -separator " | " "$DB_FILE" \
            "SELECT id, port, protocol, enable, remark FROM inbounds;" 2>/dev/null
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 删除入站
cmd_del_inbound() {
    local id=$1
    if [[ -z "$id" ]]; then
        echo "错误: 请指定入站ID"
        exit 1
    fi
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "DELETE FROM inbounds WHERE id=$id;"
        echo "入站 $id 已删除"
        echo "需要重启 Xray 生效"
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 启用入站
cmd_enable_inbound() {
    local id=$1
    if [[ -z "$id" ]]; then
        echo "错误: 请指定入站ID"
        exit 1
    fi
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE inbounds SET enable=1 WHERE id=$id;"
        echo "入站 $id 已启用"
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 禁用入站
cmd_disable_inbound() {
    local id=$1
    if [[ -z "$id" ]]; then
        echo "错误: 请指定入站ID"
        exit 1
    fi
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE inbounds SET enable=0 WHERE id=$id;"
        echo "入站 $id 已禁用"
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 更新
cmd_update() {
    bash <(curl -Ls https://raw.githubusercontent.com/DoBestone/NexCoreProxy-Agent/main/update.sh)
}

# 版本
cmd_version() {
    echo "NexCoreProxy Agent: $(cat $INSTALL_DIR/VERSION 2>/dev/null || echo '未知')"
    if [[ -f "$INSTALL_DIR/bin/xray-linux-amd64" ]]; then
        echo "Xray: $($INSTALL_DIR/bin/xray-linux-amd64 version 2>/dev/null | head -1 || echo '未知')"
    fi
}

# 主入口
case "$1" in
    status)
        cmd_status
        ;;
    info)
        cmd_info
        ;;
    restart)
        cmd_restart
        ;;
    restart-xray)
        cmd_restart_xray
        ;;
    set-port)
        cmd_set_port "$2"
        ;;
    set-user)
        cmd_set_user "$2"
        ;;
    set-pass)
        cmd_set_pass "$2"
        ;;
    get-port)
        get_port
        ;;
    get-user)
        get_username
        ;;
    list-inbounds)
        cmd_list_inbounds
        ;;
    del-inbound)
        cmd_del_inbound "$2"
        ;;
    enable-inbound)
        cmd_enable_inbound "$2"
        ;;
    disable-inbound)
        cmd_disable_inbound "$2"
        ;;
    update)
        cmd_update
        ;;
    version)
        cmd_version
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac