#!/bin/bash

# NexCoreProxy Agent SSH 管理脚本
# 用于 Master 通过 SSH 直接控制节点，不依赖面板 API

INSTALL_DIR="/usr/local/x-ui"
DB_FILE="$INSTALL_DIR/db/x-ui.db"

# 显示帮助
show_help() {
    echo "NexCoreProxy Agent SSH 管理工具"
    echo "直接操作数据库，无需面板认证"
    echo ""
    echo "用法: ncp-agent <命令> [参数]"
    echo ""
    echo "=== 服务管理 ==="
    echo "  status              查看服务状态"
    echo "  info                查看面板信息"
    echo "  start               启动面板"
    echo "  stop                停止面板"
    echo "  restart             重启面板"
    echo "  restart-xray        重启 Xray"
    echo ""
    echo "=== 面板设置 ==="
    echo "  get-port            获取面板端口"
    echo "  set-port <端口>     设置面板端口"
    echo "  get-user            获取管理员用户名"
    echo "  set-user <用户名>   设置管理员用户名"
    echo "  set-pass <密码>     设置管理员密码"
    echo "  gen-cert            生成自签名证书"
    echo ""
    echo "=== API Token ==="
    echo "  gen-token           生成 API Token"
    echo "  get-token           获取 API Token"
    echo "  reset-token         重置 API Token"
    echo ""
    echo "=== 入站管理 ==="
    echo "  list-inbounds       列出所有入站"
    echo "  get-inbound <id>    查看入站详情"
    echo "  del-inbound <id>    删除入站"
    echo "  enable-inbound <id> 启用入站"
    echo "  disable-inbound <id> 禁用入站"
    echo "  reset-traffic <id>  重置入站流量"
    echo ""
    echo "=== 客户端管理 ==="
    echo "  list-clients <inbound_id>  列出入站客户端"
    echo "  add-client <inbound_id> <email> <uuid>  添加客户端"
    echo "  del-client <inbound_id> <email>  删除客户端"
    echo "  enable-client <inbound_id> <email>  启用客户端"
    echo "  disable-client <inbound_id> <email>  禁用客户端"
    echo ""
    echo "=== 系统管理 ==="
    echo "  version             查看版本"
    echo "  update              更新到最新版本"
    echo "  backup              备份数据库"
    echo "  logs [n]            查看日志 (默认50行)"
    echo ""
    echo "示例:"
    echo "  ncp-agent status"
    echo "  ncp-agent set-port 54321"
    echo "  ncp-agent list-inbounds"
    echo "  ncp-agent list-clients 1"
    echo "  ncp-agent gen-token"
}

# 检查 sqlite3
check_sqlite() {
    if ! command -v sqlite3 &> /dev/null; then
        apt-get update && apt-get install -y sqlite3 2>/dev/null || \
        yum install -y sqlite 2>/dev/null || \
        echo "请安装 sqlite3"
        exit 1
    fi
}

# 检查服务状态
cmd_status() {
    if systemctl is-active --quiet x-ui; then
        echo "状态: 运行中 ✓"
        echo "端口: $(get_port)"
        echo "用户: $(get_username)"
        # Xray 进程检查
        if pgrep -f "xray-linux" > /dev/null; then
            echo "Xray: 运行中 ✓"
        else
            echo "Xray: 未运行 ✗"
        fi
    else
        echo "状态: 未运行 ✗"
    fi
}

# 查看面板信息
cmd_info() {
    echo "╔════════════════════════════════════╗"
    echo "║     NexCoreProxy Agent 信息        ║"
    echo "╚════════════════════════════════════╝"
    echo ""
    echo "版本:     $(cat $INSTALL_DIR/VERSION 2>/dev/null || echo '未知')"
    echo "服务:     $(systemctl is-active x-ui 2>/dev/null || echo '未知')"
    echo "端口:     $(get_port)"
    echo "用户:     $(get_username)"
    echo ""
    echo "安装目录: $INSTALL_DIR"
    echo "数据库:   $DB_FILE"
    echo ""
    # 系统资源
    if command -v free &> /dev/null; then
        MEM=$(free -m | awk '/Mem:/ {printf "%.0fMB / %.0fMB", $3, $2}')
        echo "内存:     $MEM"
    fi
    if command -v df &> /dev/null; then
        DISK=$(df -h $INSTALL_DIR | awk 'NR==2 {print $3 " / " $2}')
        echo "磁盘:     $DISK"
    fi
}

# 启动服务
cmd_start() {
    systemctl start x-ui
    sleep 2
    cmd_status
}

# 停止服务
cmd_stop() {
    systemctl stop x-ui
    echo "面板已停止"
}

# 重启服务
cmd_restart() {
    systemctl restart x-ui
    sleep 2
    cmd_status
}

# 重启 Xray
cmd_restart_xray() {
    # 使用 x-ui 命令或直接 kill
    if command -v x-ui &> /dev/null; then
        x-ui restart
    else
        pkill -f xray-linux
        sleep 2
    fi
    echo "Xray 已重启"
}

# 获取端口
get_port() {
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "SELECT value FROM settings WHERE key='webPort';" 2>/dev/null || echo "54321"
    else
        echo "54321"
    fi
}

# 获取用户名
get_username() {
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "SELECT value FROM settings WHERE key='webUsername';" 2>/dev/null || echo "admin"
    else
        echo "admin"
    fi
}

# 设置端口
cmd_set_port() {
    local port=$1
    if [[ -z "$port" ]]; then
        echo "错误: 请指定端口"
        exit 1
    fi
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE settings SET value='$port' WHERE key='webPort';"
        echo "✓ 端口已设置为: $port"
        echo "  执行 ncp-agent restart 使配置生效"
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
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE settings SET value='$user' WHERE key='webUsername';"
        echo "✓ 用户名已设置为: $user"
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
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE settings SET value='$pass' WHERE key='webPassword';"
        echo "✓ 密码已设置"
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 列出入站
cmd_list_inbounds() {
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        echo ""
        echo "ID | 端口  | 协议       | 启用 | 上传      | 下载      | 备注"
        echo "---|-------|------------|------|-----------|-----------|------"
        sqlite3 -header -column "$DB_FILE" \
            "SELECT id, port, protocol, 
                    CASE WHEN enable=1 THEN '✓' ELSE '✗' END as enable,
                    printf('%.2fGB', up/1073741824.0) as up,
                    printf('%.2fGB', down/1073741824.0) as down,
                    COALESCE(remark,'') as remark
             FROM inbounds;" 2>/dev/null
        echo ""
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 查看入站详情
cmd_get_inbound() {
    local id=$1
    if [[ -z "$id" ]]; then
        echo "错误: 请指定入站ID"
        exit 1
    fi
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "SELECT * FROM inbounds WHERE id=$id;" 2>/dev/null
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
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "DELETE FROM inbounds WHERE id=$id;"
        echo "✓ 入站 $id 已删除"
        echo "  执行 ncp-agent restart-xray 使配置生效"
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
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE inbounds SET enable=1 WHERE id=$id;"
        echo "✓ 入站 $id 已启用"
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
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE inbounds SET enable=0 WHERE id=$id;"
        echo "✓ 入站 $id 已禁用"
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 重置流量
cmd_reset_traffic() {
    local id=$1
    if [[ -z "$id" ]]; then
        echo "错误: 请指定入站ID"
        exit 1
    fi
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" "UPDATE inbounds SET up=0, down=0 WHERE id=$id;"
        echo "✓ 入站 $id 流量已重置"
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 列出客户端
cmd_list_clients() {
    local inbound_id=$1
    if [[ -z "$inbound_id" ]]; then
        echo "错误: 请指定入站ID"
        exit 1
    fi
    check_sqlite
    if [[ -f "$DB_FILE" ]]; then
        echo ""
        echo "入站 $inbound_id 的客户端:"
        echo ""
        # 获取客户端配置
        local config=$(sqlite3 "$DB_FILE" "SELECT settings FROM inbounds WHERE id=$inbound_id;" 2>/dev/null)
        if command -v jq &> /dev/null; then
            echo "$config" | jq -r '.clients[] | "Email: \(.email) | UUID: \(.id) | 启用: \(.enable)"' 2>/dev/null
        else
            echo "$config"
        fi
        echo ""
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 生成证书
cmd_gen_cert() {
    local domain=${1:-"localhost"}
    mkdir -p $INSTALL_DIR/bin
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout $INSTALL_DIR/bin/private.key \
        -out $INSTALL_DIR/bin/cert.pem \
        -subj "/CN=$domain" 2>/dev/null
    echo "✓ 证书已生成:"
    echo "  $INSTALL_DIR/bin/cert.pem"
    echo "  $INSTALL_DIR/bin/private.key"
}

# 备份数据库
cmd_backup() {
    local backup_file="/tmp/x-ui-backup-$(date +%Y%m%d_%H%M%S).db"
    if [[ -f "$DB_FILE" ]]; then
        cp "$DB_FILE" "$backup_file"
        echo "✓ 数据库已备份到: $backup_file"
    else
        echo "错误: 数据库不存在"
        exit 1
    fi
}

# 查看日志
cmd_logs() {
    local lines=${1:-50}
    journalctl -u x-ui --no-pager -n "$lines"
}

# 更新
cmd_update() {
    bash <(curl -Ls https://raw.githubusercontent.com/DoBestone/NexCoreProxy-Agent/main/update.sh)
}

# 版本
cmd_version() {
    echo "NexCoreProxy Agent: $(cat $INSTALL_DIR/VERSION 2>/dev/null || echo '未知')"
    if [[ -f "$INSTALL_DIR/bin/xray-linux-amd64" ]]; then
        XRAY_VER=$($INSTALL_DIR/bin/xray-linux-amd64 version 2>/dev/null | head -1 || echo 'Xray: 未知')
        echo "$XRAY_VER"
    fi
}

# 生成 API Token
cmd_gen_token() {
    local token=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    echo "$token" > $INSTALL_DIR/API_TOKEN
    chmod 600 $INSTALL_DIR/API_TOKEN
    echo "✓ API Token 已生成: $token"
    echo "  存储位置: $INSTALL_DIR/API_TOKEN"
}

# 获取 API Token
cmd_get_token() {
    if [[ -f "$INSTALL_DIR/API_TOKEN" ]]; then
        cat $INSTALL_DIR/API_TOKEN
    else
        echo "未生成 API Token，请执行 ncp-agent gen-token"
    fi
}

# 重置 API Token
cmd_reset_token() {
    cmd_gen_token
}

# 主入口
case "$1" in
    status)       cmd_status ;;
    info)         cmd_info ;;
    start)        cmd_start ;;
    stop)         cmd_stop ;;
    restart)      cmd_restart ;;
    restart-xray) cmd_restart_xray ;;
    get-port)     get_port ;;
    set-port)     cmd_set_port "$2" ;;
    get-user)     get_username ;;
    set-user)     cmd_set_user "$2" ;;
    set-pass)     cmd_set_pass "$2" ;;
    gen-cert)     cmd_gen_cert "$2" ;;
    gen-token)    cmd_gen_token ;;
    get-token)    cmd_get_token ;;
    reset-token)  cmd_reset_token ;;
    list-inbounds)  cmd_list_inbounds ;;
    get-inbound)  cmd_get_inbound "$2" ;;
    del-inbound)  cmd_del_inbound "$2" ;;
    enable-inbound) cmd_enable_inbound "$2" ;;
    disable-inbound) cmd_disable_inbound "$2" ;;
    reset-traffic) cmd_reset_traffic "$2" ;;
    list-clients) cmd_list_clients "$2" ;;
    backup)       cmd_backup ;;
    logs)         cmd_logs "$2" ;;
    version)      cmd_version ;;
    update)       cmd_update ;;
    help|--help|-h) show_help ;;
    *)            show_help; exit 1 ;;
esac