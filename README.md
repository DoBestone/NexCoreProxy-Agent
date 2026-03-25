# NexCoreProxy Agent

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

NexCoreProxy 代理主机节点服务端，基于 x-ui。

## 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/DoBestone/NexCoreProxy-Agent/main/install.sh) -u admin -pass YourPassword
```

### 安装参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-u, --user` | 管理员用户名 | ncp_admin |
| `-pass, --password` | 管理员密码 | **必填** |

### 安装示例

```bash
# 基本安装
bash <(curl -Ls https://raw.githubusercontent.com/DoBestone/NexCoreProxy-Agent/main/install.sh) -pass MyPassword123

# 自定义用户名
bash <(curl -Ls https://raw.githubusercontent.com/DoBestone/NexCoreProxy-Agent/main/install.sh) -u admin -pass MyPassword123
```

## 安装后信息

安装完成后会显示：
- 面板地址: `http://服务器IP:54321`
- 用户名和密码

## 主控面板配置

在 NexCoreProxy Master 主控面板添加节点时填写：
- IP: 服务器IP
- 端口: 54321
- 用户名: 安装时设置的用户名
- 密码: 安装时设置的密码

## 技术栈

- 基于 [x-ui](https://github.com/vaxilu/x-ui)
- 支持协议: VMess, VLESS, Trojan, Shadowsocks
- 固定端口: 54321

## License

MIT