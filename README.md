# NexCoreProxy Agent

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

NexCoreProxy 代理主机节点服务端，基于 [3X-UI](https://github.com/MHSanaei/3x-ui)。

## 功能特点

- 🚀 一键安装部署
- 🔐 支持自定义端口、用户名、密码
- 📦 自动下载最新版本 3X-UI
- 🔄 支持在线更新
- 🌐 支持 VMess, VLESS, Trojan, Shadowsocks 等协议

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

### 安装示例

```bash
# 基本安装
bash <(curl -Ls https://raw.githubusercontent.com/DoBestone/NexCoreProxy-Agent/main/install.sh) -p 54321 -u admin -pass MyPassword123
```

## 安装后信息

安装完成后会显示：
- 面板地址
- 用户名和密码
- 3X-UI 版本

## 主控面板配置

在 NexCoreProxy Master 主控面板添加节点时填写：
- IP: 服务器 IP
- 端口: 安装时设置的端口
- 用户名: 安装时设置的用户名
- 密码: 安装时设置的密码
- SSH 端口: 22 (默认)
- SSH 用户: root
- SSH 密码: 服务器 root 密码

## 在线更新

已安装的节点可以通过 Master 主控面板进行在线更新。

## 文件说明

```
NexCoreProxy-Agent/
├── install.sh    # 一键安装脚本
├── update.sh     # 更新脚本
├── VERSION       # 版本号
└── README.md     # 说明文档
```

## 技术栈

- 基于 [3X-UI](https://github.com/MHSanaei/3x-ui) v2.8.11+
- 支持协议: VMess, VLESS, Trojan, Shadowsocks
- 支持 TLS, WebSocket, gRPC, HTTP/2 等传输方式

## API 文档

3X-UI API 文档: https://documenter.getpostman.com/view/5146551/2sB3QCTuB6

## License

MIT