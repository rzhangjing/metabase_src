# 会话安全与Cookie设置

<cite>
**本文档引用的文件**
- [cookies.clj](file://src/metabase/request/cookies.clj)
- [settings.clj](file://src/metabase/request/settings.clj)
- [util.clj](file://src/metabase/request/util.clj)
- [browser_cookie.clj](file://src/metabase/server/middleware/browser_cookie.clj)
- [core.clj](file://src/metabase/config/core.clj)
</cite>

## 目录
1. [会话Cookie属性设置](#会话cookie属性设置)
2. [SameSite Cookie策略](#samesite-cookie策略)
3. [HTTPS环境下的安全要求](#https环境下的安全要求)
4. [会话超时与Max-Age转换](#会话超时与max-age转换)
5. [代理环境下的最佳实践](#代理环境下的最佳实践)

## 会话Cookie属性设置

Metabase通过`default-session-cookie-attributes`多方法根据请求类型设置不同的Cookie属性。该函数根据会话类型（`:normal`或`:full-app-embed`）返回相应的Cookie属性配置。

对于普通会话（`:normal`），Cookie属性包括：
- `same-site`：根据`session-cookie-samesite`设置的值（默认为`lax`）
- `path`：设置为`/`
- `secure`：仅在HTTPS请求时添加，确保Cookie仅通过安全连接传输

对于全应用嵌入会话（`:full-app-embed`），Cookie属性包括：
- `path`：设置为`/`
- `same-site`：设置为`none`，以支持跨域嵌入
- `secure`：仅在HTTPS请求时添加，满足浏览器对`SameSite=None`的要求

**Section sources**
- [cookies.clj](file://src/metabase/request/cookies.clj#L35-L96)

## SameSite Cookie策略

Metabase支持三种SameSite模式，通过`session-cookie-samesite`设置进行配置：

**宽松模式（Lax）**
- 默认模式，提供平衡的安全性和可用性
- Cookie在跨站请求中不会被发送，但在用户从外部站点导航到Metabase时会被发送
- 适用于大多数标准部署场景

**无限制模式（None）**
- 允许Cookie在跨站请求中发送
- 必须与`Secure`标志一起使用，仅在HTTPS连接上有效
- 专为跨域嵌入场景设计，如将Metabase嵌入到其他应用中

**严格模式（Strict）**
- 最安全的模式，Cookie永远不会在跨站请求中发送
- 提供最强的CSRF保护，但可能影响用户体验
- 适用于对安全性要求极高的部署

这些模式通过`possible-session-cookie-samesite-values`私有变量定义，确保只有有效的值（`:lax`、`:none`、`:strict`）被接受。

**Section sources**
- [settings.clj](file://src/metabase/request/settings.clj#L37-L65)

## HTTPS环境下的安全要求

当`SameSite=None`与`Secure`标志关联时，Metabase实施严格的强制机制。系统通过`request.util/https?`函数检测请求是否通过HTTPS进行，该函数检查多个代理头（如`X-Forwarded-Proto`、`X-Forwarded-Ssl`）来确定原始请求的安全状态。

如果`session-cookie-samesite`设置为`none`但请求不是通过HTTPS进行，系统会记录警告日志：
```
"Session cookie's SameSite is configured to \"None\", but site is served over an insecure connection. Some browsers will reject cookies under these conditions."
```

这种机制确保了在不安全连接上不会发送`SameSite=None`的Cookie，防止浏览器拒绝这些Cookie。对于全应用嵌入场景，只有在HTTPS连接上才会设置`Secure`标志，确保符合现代浏览器的安全要求。

**Section sources**
- [cookies.clj](file://src/metabase/request/cookies.clj#L167-L181)
- [util.clj](file://src/metabase/request/util.clj#L60-L84)

## 会话超时与Max-Age转换

会话超时配置通过`session-timeout`设置进行管理，该设置接受JSON格式的值，包含`amount`和`unit`（秒、分钟、小时）。系统通过`session-timeout->seconds`函数将配置值转换为秒数，确保最小值为60秒以防止用户被锁定。

Cookie的`Max-Age`属性根据以下优先级确定：
1. 如果会话有`expires_at`时间戳，使用该时间计算`max-age`
2. 如果启用了永久Cookie（用户选择了"记住我"），使用`max-session-age`配置的值
3. 否则，使用默认的会话Cookie（在浏览器关闭时过期）

`max-session-age`的默认值为20160分钟（14天），可以在环境变量中配置。`Max-Age`值以秒为单位，因此需要将分钟转换为秒（乘以60）。

**Section sources**
- [cookies.clj](file://src/metabase/request/cookies.clj#L148-L167)
- [settings.clj](file://src/metabase/request/settings.clj#L65-L96)
- [core.clj](file://src/metabase/config/core.clj#L60)

## 代理环境下的最佳实践

在代理环境下，会话安全的最佳实践包括：

**X-Forwarded-For头验证**
- 使用`source-address-header`设置（默认为`X-Forwarded-For`）识别HTTP请求来源
- 通过`not-behind-proxy`设置指示Metabase是否运行在设置源地址头的代理后面
- 从`X-Forwarded-For`头获取客户端IP地址时，取第一个IP作为实际客户端IP

**安全Cookie的正确传递**
- 确保代理服务器正确传递和设置安全头
- 在HTTPS终止代理后，通过`X-Forwarded-Proto`等头传递原始协议信息
- 对于嵌入式场景，使用`ensure-browser-id-cookie`中间件设置持久性浏览器标识Cookie
- 浏览器标识Cookie在HTTPS上设置`SameSite=None`和`Secure`，在HTTP上设置`SameSite=Lax`

这些实践确保了在复杂网络拓扑中的会话安全性和可靠性，同时保持了与各种部署架构的兼容性。

**Section sources**
- [util.clj](file://src/metabase/request/util.clj#L83-L111)
- [browser_cookie.clj](file://src/metabase/server/middleware/browser_cookie.clj#L26-L45)
- [settings.clj](file://src/metabase/request/settings.clj#L0-L39)