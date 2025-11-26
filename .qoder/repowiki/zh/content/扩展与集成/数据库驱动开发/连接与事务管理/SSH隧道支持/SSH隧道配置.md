# SSH隧道配置

<cite>
**本文档中引用的文件**
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj)
- [common.clj](file://src/metabase/driver/common.clj)
- [settings.clj](file://src/metabase/driver/settings.clj)
- [util.clj](file://src/metabase/driver/util.clj)
- [connection.clj](file://src/metabase/driver/sql_jdbc/connection.clj)
</cite>

## 目录
1. [简介](#简介)
2. [SSH隧道架构概述](#ssh隧道架构概述)
3. [核心配置参数](#核心配置参数)
4. [认证方式](#认证方式)
5. [配置实现详解](#配置实现详解)
6. [配置验证与错误处理](#配置验证与错误处理)
7. [最佳实践](#最佳实践)
8. [故障排除指南](#故障排除指南)
9. [总结](#总结)

## 简介

Metabase的SSH隧道功能为用户提供了通过SSH安全通道连接到远程数据库的能力。该功能特别适用于需要访问位于防火墙后或网络隔离环境中的数据库的情况。SSH隧道在Metabase中作为JDBC驱动程序的一部分实现，支持多种认证方式，并提供了完善的错误处理和监控机制。

## SSH隧道架构概述

SSH隧道在Metabase中的实现采用了分层架构设计，确保了安全性、可靠性和可维护性。

```mermaid
graph TB
subgraph "客户端层"
UI[用户界面]
Config[配置管理器]
end
subgraph "SSH隧道层"
TunnelMgr[隧道管理器]
AuthMgr[认证管理器]
Heartbeat[心跳监控]
end
subgraph "连接池层"
ConnPool[连接池管理]
ConnSpec[连接规范]
end
subgraph "数据库层"
RemoteDB[远程数据库]
LocalProxy[本地代理]
end
UI --> Config
Config --> TunnelMgr
TunnelMgr --> AuthMgr
TunnelMgr --> Heartbeat
TunnelMgr --> ConnPool
ConnPool --> ConnSpec
ConnSpec --> LocalProxy
LocalProxy --> RemoteDB
```

**图表来源**
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj#L1-L33)
- [connection.clj](file://src/metabase/driver/sql_jdbc/connection.clj#L174-L198)

**章节来源**
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj#L1-L163)
- [connection.clj](file://src/metabase/driver/sql_jdbc/connection.clj#L174-L248)

## 核心配置参数

SSH隧道配置包含以下核心参数，每个参数都有特定的作用和安全考虑：

### 基础连接参数

| 参数名称 | 类型 | 必需 | 默认值 | 描述 |
|---------|------|------|--------|------|
| `tunnel-enabled` | boolean | 否 | false | 是否启用SSH隧道 |
| `tunnel-host` | string | 是 | - | SSH隧道主机名或IP地址 |
| `tunnel-port` | integer | 否 | 22 | SSH隧道端口号 |
| `tunnel-user` | string | 是 | - | SSH隧道用户名 |

### 认证相关参数

| 参数名称 | 类型 | 必需 | 描述 |
|---------|------|------|------|
| `tunnel-auth-option` | select | 否 | SSH认证方式选择（SSH密钥/密码） |
| `tunnel-pass` | password | 否 | SSH隧道密码（密码认证时必需） |
| `tunnel-private-key` | string | 否 | SSH私钥内容（密钥认证时必需） |
| `tunnel-private-key-passphrase` | password | 否 | SSH私钥密码短语（如有保护时必需） |

### 隧道行为参数

| 参数名称 | 类型 | 默认值 | 描述 |
|---------|------|--------|------|
| `ssh-heartbeat-interval-sec` | integer | 180 | SSH心跳间隔时间（秒） |
| `db-connection-timeout-ms` | integer | 10000 | 数据库连接超时时间（毫秒） |

**章节来源**
- [common.clj](file://src/metabase/driver/common.clj#L77-L123)
- [settings.clj](file://src/metabase/driver/settings.clj#L10-L25)

## 认证方式

Metabase支持两种主要的SSH隧道认证方式，每种方式都有其特定的安全特性和使用场景。

### 密码认证

密码认证是最简单的认证方式，适用于临时访问或测试环境。

```mermaid
sequenceDiagram
participant Client as 客户端
participant Tunnel as SSH隧道
participant Server as SSH服务器
Client->>Tunnel : 连接请求 (用户名+密码)
Tunnel->>Server : 验证凭据
Server-->>Tunnel : 认证结果
Tunnel-->>Client : 连接建立确认
Note over Client,Server : 使用密码进行身份验证
```

**图表来源**
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj#L39-L45)

#### 密码认证配置要点

- **安全性考虑**：密码应足够复杂，避免使用默认值
- **传输安全**：所有通信都通过加密隧道进行
- **会话管理**：支持会话保持和自动重连

### 私钥认证

私钥认证提供了更高的安全性，推荐用于生产环境。

```mermaid
sequenceDiagram
participant Client as 客户端
participant Tunnel as SSH隧道
participant Server as SSH服务器
Client->>Tunnel : 连接请求 (用户名+私钥)
Tunnel->>Server : 验证公钥
Server-->>Tunnel : 公钥验证成功
Tunnel->>Server : 私钥解密验证
Server-->>Tunnel : 最终认证确认
Tunnel-->>Client : 连接建立确认
Note over Client,Server : 使用非对称加密进行身份验证
```

**图表来源**
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj#L47-L65)

#### 私钥认证配置要点

- **密钥格式**：支持PEM格式的RSA和ECDSA私钥
- **密码保护**：私钥可以设置密码短语保护
- **密钥轮换**：支持定期更换私钥以提高安全性

**章节来源**
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj#L39-L65)
- [util.clj](file://src/metabase/driver/util.clj#L29-L60)

## 配置实现详解

SSH隧道的配置实现涉及多个层次的技术组件，形成了一个完整的连接管理体系。

### 隧道建立流程

```mermaid
flowchart TD
Start([开始配置]) --> CheckEnabled{检查隧道启用}
CheckEnabled --> |未启用| DirectConn[直接数据库连接]
CheckEnabled --> |已启用| ValidateParams[验证参数]
ValidateParams --> ParamValid{参数有效?}
ParamValid --> |否| ParamError[参数错误]
ParamValid --> |是| EstablishSSH[建立SSH连接]
EstablishSSH --> SSHSuccess{SSH连接成功?}
SSHSuccess --> |否| SSHErr[SSH连接失败]
SSHSuccess --> |是| SetupTunnel[设置端口转发]
SetupTunnel --> TunnelReady[隧道就绪]
TunnelReady --> UpdateDetails[更新连接详情]
UpdateDetails --> TestConnection[测试连接]
TestConnection --> ConnSuccess{连接成功?}
ConnSuccess --> |否| ConnErr[连接失败]
ConnSuccess --> |是| Complete([配置完成])
ParamError --> End([结束])
SSHErr --> End
ConnErr --> End
DirectConn --> End
Complete --> End
```

**图表来源**
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj#L99-L115)
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj#L117-L131)

### 连接池集成

SSH隧道与Metabase的连接池系统深度集成，确保资源的有效管理和并发访问控制。

```mermaid
classDiagram
class ConnectionPool {
+String databaseId
+Map details
+ClientSession tunnelSession
+PortForwardingTracker tunnelTracker
+createPool() ComboPooledDataSource
+invalidatePool() void
+closeTunnel() void
}
class SSHTunnelManager {
+startSSHConnection() SessionHolder
+setupPortForwarding() PortForwardingTracker
+manageHeartbeat() void
+closeConnection() void
}
class ConnectionDetails {
+String tunnelHost
+Integer tunnelPort
+String tunnelUser
+String tunnelPass
+String tunnelPrivateKey
+Boolean tunnelEnabled
+updateForTunnel() Map
}
ConnectionPool --> SSHTunnelManager : uses
SSHTunnelManager --> ConnectionDetails : manages
ConnectionPool --> ConnectionDetails : validates
```

**图表来源**
- [connection.clj](file://src/metabase/driver/sql_jdbc/connection.clj#L174-L198)
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj#L117-L131)

### 心跳机制

SSH隧道实现了智能的心跳机制，确保连接的稳定性和可靠性。

| 心跳类型 | 默认间隔 | 用途 | 可配置性 |
|---------|----------|------|----------|
| SSH会话心跳 | 180秒 | 检测连接状态 | 是 |
| 连接超时 | 30秒 | 连接建立超时 | 是 |
| 查询超时 | 20分钟 | 查询执行超时 | 是 |

**章节来源**
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj#L56-L74)
- [settings.clj](file://src/metabase/driver/settings.clj#L10-L25)

## 配置验证与错误处理

Metabase提供了完善的SSH隧道配置验证和错误处理机制，帮助用户快速识别和解决问题。

### 错误分类与处理

```mermaid
graph LR
subgraph "连接错误"
ConnFail[连接失败]
Timeout[连接超时]
HostUnreachable[主机不可达]
end
subgraph "认证错误"
AuthFail[认证失败]
PassWrong[密码错误]
KeyInvalid[密钥无效]
end
subgraph "配置错误"
ParamMissing[参数缺失]
PortInvalid[端口无效]
HostInvalid[主机无效]
end
subgraph "系统错误"
ResourceLimit[资源限制]
PermissionDenied[权限拒绝]
InternalError[内部错误]
end
ConnFail --> HumanizedMsg[人性化错误消息]
AuthFail --> HumanizedMsg
ParamMissing --> HumanizedMsg
HumanizedMsg --> UserGuidance[用户指导]
```

**图表来源**
- [util.clj](file://src/metabase/driver/util.clj#L29-L91)

### 常见错误类型

| 错误类型 | 错误代码 | 用户消息 | 解决方案 |
|---------|----------|----------|----------|
| SSH隧道连接失败 | `ssh-tunnel-connection-fail` | "无法连接到SSH隧道主机" | 检查主机名和端口设置 |
| SSH隧道认证失败 | `ssh-tunnel-auth-fail` | "SSH隧道主机认证失败" | 验证用户名和密码/密钥 |
| 主机设置错误 | `cannot-connect-check-host-and-port` | "主机或端口设置不正确" | 确认网络可达性 |
| 密码错误 | `password-incorrect` | "密码不正确" | 重新输入正确的密码 |

### 验证流程

```mermaid
sequenceDiagram
participant User as 用户
participant Validator as 验证器
participant SSH as SSH服务
participant DB as 数据库
User->>Validator : 提交配置
Validator->>Validator : 参数语法验证
Validator->>SSH : 尝试SSH连接
SSH-->>Validator : 连接状态
Validator->>SSH : 执行认证
SSH-->>Validator : 认证结果
Validator->>DB : 测试数据库连接
DB-->>Validator : 连接结果
Validator-->>User : 验证报告
Note over User,DB : 包含详细的错误信息和修复建议
```

**图表来源**
- [util.clj](file://src/metabase/driver/util.clj#L62-L91)

**章节来源**
- [util.clj](file://src/metabase/driver/util.clj#L29-L91)

## 最佳实践

为了确保SSH隧道配置的安全性和稳定性，建议遵循以下最佳实践。

### 安全配置建议

1. **使用私钥认证**
   - 优先使用SSH密钥而非密码认证
   - 定期轮换私钥对
   - 设置强密码短语保护私钥

2. **网络配置**
   - 确保SSH服务器端口（默认22）在网络中可访问
   - 考虑使用非标准端口提高安全性
   - 配置适当的防火墙规则

3. **权限管理**
   - 使用最小权限原则
   - 创建专用的SSH用户账户
   - 定期审计访问日志

### 性能优化

1. **连接参数调优**
   ```clojure
   ;; 推荐的心跳间隔设置
   {:ssh-heartbeat-interval-sec 180}
   
   ;; 推荐的连接超时设置
   {:db-connection-timeout-ms 15000}
   ```

2. **监控和日志**
   - 启用SSH隧道连接日志
   - 监控连接成功率
   - 设置告警阈值

### 配置模板

以下是生产环境推荐的SSH隧道配置模板：

```clojure
{
  :tunnel-enabled true
  :tunnel-host "secure-db.example.com"
  :tunnel-port 2222
  :tunnel-user "metabase-user"
  :tunnel-auth-option "ssh-key"
  :tunnel-private-key "-----BEGIN RSA PRIVATE KEY-----
  MIIEowIBAAKCAQEA...
  -----END RSA PRIVATE KEY-----"
  :tunnel-private-key-passphrase "your-strong-passphrase"
  :ssl true
  :additional-options "tcpKeepAlive=true;loginTimeout=10;"
}
```

## 故障排除指南

当SSH隧道配置出现问题时，可以按照以下步骤进行诊断和解决。

### 诊断流程

```mermaid
flowchart TD
Problem[遇到问题] --> CheckLogs[检查日志]
CheckLogs --> LogAnalysis{日志分析}
LogAnalysis --> |连接超时| NetworkIssue[网络问题]
LogAnalysis --> |认证失败| AuthIssue[认证问题]
LogAnalysis --> |主机不可达| HostIssue[主机问题]
LogAnalysis --> |其他错误| OtherIssue[其他问题]
NetworkIssue --> CheckFirewall[检查防火墙]
AuthIssue --> CheckCreds[检查凭据]
HostIssue --> CheckDNS[检查DNS解析]
OtherIssue --> ContactSupport[联系支持]
CheckFirewall --> FixNetwork[修复网络]
CheckCreds --> FixAuth[修复认证]
CheckDNS --> FixHost[修复主机配置]
FixNetwork --> TestConn[测试连接]
FixAuth --> TestConn
FixHost --> TestConn
ContactSupport --> Escalate[升级处理]
TestConn --> Success{连接成功?}
Success --> |是| Complete[问题解决]
Success --> |否| BackToProblem[返回问题]
Complete --> End[结束]
Escalate --> End
BackToProblem --> CheckLogs
```

### 常见问题及解决方案

| 问题症状 | 可能原因 | 解决方案 |
|---------|----------|----------|
| "无法连接到SSH隧道主机" | 网络不通或端口被阻塞 | 检查网络连通性和防火墙设置 |
| "SSH隧道主机认证失败" | 用户名密码错误或密钥问题 | 验证认证凭据的正确性 |
| "连接超时" | 网络延迟过高或服务器负载 | 调整超时设置或优化网络 |
| "查询执行超时" | 数据库响应缓慢 | 增加查询超时时间 |
| "密钥格式错误" | 私钥格式不正确 | 使用正确的PEM格式私钥 |

### 日志分析技巧

1. **启用详细日志**
   ```clojure
   ;; 在配置中启用调试日志
   {:log-level :debug}
   ```

2. **关键日志模式**
   ```
   << OPENED SSH TUNNEL >>
   creating ssh tunnel (heartbeating every 180 seconds)
   Closing SSH tunnel
   ```

3. **错误日志关键字**
   - `SSH tunnel connection failed`
   - `Authentication failed`
   - `Connection timeout`
   - `Cannot establish SSH tunnel`

**章节来源**
- [ssh_tunnel.clj](file://src/metabase/driver/sql_jdbc/connection/ssh_tunnel.clj#L133-L163)
- [util.clj](file://src/metabase/driver/util.clj#L62-L91)

## 总结

Metabase的SSH隧道配置功能提供了强大而灵活的数据库连接能力，支持多种认证方式和完善的错误处理机制。通过合理配置和遵循最佳实践，可以在保证安全性的同时获得稳定的数据库连接体验。

关键要点：
- 支持密码和私钥两种认证方式
- 提供完善的心跳和超时机制
- 实现了全面的错误处理和用户指导
- 与连接池系统深度集成
- 支持动态参数调整和运行时配置

对于需要访问受保护网络环境中的数据库的用户，SSH隧道功能是一个不可或缺的工具，能够显著提升数据访问的安全性和灵活性。