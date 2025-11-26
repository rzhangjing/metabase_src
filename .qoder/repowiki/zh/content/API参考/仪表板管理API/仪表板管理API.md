# Metabase仪表板管理API完整文档

<cite>
**本文档中引用的文件**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj)
- [src/metabase/dashboards/schema.clj](file://src/metabase/dashboards/schema.clj)
- [src/metabase/dashboards/models/dashboard.clj](file://src/metabase/dashboards/models/dashboard.clj)
- [src/metabase/public_sharing/api.clj](file://src/metabase/public_sharing/api.clj)
- [src/metabase/embedding/api.clj](file://src/metabase/embedding/api.clj)
- [src/metabase/embedding/api/embed.clj](file://src/metabase/embedding/api/embed.clj)
- [src/metabase/embedding/api/common.clj](file://src/metabase/embedding/api/common.clj)
- [src/metabase/public_sharing/validation.clj](file://src/metabase/public_sharing/validation.clj)
- [src/metabase/embedding/validation.clj](file://src/metabase/embedding/validation.clj)
- [src/metabase/embedding/settings.clj](file://src/metabase/embedding/settings.clj)
</cite>

## 目录
1. [简介](#简介)
2. [项目结构概览](#项目结构概览)
3. [核心组件分析](#核心组件分析)
4. [架构概览](#架构概览)
5. [详细组件分析](#详细组件分析)
6. [依赖关系分析](#依赖关系分析)
7. [性能考虑](#性能考虑)
8. [故障排除指南](#故障排除指南)
9. [结论](#结论)

## 简介

Metabase仪表板管理API提供了全面的仪表板生命周期管理功能，包括创建、更新、删除、权限管理和共享机制。该API支持公共共享和嵌入式共享两种主要的共享模式，为不同场景下的数据可视化需求提供灵活的解决方案。

本文档系统性地记录了所有仪表板相关的API端点，详细说明了公共和可嵌入仪表板的列表获取、仪表板的CRUD操作、权限管理功能，以及公共共享和嵌入式共享的安全机制。

## 项目结构概览

仪表板管理API的核心文件组织结构如下：

```mermaid
graph TB
subgraph "仪表板模块"
A[dashboards/api.clj] --> B[dashboards/schema.clj]
A --> C[dashboards/models/dashboard.clj]
A --> D[dashboards/settings.clj]
end
subgraph "共享模块"
E[public_sharing/api.clj] --> F[public_sharing/validation.clj]
G[embedding/api.clj] --> H[embedding/api/embed.clj]
G --> I[embedding/api/common.clj]
G --> J[embedding/validation.clj]
G --> K[embedding/settings.clj]
end
A --> E
A --> G
C --> A
```

**图表来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L1-L50)
- [src/metabase/public_sharing/api.clj](file://src/metabase/public_sharing/api.clj#L1-L30)
- [src/metabase/embedding/api.clj](file://src/metabase/embedding/api.clj#L1-L17)

## 核心组件分析

### 仪表板模型层

仪表板模型定义了仪表板的基本结构和验证规则：

```mermaid
classDiagram
class Dashboard {
+id : PositiveInt
+name : NonBlankString
+description : String
+parameters : Parameters[]
+dashcards : Dashcard[]
+public_uuid : UUIDString
+enable_embedding : Boolean
+embedding_params : Map
+width : Int
+archived : Boolean
+creator_id : PositiveInt
+collection_id : PositiveInt
+created_at : DateTime
+updated_at : DateTime
}
class Dashcard {
+id : PositiveInt
+card_id : PositiveInt
+dashboard_id : PositiveInt
+size_x : PositiveInt
+size_y : PositiveInt
+col : Int
+row : Int
+parameter_mappings : ParameterMapping[]
+series : Card[]
+visualization_settings : Map
+dashboard_tab_id : Int
}
class Parameter {
+id : NonBlankString
+name : NonBlankString
+slug : NonBlankString
+type : ParameterType
+values_source_type : String
+values_source_config : Map
+filteringParameters : String[]
}
Dashboard --> Dashcard : "包含多个"
Dashcard --> Parameter : "映射到"
```

**图表来源**
- [src/metabase/dashboards/schema.clj](file://src/metabase/dashboards/schema.clj#L1-L27)
- [src/metabase/dashboards/models/dashboard.clj](file://src/metabase/dashboards/models/dashboard.clj#L1-L100)

**章节来源**
- [src/metabase/dashboards/schema.clj](file://src/metabase/dashboards/schema.clj#L1-L27)
- [src/metabase/dashboards/models/dashboard.clj](file://src/metabase/dashboards/models/dashboard.clj#L1-L200)

### 公共共享机制

公共共享API提供了公开访问仪表板的功能：

```mermaid
sequenceDiagram
participant Client as 客户端
participant API as 公共共享API
participant Validation as 验证服务
participant Dashboard as 仪表板模型
participant Security as 安全检查
Client->>API : GET /api/public/dashboard/ : uuid
API->>Validation : check-public-sharing-enabled()
Validation-->>API : 验证通过
API->>Dashboard : 查询公开仪表板
Dashboard-->>API : 返回仪表板数据
API->>Security : 移除敏感字段
Security-->>API : 清理后的数据
API-->>Client : 返回公开仪表板
```

**图表来源**
- [src/metabase/public_sharing/api.clj](file://src/metabase/public_sharing/api.clj#L200-L250)

**章节来源**
- [src/metabase/public_sharing/api.clj](file://src/metabase/public_sharing/api.clj#L1-L300)
- [src/metabase/public_sharing/validation.clj](file://src/metabase/public_sharing/validation.clj#L1-L12)

### 嵌入式共享机制

嵌入式共享使用JWT令牌进行安全授权：

```mermaid
sequenceDiagram
participant Client as 客户端
participant EmbedAPI as 嵌入API
participant JWT as JWT验证
participant EmbedCommon as 嵌入通用逻辑
participant Dashboard as 仪表板服务
Client->>EmbedAPI : GET /api/embed/dashboard/ : token
EmbedAPI->>JWT : unsign-and-translate-ids(token)
JWT-->>EmbedAPI : 解码后的令牌
EmbedAPI->>EmbedCommon : check-embedding-enabled-for-dashboard()
EmbedCommon->>Dashboard : 验证嵌入权限
Dashboard-->>EmbedCommon : 权限验证结果
EmbedCommon-->>EmbedAPI : 验证通过
EmbedAPI->>EmbedCommon : dashboard-for-unsigned-token()
EmbedCommon-->>EmbedAPI : 返回清理后的仪表板
EmbedAPI-->>Client : 返回嵌入式仪表板
```

**图表来源**
- [src/metabase/embedding/api/embed.clj](file://src/metabase/embedding/api/embed.clj#L132-L161)
- [src/metabase/embedding/api/common.clj](file://src/metabase/embedding/api/common.clj#L100-L150)

**章节来源**
- [src/metabase/embedding/api/embed.clj](file://src/metabase/embedding/api/embed.clj#L1-L200)
- [src/metabase/embedding/api/common.clj](file://src/metabase/embedding/api/common.clj#L1-L300)
- [src/metabase/embedding/validation.clj](file://src/metabase/embedding/validation.clj#L1-L12)

## 架构概览

仪表板管理API采用分层架构设计，确保功能模块的清晰分离和良好的可维护性：

```mermaid
graph TB
subgraph "API层"
A[仪表板API控制器]
B[公共共享API]
C[嵌入式API]
end
subgraph "业务逻辑层"
D[仪表板服务]
E[权限验证服务]
F[参数处理服务]
G[查询处理器]
end
subgraph "数据访问层"
H[仪表板模型]
I[仪表板卡片模型]
J[参数模型]
end
subgraph "基础设施层"
K[数据库连接]
L[缓存服务]
M[JWT验证]
N[安全中间件]
end
A --> D
B --> E
C --> F
D --> G
E --> H
F --> I
G --> J
H --> K
I --> K
J --> K
C --> M
A --> N
B --> N
```

**图表来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L1-L50)
- [src/metabase/embedding/api.clj](file://src/metabase/embedding/api.clj#L1-L17)

## 详细组件分析

### 仪表板CRUD操作

仪表板API提供了完整的CRUD操作支持：

#### 创建仪表板

```mermaid
flowchart TD
Start([开始创建仪表板]) --> ValidateParams["验证请求参数"]
ValidateParams --> CheckPerms["检查创建权限"]
CheckPerms --> ValidateCollection["验证集合位置"]
ValidateCollection --> CreateDashboard["创建仪表板实例"]
CreateDashboard --> SetPosition["设置集合位置"]
SetPosition --> SaveToDB["保存到数据库"]
SaveToDB --> UpdateParams["更新参数卡片"]
UpdateParams --> PublishEvent["发布创建事件"]
PublishEvent --> TrackAnalytics["跟踪分析事件"]
TrackAnalytics --> HydrateDetails["填充详细信息"]
HydrateDetails --> ReturnResult["返回仪表板对象"]
ReturnResult --> End([结束])
```

**图表来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L100-L150)

#### 更新仪表板

仪表板更新操作支持参数映射、卡片序列等复杂更新：

```mermaid
flowchart TD
Start([开始更新仪表板]) --> LoadExisting["加载现有仪表板"]
LoadExisting --> ValidatePerms["验证写入权限"]
ValidatePerms --> CheckEmbedding["检查嵌入权限变更"]
CheckEmbedding --> ValidateParams["验证新参数"]
ValidateParams --> ProcessCards["处理卡片更新"]
ProcessCards --> UpdateCards["更新卡片映射"]
UpdateCards --> ValidateParamPerms["验证参数权限"]
ValidateParamPerms --> SaveChanges["保存更改"]
SaveChanges --> UpdateFieldValues["更新字段值"]
UpdateFieldValues --> PublishEvents["发布更新事件"]
PublishEvents --> End([结束])
```

**图表来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L600-L700)

**章节来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L100-L300)
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L600-L800)

### 参数管理系统

仪表板参数系统支持复杂的参数映射和权限控制：

#### 参数权限验证流程

```mermaid
flowchart TD
Start([参数权限验证]) --> ExtractMappings["提取参数映射"]
ExtractMappings --> GroupByCard["按卡片分组映射"]
GroupByCard --> CheckCardPerms["检查卡片权限"]
CheckCardPerms --> ValidateFields["验证字段权限"]
ValidateFields --> CheckTablePerms["检查表权限"]
CheckTablePerms --> GrantAccess["授予访问权限"]
GrantAccess --> End([验证完成])
CheckCardPerms --> |无权限| DenyAccess["拒绝访问"]
ValidateFields --> |无权限| DenyAccess
CheckTablePerms --> |无权限| DenyAccess
DenyAccess --> ThrowError["抛出权限错误"]
ThrowError --> End
```

**图表来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L450-L550)

**章节来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L450-L600)

### 仪表板加载优化

系统实现了智能的仪表板加载缓存机制：

#### 缓存策略

```mermaid
graph LR
A[请求仪表板] --> B{检查dashboard_load_id}
B --> |存在| C[使用缓存键]
B --> |不存在| D[直接查询]
C --> E{缓存命中?}
E --> |是| F[返回缓存结果]
E --> |否| G[查询数据库]
D --> G
G --> H[应用hydrators]
H --> I[添加查询平均时间]
I --> J[隐藏不可读卡片]
J --> K[存储到缓存]
K --> F
F --> L[返回结果]
G --> L
```

**图表来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L300-L400)

**章节来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L300-L450)

### 公共仪表板列表获取

系统提供了专门的端点用于获取可公开访问的仪表板列表：

#### 公共仪表板查询

```mermaid
sequenceDiagram
participant Client as 客户端
participant API as 公共仪表板API
participant PermCheck as 权限检查
participant Validation as 验证服务
participant DB as 数据库
Client->>API : GET /api/dashboard/public
API->>PermCheck : 检查应用权限
PermCheck-->>API : 权限验证
API->>Validation : check-public-sharing-enabled()
Validation-->>API : 公共共享启用
API->>DB : 查询公开仪表板
Note over DB : WHERE public_uuid IS NOT NULL<br/>AND archived = false
DB-->>API : 返回仪表板列表
API-->>Client : 返回公开仪表板数组
```

**图表来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L547-L576)

**章节来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L547-L580)

### 可嵌入仪表板列表获取

嵌入式仪表板列表专门针对嵌入场景优化：

#### 嵌入仪表板查询

```mermaid
sequenceDiagram
participant Client as 客户端
participant API as 嵌入仪表板API
participant PermCheck as 权限检查
participant Validation as 验证服务
participant DB as 数据库
Client->>API : GET /api/dashboard/embeddable
API->>PermCheck : 检查应用权限
PermCheck-->>API : 权限验证
API->>Validation : check-embedding-enabled()
Validation-->>API : 嵌入功能启用
API->>DB : 查询可嵌入仪表板
Note over DB : WHERE enable_embedding = true<br/>AND archived = false
DB-->>API : 返回可嵌入仪表板列表
API-->>Client : 返回嵌入仪表板数组
```

**图表来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L578-L590)

**章节来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L578-L590)

## 依赖关系分析

仪表板管理API的依赖关系体现了清晰的分层架构：

```mermaid
graph TB
subgraph "外部依赖"
A[Clojure核心库]
B[Malli验证库]
C[Toucan2 ORM]
D[Ring Web框架]
end
subgraph "内部模块依赖"
E[metabase.api.common]
F[metabase.permissions.core]
G[metabase.parameters.core]
H[metabase.query-processor.core]
I[metabase.events.core]
J[metabase.analytics.core]
end
subgraph "仪表板模块"
K[dashboards.api]
L[dashboards.models]
M[dashboards.schema]
end
subgraph "共享模块"
N[public_sharing.api]
O[embedding.api]
P[embedding.jwt]
end
K --> E
K --> F
K --> G
K --> H
K --> I
K --> J
K --> L
K --> M
N --> K
O --> P
O --> K
```

**图表来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L1-L50)
- [src/metabase/embedding/api.clj](file://src/metabase/embedding/api.clj#L1-L17)

**章节来源**
- [src/metabase/dashboards/api.clj](file://src/metabase/dashboards/api.clj#L1-L50)
- [src/metabase/embedding/api.clj](file://src/metabase/embedding/api.clj#L1-L17)

## 性能考虑

### 缓存机制

仪表板API实现了多层次的缓存策略：

1. **仪表板加载缓存**: 使用`dashboard_load_id`作为缓存键，实现10秒TTL的智能缓存
2. **元数据提供者缓存**: 在仪表板加载期间缓存元数据查询结果
3. **查询平均时间缓存**: 批量查询卡片的平均执行时间

### 批量操作优化

- **卡片批量水合**: 支持批量加载仪表板卡片及其关联数据
- **参数批量验证**: 批量检查参数权限，避免N+1查询问题
- **字段值批量更新**: 对于参数变化，批量更新相关字段值

### 查询优化

- **条件索引**: 利用数据库索引优化公开仪表板和嵌入仪表板查询
- **投影选择**: 只查询必要的字段，减少网络传输开销
- **分页支持**: 支持大数据集的分页查询

## 故障排除指南

### 常见问题及解决方案

#### 公共共享问题

**问题**: 无法访问公开仪表板
**原因**: 公共共享功能未启用或仪表板未设置公共UUID
**解决方案**: 
1. 检查`public-sharing-enabled`设置
2. 确认仪表板已启用公共分享
3. 验证公共UUID是否正确设置

#### 嵌入式共享问题

**问题**: JWT验证失败
**原因**: 
- 嵌入密钥未配置
- JWT格式不正确
- 令牌过期

**解决方案**:
1. 设置`embedding-secret-key`环境变量
2. 验证JWT签名和格式
3. 检查令牌有效期

#### 权限问题

**问题**: 参数权限验证失败
**原因**: 用户缺乏数据查询权限
**解决方案**:
1. 检查用户数据库访问权限
2. 验证参数引用的字段权限
3. 确认表级权限设置

**章节来源**
- [src/metabase/public_sharing/validation.clj](file://src/metabase/public_sharing/validation.clj#L1-L12)
- [src/metabase/embedding/validation.clj](file://src/metabase/embedding/validation.clj#L1-L12)

## 结论

Metabase仪表板管理API提供了功能完整、安全可靠的仪表板管理解决方案。通过分层架构设计，系统实现了良好的可维护性和扩展性。公共共享和嵌入式共享功能满足了不同场景下的数据可视化需求，而完善的权限控制系统确保了数据安全。

主要特性包括：
- 完整的仪表板CRUD操作支持
- 智能缓存机制提升性能
- 多层次的安全验证体系
- 灵活的参数映射和权限控制
- 优化的批量操作支持

该API为构建现代数据分析平台提供了坚实的基础，支持企业级的数据可视化和报告需求。