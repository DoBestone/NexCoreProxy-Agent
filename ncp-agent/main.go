package main

import (
	"database/sql"
	"fmt"
	"os"
	"os/exec"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

const (
	INSTALL_DIR = "/usr/local/x-ui"
	DB_FILE     = INSTALL_DIR + "/db/x-ui.db"
	VERSION_URL = "https://raw.githubusercontent.com/DoBestone/NexCoreProxy-Agent/main/VERSION"
)

var db *sql.DB

func main() {
	if len(os.Args) < 2 {
		showHelp()
		os.Exit(1)
	}

	// 初始化数据库连接
	initDB()
	defer closeDB()

	cmd := os.Args[1]
	args := os.Args[2:]

	switch cmd {
	case "status":
		cmdStatus()
	case "info":
		cmdInfo()
	case "restart":
		cmdRestart()
	case "restart-xray":
		cmdRestartXray()
	case "set-port":
		if len(args) < 1 {
			fmt.Println("错误: 请指定端口")
			os.Exit(1)
		}
		cmdSetPort(args[0])
	case "set-user":
		if len(args) < 1 {
			fmt.Println("错误: 请指定用户名")
			os.Exit(1)
		}
		cmdSetUser(args[0])
	case "set-pass":
		if len(args) < 1 {
			fmt.Println("错误: 请指定密码")
			os.Exit(1)
		}
		cmdSetPass(args[0])
	case "get-port":
		fmt.Println(getPort())
	case "get-user":
		fmt.Println(getUsername())
	case "list-inbounds":
		cmdListInbounds()
	case "del-inbound":
		if len(args) < 1 {
			fmt.Println("错误: 请指定入站ID")
			os.Exit(1)
		}
		cmdDelInbound(args[0])
	case "enable-inbound":
		if len(args) < 1 {
			fmt.Println("错误: 请指定入站ID")
			os.Exit(1)
		}
		cmdEnableInbound(args[0], true)
	case "disable-inbound":
		if len(args) < 1 {
			fmt.Println("错误: 请指定入站ID")
			os.Exit(1)
		}
		cmdEnableInbound(args[0], false)
	case "version":
		cmdVersion()
	case "update":
		cmdUpdate()
	default:
		showHelp()
		os.Exit(1)
	}
}

func initDB() {
	var err error
	db, err = sql.Open("sqlite3", DB_FILE)
	if err != nil {
		fmt.Printf("数据库连接失败: %v\n", err)
	}
}

func closeDB() {
	if db != nil {
		db.Close()
	}
}

func showHelp() {
	fmt.Println("NexCoreProxy Agent SSH 管理工具")
	fmt.Println("")
	fmt.Println("用法: ncp-agent <命令> [参数]")
	fmt.Println("")
	fmt.Println("命令:")
	fmt.Println("  status              查看服务状态")
	fmt.Println("  info                查看面板信息")
	fmt.Println("  restart             重启面板服务")
	fmt.Println("  restart-xray        重启 Xray")
	fmt.Println("  set-port <端口>      设置面板端口")
	fmt.Println("  set-user <用户名>    设置管理员用户名")
	fmt.Println("  set-pass <密码>      设置管理员密码")
	fmt.Println("  get-port            获取面板端口")
	fmt.Println("  get-user            获取管理员用户名")
	fmt.Println("  list-inbounds       列出所有入站")
	fmt.Println("  del-inbound <id>    删除入站")
	fmt.Println("  enable-inbound <id> 启用入站")
	fmt.Println("  disable-inbound <id> 禁用入站")
	fmt.Println("  update              更新到最新版本")
	fmt.Println("  version             查看版本")
}

func cmdStatus() {
	if isServiceActive() {
		fmt.Println("状态: 运行中")
		fmt.Printf("端口: %s\n", getPort())
		fmt.Printf("用户: %s\n", getUsername())
	} else {
		fmt.Println("状态: 未运行")
	}
}

func cmdInfo() {
	fmt.Println("=== NexCoreProxy Agent 信息 ===")
	fmt.Println()
	version := getVersion()
	fmt.Printf("版本: %s\n", version)
	status := "未运行"
	if isServiceActive() {
		status = "运行中"
	}
	fmt.Printf("服务状态: %s\n", status)
	fmt.Printf("面板端口: %s\n", getPort())
	fmt.Printf("管理员: %s\n", getUsername())
	fmt.Println()
	fmt.Printf("安装目录: %s\n", INSTALL_DIR)
	fmt.Printf("数据库: %s\n", DB_FILE)
}

func cmdRestart() {
	exec.Command("systemctl", "restart", "x-ui").Run()
	fmt.Println("面板重启成功")
}

func cmdRestartXray() {
	exec.Command("pkill", "-f", "xray-linux").Run()
	fmt.Println("Xray 已重启")
}

func cmdSetPort(port string) {
	if db == nil {
		fmt.Println("错误: 数据库未连接")
		return
	}
	_, err := db.Exec("UPDATE settings SET value=? WHERE key='webPort'", port)
	if err != nil {
		fmt.Printf("设置失败: %v\n", err)
		return
	}
	fmt.Printf("端口已设置为: %s\n", port)
	fmt.Println("需要重启服务生效: ncp-agent restart")
}

func cmdSetUser(user string) {
	if db == nil {
		fmt.Println("错误: 数据库未连接")
		return
	}
	_, err := db.Exec("UPDATE settings SET value=? WHERE key='webUsername'", user)
	if err != nil {
		fmt.Printf("设置失败: %v\n", err)
		return
	}
	fmt.Printf("用户名已设置为: %s\n", user)
}

func cmdSetPass(pass string) {
	if db == nil {
		fmt.Println("错误: 数据库未连接")
		return
	}
	_, err := db.Exec("UPDATE settings SET value=? WHERE key='webPassword'", pass)
	if err != nil {
		fmt.Printf("设置失败: %v\n", err)
		return
	}
	fmt.Println("密码已设置")
}

func cmdListInbounds() {
	if db == nil {
		fmt.Println("错误: 数据库未连接")
		return
	}
	fmt.Println("ID  | 端口  | 协议      | 启用 | 备注")
	fmt.Println("----|-------|-----------|------|------")

	rows, err := db.Query("SELECT id, port, protocol, enable, remark FROM inbounds")
	if err != nil {
		return
	}
	defer rows.Close()

	for rows.Next() {
		var id, port int
		var protocol, remark string
		var enable bool
		rows.Scan(&id, &port, &protocol, &enable, &remark)
		enableStr := "是"
		if !enable {
			enableStr = "否"
		}
		fmt.Printf("%-3d | %-5d | %-9s | %-4s | %s\n", id, port, protocol, enableStr, remark)
	}
}

func cmdDelInbound(id string) {
	if db == nil {
		fmt.Println("错误: 数据库未连接")
		return
	}
	_, err := db.Exec("DELETE FROM inbounds WHERE id=?", id)
	if err != nil {
		fmt.Printf("删除失败: %v\n", err)
		return
	}
	fmt.Printf("入站 %s 已删除\n", id)
}

func cmdEnableInbound(id string, enable bool) {
	if db == nil {
		fmt.Println("错误: 数据库未连接")
		return
	}
	enableInt := 1
	if !enable {
		enableInt = 0
	}
	_, err := db.Exec("UPDATE inbounds SET enable=? WHERE id=?", enableInt, id)
	if err != nil {
		fmt.Printf("操作失败: %v\n", err)
		return
	}
	action := "启用"
	if !enable {
		action = "禁用"
	}
	fmt.Printf("入站 %s 已%s\n", id, action)
}

func cmdVersion() {
	fmt.Printf("NexCoreProxy Agent: %s\n", getVersion())
}

func cmdGenToken() {
	token := generateRandomString(32)
	err := os.WriteFile(INSTALL_DIR+"/API_TOKEN", []byte(token), 0600)
	if err != nil {
		fmt.Printf("生成失败: %v\n", err)
		return
	}
	fmt.Printf("✓ API Token 已生成: %s\n", token)
	fmt.Printf("  存储位置: %s/API_TOKEN\n", INSTALL_DIR)
}

func cmdGetToken() {
	data, err := os.ReadFile(INSTALL_DIR + "/API_TOKEN")
	if err != nil {
		fmt.Println("未生成 API Token，请执行 ncp-agent gen-token")
		return
	}
	fmt.Println(strings.TrimSpace(string(data)))
}

func cmdResetToken() {
	cmdGenToken()
}

func generateRandomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	return string(b)
}

func cmdUpdate() {
	cmd := exec.Command("bash", "-c", "bash <(curl -Ls https://raw.githubusercontent.com/DoBestone/NexCoreProxy-Agent/main/update.sh)")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
}

func getPort() string {
	if db == nil {
		return "54321"
	}
	var port string
	err := db.QueryRow("SELECT value FROM settings WHERE key='webPort'").Scan(&port)
	if err != nil {
		return "54321"
	}
	return port
}

func getUsername() string {
	if db == nil {
		return "admin"
	}
	var user string
	err := db.QueryRow("SELECT value FROM settings WHERE key='webUsername'").Scan(&user)
	if err != nil {
		return "admin"
	}
	return user
}

func getVersion() string {
	data, err := os.ReadFile(INSTALL_DIR + "/VERSION")
	if err != nil {
		return "未知"
	}
	return strings.TrimSpace(string(data))
}

func isServiceActive() bool {
	out, _ := exec.Command("systemctl", "is-active", "x-ui").Output()
	return strings.TrimSpace(string(out)) == "active"
}