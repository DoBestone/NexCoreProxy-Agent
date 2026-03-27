# NexCoreProxy Agent

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/release/DoBestone/NexCoreProxy-Agent.svg)](https://github.com/DoBestone/NexCoreProxy-Agent/releases)

NexCoreProxy 代理主机节点服务端，基于 [3X-UI](https://github.com/MHSanaei/3x-ui)。

## 双模式控制

Agent 支持两种控制方式：

### 1. API 模式（交互式）
通过 3X-UI 面板的 REST API 控制，需要登录认证。

```
Master → HTTP/API → Agent 面板 → 操作
```

**适用场景：** 需要复杂操作、查看 UI 界面

### 2. SSH 指令模式（命令行）
通过 `ncp-agent` 命令行工具直接操作，无需面板认证。

```
Master → SSH → ncp-agent → 直接操作数据库
```

**适用场景：** 自动化脚本、批量管理、面板无法访问时

---

## 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/DoBestone/NexCoreProxy-Agent/main/install.sh) -p 54321 -u admin -pass YourPassword
```

### 安装参数

| 参数 | 说明 | 必填 |
|------|------|------|
| `-p, --port` | 面板端口 | ✅ |
| `-u, --user` | 管理员用户名 | ✅ |
| `-pass, --password` | 管理员密码 | ✅ |

---

## ncp-agent 指令参考

安装后可通过 `ncp-agent` 命令管理节点：

### 服务管理

```bash
ncp-agent status          # 查看状态
ncp-agent info            # 查看详细信息
ncp-agent start           # 启动面板
ncp-agent stop            # 停止面板
ncp-agent restart         # 重启面板
ncp-agent restart-xray    # 重启 Xray
```

### 面板设置

```bash
ncp-agent get-port        # 获取端口
ncp-agent set-port 54321  # 设置端口
ncp-agent get-user        # 获取用户名
ncp-agent set-user admin  # 设置用户名
ncp-agent set-pass xxx    # 设置密码
ncp-agent gen-cert        # 生成证书
```

### 入站管理

```bash
ncp-agent list-inbounds     # 列出入站
ncp-agent get-inbound 1     # 查看详情
ncp-agent del-inbound 1     # 删除入站
ncp-agent enable-inbound 1  # 启用入站
ncp-agent disable-inbound 1 # 禁用入站
ncp-agent reset-traffic 1   # 重置流量
```

### 客户端管理

```bash
ncp-agent list-clients 1    # 列出客户端
```

### 系统管理

```bash
ncp-agent version         # 查看版本
ncp-agent update          # 更新
ncp-agent backup          # 备份数据库
ncp-agent logs            # 查看日志
```

---

## Master 端集成

Master 主控面板自动选择最优控制方式：

| 操作 | 方式 | 说明 |
|------|------|------|
| 安装 Agent | SSH | 一键安装 |
| 重置密码 | SSH + ncp-agent | 无需知道旧密码 |
| 重启服务 | SSH + ncp-agent | 直接操作 |
| 同步状态 | API | 获取详细信息 |
| 管理入站 | API | 复杂操作 |
| 检测更新 | SSH | 查询版本 |

---

## 文件说明

```
NexCoreProxy-Agent/
├── install.sh        # 一键安装脚本
├── update.sh         # 更新脚本
├── ncp-agent.sh      # Shell 版管理工具
├── ncp-agent/        # Go 版管理工具源码
│   ├── main.go
│   └── go.mod
├── bin/              # 预编译二进制
│   ├── ncp-agent-linux-amd64
│   └── ncp-agent-linux-arm64
└── README.md
```

---

## API 端点

3X-UI 完整 API 文档: https://documenter.getpostman.com/view/5146551/2sB3QCTuB6

主要端点：

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /login | 登录 |
| GET | /panel/api/inbounds | 获取入站列表 |
| POST | /panel/api/inbounds | 添加入站 |
| POST | /panel/api/server/status | 服务器状态 |

---

## 技术栈

- 基于 [3X-UI](https://github.com/MHSanaei/3x-ui) v2.8.11+
- 支持协议: VMess, VLESS, Trojan, Shadowsocks, WireGuard
- 支持传输: TCP, WebSocket, HTTP/2, gRPC, QUIC

## License

MIT