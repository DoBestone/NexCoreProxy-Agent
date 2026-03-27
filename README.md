# NexCoreProxy Agent

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/release/DoBestone/NexCoreProxy-Agent.svg)](https://github.com/DoBestone/NexCoreProxy-Agent/releases)

NexCoreProxy 代理主机节点服务端，基于 [3X-UI](https://github.com/MHSanaei/3x-ui)。

## 架构

```
┌─────────────────┐
│   Master 主控   │
│  (管理面板)     │
└────────┬────────┘
         │ SSH / API
         ▼
┌─────────────────┐
│   Agent 节点    │
│  3X-UI + ncp-agent │
└─────────────────┘
```

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

## ncp-agent 管理工具

安装后可通过 `ncp-agent` 命令管理节点：

```bash
ncp-agent status          # 查看状态
ncp-agent info            # 查看面板信息
ncp-agent restart         # 重启面板
ncp-agent restart-xray    # 重启 Xray
ncp-agent set-port 54321  # 设置端口
ncp-agent set-user admin  # 设置用户名
ncp-agent set-pass xxx     # 设置密码
ncp-agent list-inbounds   # 列出入站
ncp-agent del-inbound 1   # 删除入站
ncp-agent version         # 查看版本
ncp-agent update          # 更新
```

## Master 端控制

通过 Master 主控面板可以：

- ✅ SSH 安装 Agent
- ✅ 检测版本更新
- ✅ 在线更新 Agent
- ✅ 重置面板密码
- ✅ 重启 Xray 服务
- ✅ 管理入站配置

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
│   ├── linux-amd64/
│   └── linux-arm64/
└── README.md
```

## API 端点

3X-UI 完整 API 文档: https://documenter.getpostman.com/view/5146551/2sB3QCTuB6

主要端点：
- `POST /login` - 登录
- `POST /panel/api/inbounds` - 入站管理
- `POST /panel/api/server` - 服务器状态

## 技术栈

- 基于 [3X-UI](https://github.com/MHSanaei/3x-ui) v2.8.11+
- 支持协议: VMess, VLESS, Trojan, Shadowsocks, WireGuard
- 支持传输: TCP, WebSocket, HTTP/2, gRPC, QUIC

## License

MIT