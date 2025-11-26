# 权限API

<cite>
**本文档中引用的文件**  
- [api.clj](file://src/metabase/permissions_rest/api.clj)
- [core.clj](file://src/metabase/permissions/core.clj)
- [schema.clj](file://src/metabase/permissions/schema.clj)
- [data_permissions.clj](file://src/metabase/permissions/models/data_permissions.clj)
- [permissions.clj](file://src/metabase/permissions/models/permissions.clj)
- [util.clj](file://src/metabase/permissions/util.clj)
- [validation.clj](file://src/metabase/permissions/validation.clj)
- [graph.clj](file://src/metabase/permissions_rest/data_permissions/graph.clj)
</cite>

## 目录
1. [简介](#简介)
2. [权限图API端点](#权限图api端点)
3. [权限组管理](#权限组管理)
4. [权限继承与多租户应用](#权限继承与多租户应用)
5. [复杂权限配置示例](#复杂权限配置示例)
6. [权限验证与检查](#权限验证与检查)

## 简介
Metabase权限管理系统提供了一套全面的API，用于管理用户对数据、集合和应用程序功能的访问权限。本系统基于权限路径（permissions paths）的概念，通过前缀匹配机制实现高效的权限检查。权限系统支持两种主要类型的权限：数据权限（data permissions）和集合权限（collection permissions）。超级用户自动拥有根权限（root permissions），可以访问所有资源。权限组（Permissions Groups）类似于其他系统中的"角色"，用户可以属于一个或多个权限组。该系统还支持企业版特有的功能，如数据沙盒（data sandboxing）和连接模拟（connection impersonation）。

**Section sources**
- [core.clj](file://src/metabase/permissions/core.clj#L1-L50)
- [permissions.clj](file://src/metabase/permissions/models/permissions.clj#L1-L100)

## 权限图API端点
权限图API提供了读取和更新系统中所有权限的接口。权限图以结构化格式表示所有权限组的权限分配情况，便于批量操作和版本控制。

### 读取权限图
权限图API提供了多个端点来获取权限图的不同视图：

```mermaid
flowchart TD
A[客户端] --> B[GET /api/permissions/graph]
B --> C{权限检查}
C --> |超级用户| D[返回完整权限图]
C --> |非超级用户| E[返回403错误]
F[客户端] --> G[GET /api/permissions/graph/db/:db-id]
G --> H{权限检查}
H --> |超级用户| I[返回指定数据库的权限图]
H --> |非超级用户| J[返回403错误]
K[客户端] --> L[GET /api/permissions/graph/group/:group-id]
L --> M{权限检查}
M --> |超级用户| N[返回指定组的权限图]
M --> |非超级用户| O[返回403错误]
```

**Diagram sources**
- [api.clj](file://src/metabase/permissions_rest/api.clj#L15-L45)

**Section sources**
- [api.clj](file://src/metabase/permissions_rest/api.clj#L15-L45)

### 更新权限图
PUT端点允许批量更新权限图，支持权限变更的版本控制和冲突检测：

```mermaid
sequenceDiagram
participant Client as "客户端"
participant API as "API端点"
participant Validator as "验证器"
participant DB as "数据库"
Client->>API : PUT /api/permissions/graph
API->>API : 检查超级用户权限
API->>Validator : 验证权限图格式
Validator-->>API : 验证结果
API->>DB : 获取当前权限图
DB-->>API : 当前权限图
API->>API : 比较修订号
alt 修订号匹配
API->>DB : 更新权限图
DB-->>API : 更新成功
API->>Client : 返回更新后的权限图
else 修订号不匹配
API->>Client : 返回409冲突错误
end
```

**Diagram sources**
- [api.clj](file://src/metabase/permissions_rest/api.clj#L47-L117)

**Section sources**
- [api.clj](file://src/metabase/permissions_rest/api.clj#L47-L117)

## 权限组管理
权限组管理API提供了对权限组及其成员的完整CRUD操作，支持权限组的创建、更新、删除以及成员管理。

### 权限组CRUD操作
权限组的创建、读取、更新和删除操作遵循严格的权限控制：

```mermaid
classDiagram
class PermissionsGroup {
+id : Integer
+name : String
+member_count : Integer
}
class PermissionsGroupMembership {
+id : Integer
+group_id : Integer
+user_id : Integer
+is_group_manager : Boolean
}
PermissionsGroup "1" *-- "0..*" PermissionsGroupMembership
class PermissionsAPI {
+getGroups() : PermissionsGroup[]
+getGroup(id : Integer) : PermissionsGroup
+createGroup(name : String) : PermissionsGroup
+updateGroup(id : Integer, name : String) : PermissionsGroup
+deleteGroup(id : Integer) : void
}
PermissionsAPI --> PermissionsGroup : "操作"
```

**Diagram sources**
- [api.clj](file://src/metabase/permissions_rest/api.clj#L119-L178)

**Section sources**
- [api.clj](file://src/metabase/permissions_rest/api.clj#L119-L178)

### 组成员管理
组成员管理API提供了对组成员的增删改查操作，支持批量操作和权限级别管理：

```mermaid
flowchart TD
A[添加成员] --> B[检查组管理权限]
B --> C[验证用户不是管理员]
C --> D[添加用户到组]
D --> E[返回更新后的成员列表]
F[更新成员] --> G[检查高级权限]
G --> H[检查组管理权限]
H --> I[更新成员权限]
I --> J[返回更新后的成员]
K[删除成员] --> L[检查组管理权限]
L --> M[删除成员关系]
M --> N[返回204无内容]
```

**Diagram sources**
- [api.clj](file://src/metabase/permissions_rest/api.clj#L179-L277)

**Section sources**
- [api.clj](file://src/metabase/permissions_rest/api.clj#L179-L277)

## 权限继承与多租户应用
权限系统实现了复杂的权限继承机制，支持多租户环境下的权限管理。

### 权限继承机制
权限继承遵循前缀匹配原则，确保权限检查的高效性：

```mermaid
erDiagram
USER ||--o{ PERMISSIONS_GROUP : "属于"
PERMISSIONS_GROUP ||--o{ PERMISSIONS : "拥有"
DATABASE ||--o{ TABLE : "包含"
PERMISSIONS_GROUP {
string name
integer id
}
PERMISSIONS {
integer id
integer group_id
string object
}
USER {
integer id
string email
}
DATABASE {
integer id
string name
}
TABLE {
integer id
string name
integer database_id
}
```

**Diagram sources**
- [permissions.clj](file://src/metabase/permissions/models/permissions.clj#L101-L200)

**Section sources**
- [permissions.clj](file://src/metabase/permissions/models/permissions.clj#L101-L200)

### 多租户环境应用
在多租户环境中，权限系统通过租户组和应用权限实现隔离：

```mermaid
graph TD
A[超级用户] --> B[管理所有租户]
C[租户管理员] --> D[管理租户内资源]
E[普通用户] --> F[访问授权资源]
G[应用权限] --> H[设置管理]
G --> I[监控工具]
G --> J[订阅管理]
K[数据权限] --> L[数据库访问]
K --> M[表访问]
K --> N[查询权限]
O[集合权限] --> P[收藏夹访问]
O --> Q[仪表板访问]
O --> R[卡片访问]
```

**Diagram sources**
- [core.clj](file://src/metabase/permissions/core.clj#L51-L100)

**Section sources**
- [core.clj](file://src/metabase/permissions/core.clj#L51-L100)

## 复杂权限配置示例
以下示例展示了如何配置复杂的权限场景，包括数据权限、集合权限和应用权限的组合。

### 数据权限配置
数据权限配置示例展示了如何为不同用户组设置不同的数据访问级别：

```mermaid
flowchart LR
A[权限组A] --> B[数据库1: 完全访问]
A --> C[数据库2: 只读访问]
A --> D[表1: 查询构建器和原生查询]
A --> E[表2: 仅查询构建器]
F[权限组B] --> G[数据库1: 无访问]
F --> H[数据库3: 完全访问]
F --> I[表3: 无下载]
F --> J[表4: 管理元数据]
K[权限组C] --> L[数据库2: 阻止访问]
K --> M[数据库4: 完全访问]
K --> N[表5: 沙盒访问]
K --> O[表6: 无管理]
```

**Diagram sources**
- [data_permissions.clj](file://src/metabase/permissions/models/data_permissions.clj#L1-L100)

**Section sources**
- [data_permissions.clj](file://src/metabase/permissions/models/data_permissions.clj#L1-L100)

### 高级权限配置
高级权限配置示例展示了如何结合多种权限类型实现复杂的访问控制：

```mermaid
classDiagram
class AdvancedPermissions {
+dataPermissions : Map~String, DataPermission~
+collectionPermissions : Map~String, CollectionPermission~
+applicationPermissions : Set~ApplicationPermission~
+blockPermissions : Set~BlockPermission~
+sandboxPermissions : Set~SandboxPermission~
}
class DataPermission {
+viewData : ViewDataLevel
+createQueries : QueryLevel
+downloadResults : DownloadLevel
+manageTableMetadata : Boolean
+manageDatabase : Boolean
}
class CollectionPermission {
+read : Boolean
+write : Boolean
}
class ApplicationPermission {
+setting : Boolean
+monitoring : Boolean
+subscription : Boolean
}
class BlockPermission {
+databaseId : Integer
}
class SandboxPermission {
+tableId : Integer
+query : String
}
AdvancedPermissions "1" *-- "1..*" DataPermission
AdvancedPermissions "1" *-- "1..*" CollectionPermission
AdvancedPermissions "1" *-- "0..*" ApplicationPermission
AdvancedPermissions "1" *-- "0..*" BlockPermission
AdvancedPermissions "1" *-- "0..*" SandboxPermission
```

**Diagram sources**
- [schema.clj](file://src/metabase/permissions/schema.clj#L1-L34)

**Section sources**
- [schema.clj](file://src/metabase/permissions/schema.clj#L1-L34)

## 权限验证与检查
权限系统提供了完善的验证和检查机制，确保权限操作的安全性和一致性。

### 权限验证流程
权限验证流程确保所有权限操作都符合系统规则：

```mermaid
sequenceDiagram
participant User as "用户"
participant API as "API"
participant Validator as "验证器"
participant PermissionSystem as "权限系统"
User->>API : 请求权限操作
API->>Validator : 验证请求参数
Validator-->>API : 验证结果
API->>API : 检查用户权限
API->>PermissionSystem : 获取当前权限状态
PermissionSystem-->>API : 当前权限
API->>API : 检查修订号
API->>API : 记录权限变更
API->>PermissionSystem : 执行权限更新
PermissionSystem-->>API : 更新结果
API-->>User : 返回响应
```

**Diagram sources**
- [util.clj](file://src/metabase/permissions/util.clj#L1-L50)

**Section sources**
- [util.clj](file://src/metabase/permissions/util.clj#L1-L50)

### 权限检查规则
权限检查规则定义了不同场景下的权限验证逻辑：

```mermaid
flowchart TD
A[权限检查] --> B{检查类型}
B --> C[应用权限]
B --> D[数据权限]
B --> E[集合权限]
B --> F[块权限]
B --> G[沙盒权限]
C --> H[检查高级权限功能]
C --> I[检查超级用户]
D --> J[检查数据库权限]
D --> K[检查表权限]
D --> L[检查模式权限]
E --> M[检查收藏夹权限]
E --> N[检查仪表板权限]
E --> O[检查卡片权限]
F --> P[检查阻止权限]
G --> Q[检查沙盒权限]
R[结果] --> S[允许访问]
R --> T[拒绝访问]
R --> U[沙盒访问]
```

**Diagram sources**
- [validation.clj](file://src/metabase/permissions/validation.clj#L1-L55)

**Section sources**
- [validation.clj](file://src/metabase/permissions/validation.clj#L1-L55)