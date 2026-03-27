package main

import (
	"crypto/subtle"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

const (
	DEFAULT_PORT   = 54322
	INSTALL_DIR    = "/usr/local/x-ui"
	DB_FILE        = INSTALL_DIR + "/db/x-ui.db"
	TOKEN_FILE     = INSTALL_DIR + "/API_TOKEN"
	VERSION_FILE   = INSTALL_DIR + "/VERSION"
)

var db *sql.DB

func main() {
	// 检查 Token 文件
	token := getToken()
	if token == "" {
		log.Fatal("API Token 未设置，请先执行: ncp-agent gen-token")
	}

	// 初始化数据库
	var err error
	db, err = sql.Open("sqlite3", DB_FILE)
	if err != nil {
		log.Fatalf("数据库连接失败: %v", err)
	}
	defer db.Close()

	// 获取监听端口
	port := getAPIPort()

	// 设置路由
	http.HandleFunc("/api/status", authMiddleware(handleStatus))
	http.HandleFunc("/api/info", authMiddleware(handleInfo))
	http.HandleFunc("/api/inbounds", authMiddleware(handleInbounds))
	http.HandleFunc("/api/inbound/", authMiddleware(handleInbound))
	http.HandleFunc("/api/clients/", authMiddleware(handleClients))
	http.HandleFunc("/api/restart", authMiddleware(handleRestart))
	http.HandleFunc("/api/restart-xray", authMiddleware(handleRestartXray))
	http.HandleFunc("/api/settings", authMiddleware(handleSettings))

	log.Printf("NexCoreProxy Agent API 启动，端口: %d", port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", port), nil))
}

// 认证中间件
func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := getToken()
		if token == "" {
			http.Error(w, `{"success":false,"msg":"Token not configured"}`, http.StatusInternalServerError)
			return
		}

		// 从 Header 或 Query 获取 Token
		reqToken := r.Header.Get("X-API-Token")
		if reqToken == "" {
			reqToken = r.URL.Query().Get("token")
		}

		// 安全比较
		if subtle.ConstantTimeCompare([]byte(token), []byte(reqToken)) != 1 {
			http.Error(w, `{"success":false,"msg":"Invalid token"}`, http.StatusUnauthorized)
			return
		}

		next(w, r)
	}
}

// 响应 JSON
func jsonResp(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

// 获取 Token
func getToken() string {
	data, err := os.ReadFile(TOKEN_FILE)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// 获取 API 端口
func getAPIPort() int {
	// 从数据库读取或使用默认端口
	if db != nil {
		var port int
		err := db.QueryRow("SELECT value FROM settings WHERE key='apiPort'").Scan(&port)
		if err == nil && port > 0 {
			return port
		}
	}
	return DEFAULT_PORT
}

// ========== API Handlers ==========

// GET /api/status - 获取状态
func handleStatus(w http.ResponseWriter, r *http.Request) {
	status := map[string]interface{}{
		"version":       getVersion(),
		"service_status": getServiceStatus(),
		"xray_status":   getXrayStatus(),
		"inbound_count": getInboundCount(),
	}

	// 系统资源
	if cpu, err := getCPU(); err == nil {
		status["cpu"] = cpu
	}
	if mem, err := getMemory(); err == nil {
		status["memory"] = mem
	}
	if disk, err := getDisk(); err == nil {
		status["disk"] = disk
	}
	if uptime, err := getUptime(); err == nil {
		status["uptime"] = uptime
	}

	jsonResp(w, map[string]interface{}{"success": true, "obj": status})
}

// GET /api/info - 获取详细信息
func handleInfo(w http.ResponseWriter, r *http.Request) {
	info := map[string]interface{}{
		"version":      getVersion(),
		"panel_port":   getPanelPort(),
		"admin_user":   getAdminUser(),
		"api_port":     getAPIPort(),
		"service":      getServiceStatus(),
		"xray":         getXrayStatus(),
		"xray_version": getXrayVersion(),
		"inbounds":     getInboundCount(),
		"total_up":     getTotalTraffic("up"),
		"total_down":   getTotalTraffic("down"),
	}

	jsonResp(w, map[string]interface{}{"success": true, "obj": info})
}

// GET /api/inbounds - 列出入站
func handleInbounds(w http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		inbounds := []map[string]interface{}{}
		rows, err := db.Query(`SELECT id, port, protocol, enable, up, down, remark FROM inbounds`)
		if err != nil {
			jsonResp(w, map[string]interface{}{"success": false, "msg": err.Error()})
			return
		}
		defer rows.Close()

		for rows.Next() {
			var id, port int
			var protocol, remark string
			var enable bool
			var up, down int64
			rows.Scan(&id, &port, &protocol, &enable, &up, &down, &remark)
			inbounds = append(inbounds, map[string]interface{}{
				"id":       id,
				"port":     port,
				"protocol": protocol,
				"enable":   enable,
				"up":       up,
				"down":     down,
				"remark":   remark,
			})
		}

		jsonResp(w, map[string]interface{}{"success": true, "obj": inbounds})
	}
}

// /api/inbound/{id} - 入站操作
func handleInbound(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/api/inbound/")
	id, err := strconv.Atoi(path)
	if err != nil {
		jsonResp(w, map[string]interface{}{"success": false, "msg": "Invalid ID"})
		return
	}

	switch r.Method {
	case "GET":
		// 获取详情
		var port int
		var protocol, settings, remark string
		var enable bool
		err := db.QueryRow(`SELECT port, protocol, enable, settings, remark FROM inbounds WHERE id=?`, id).
			Scan(&port, &protocol, &enable, &settings, &remark)
		if err != nil {
			jsonResp(w, map[string]interface{}{"success": false, "msg": "Not found"})
			return
		}
		jsonResp(w, map[string]interface{}{
			"success": true,
			"obj": map[string]interface{}{
				"id":       id,
				"port":     port,
				"protocol": protocol,
				"enable":   enable,
				"settings": settings,
				"remark":   remark,
			},
		})

	case "DELETE":
		// 删除
		_, err := db.Exec("DELETE FROM inbounds WHERE id=?", id)
		if err != nil {
			jsonResp(w, map[string]interface{}{"success": false, "msg": err.Error()})
			return
		}
		jsonResp(w, map[string]interface{}{"success": true, "msg": "Deleted"})

	case "PUT":
		// 更新 (启用/禁用)
		var req struct {
			Enable *bool `json:"enable"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		if req.Enable != nil {
			enableInt := 0
			if *req.Enable {
				enableInt = 1
			}
			_, err := db.Exec("UPDATE inbounds SET enable=? WHERE id=?", enableInt, id)
			if err != nil {
				jsonResp(w, map[string]interface{}{"success": false, "msg": err.Error()})
				return
			}
		}
		jsonResp(w, map[string]interface{}{"success": true})

	default:
		http.Error(w, "Method not allowed", 405)
	}
}

// /api/clients/{inbound_id} - 客户端列表
func handleClients(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/api/clients/")
	inboundId, err := strconv.Atoi(path)
	if err != nil {
		jsonResp(w, map[string]interface{}{"success": false, "msg": "Invalid ID"})
		return
	}

	// 获取入站设置
	var settings string
	err = db.QueryRow("SELECT settings FROM inbounds WHERE id=?", inboundId).Scan(&settings)
	if err != nil {
		jsonResp(w, map[string]interface{}{"success": false, "msg": "Inbound not found"})
		return
	}

	// 解析客户端
	var config struct {
		Clients []map[string]interface{} `json:"clients"`
	}
	json.Unmarshal([]byte(settings), &config)

	jsonResp(w, map[string]interface{}{
		"success": true,
		"obj":     config.Clients,
	})
}

// POST /api/restart - 重启面板
func handleRestart(w http.ResponseWriter, r *http.Request) {
	// 异步重启
	go func() {
		// 通过 systemd 重启
		execCommand("systemctl", "restart", "x-ui")
	}()
	jsonResp(w, map[string]interface{}{"success": true, "msg": "Restarting"})
}

// POST /api/restart-xray - 重启 Xray
func handleRestartXray(w http.ResponseWriter, r *http.Request) {
	// Kill xray 进程，面板会自动重启
	execCommand("pkill", "-f", "xray-linux")
	jsonResp(w, map[string]interface{}{"success": true, "msg": "Xray restarted"})
}

// GET/PUT /api/settings - 设置
func handleSettings(w http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		settings := map[string]interface{}{
			"panel_port": getPanelPort(),
			"admin_user": getAdminUser(),
		}
		jsonResp(w, map[string]interface{}{"success": true, "obj": settings})
		return
	}

	// PUT - 更新设置
	var req map[string]string
	json.NewDecoder(r.Body).Decode(&req)

	for key, value := range req {
		switch key {
		case "panel_port":
			db.Exec("UPDATE settings SET value=? WHERE key='webPort'", value)
		case "admin_user":
			db.Exec("UPDATE settings SET value=? WHERE key='webUsername'", value)
		case "admin_pass":
			db.Exec("UPDATE settings SET value=? WHERE key='webPassword'", value)
		}
	}
	jsonResp(w, map[string]interface{}{"success": true})
}

// ========== 辅助函数 ==========

func getVersion() string {
	data, _ := os.ReadFile(VERSION_FILE)
	return strings.TrimSpace(string(data))
}

func getServiceStatus() string {
	out, _ := execCommand("systemctl", "is-active", "x-ui")
	return strings.TrimSpace(out)
}

func getXrayStatus() string {
	out, _ := execCommand("pgrep", "-f", "xray-linux")
	if strings.TrimSpace(out) != "" {
		return "running"
	}
	return "stopped"
}

func getXrayVersion() string {
	out, _ := execCommand("/usr/local/x-ui/bin/xray-linux-amd64", "version")
	lines := strings.Split(out, "\n")
	if len(lines) > 0 {
		parts := strings.Fields(lines[0])
		if len(parts) > 1 {
			return parts[1]
		}
	}
	return ""
}

func getInboundCount() int {
	var count int
	db.QueryRow("SELECT COUNT(*) FROM inbounds").Scan(&count)
	return count
}

func getTotalTraffic(field string) int64 {
	var total int64
	db.QueryRow(fmt.Sprintf("SELECT SUM(%s) FROM inbounds", field)).Scan(&total)
	return total
}

func getPanelPort() string {
	var port string
	db.QueryRow("SELECT value FROM settings WHERE key='webPort'").Scan(&port)
	if port == "" {
		return "54321"
	}
	return port
}

func getAdminUser() string {
	var user string
	db.QueryRow("SELECT value FROM settings WHERE key='webUsername'").Scan(&user)
	if user == "" {
		return "admin"
	}
	return user
}

func getCPU() (float64, error) {
	out, err := execCommand("bash", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
	if err != nil {
		return 0, err
	}
	return strconv.ParseFloat(strings.TrimSpace(out), 64)
}

func getMemory() (float64, error) {
	out, err := execCommand("bash", "-c", "free | grep Mem | awk '{printf \"%.1f\", $3/$2 * 100}'")
	if err != nil {
		return 0, err
	}
	return strconv.ParseFloat(strings.TrimSpace(out), 64)
}

func getDisk() (float64, error) {
	out, err := execCommand("bash", "-c", "df -h / | tail -1 | awk '{print $5}' | cut -d'%' -f1")
	if err != nil {
		return 0, err
	}
	return strconv.ParseFloat(strings.TrimSpace(out), 64)
}

func getUptime() (int64, error) {
	out, err := execCommand("bash", "-c", "cat /proc/uptime | awk '{print int($1)}'")
	if err != nil {
		return 0, err
	}
	return strconv.ParseInt(strings.TrimSpace(out), 10, 64)
}

func execCommand(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}