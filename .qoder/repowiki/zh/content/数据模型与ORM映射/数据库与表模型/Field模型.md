# Field模型

<cite>
**本文档中引用的文件**  
- [field.clj](file://src\metabase\warehouse_schema\models\field.clj)
- [field_user_settings.clj](file://src\metabase\warehouse_schema\models\field_user_settings.clj)
- [sync_instances.clj](file://src\metabase\sync\sync_metadata\fields\sync_instances.clj)
- [sync_metadata.clj](file://src\metabase\sync\sync_metadata\fields\sync_metadata.clj)
- [name.clj](file://src\metabase\analyze\classifiers\name.clj)
- [describe_table.clj](file://src\metabase\driver\sql_jdbc\sync\describe_table.clj)
</cite>

## 目录
1. [引言](#引言)
2. [字段属性详解](#字段属性详解)
3. [字段类型推断与语义标注](#字段类型推断与语义标注)
4. [用户自定义设置](#用户自定义设置)
5. [字段在查询处理中的角色](#字段在查询处理中的角色)
6. [有效性验证规则](#有效性验证规则)
7. [与Table的归属关系](#与table的归属关系)
8. [元数据查询与更新操作](#元数据查询与更新操作)

## 引言
Field模型是Metabase系统中用于描述数据库字段元数据的核心组件。它不仅包含了字段在数据库中的物理属性，还扩展了丰富的语义信息和用户自定义设置，为数据分析和可视化提供了坚实的基础。本文档将深入解析Field模型的设计，重点阐述其核心属性、类型推断机制、语义标注应用以及用户自定义设置的管理。

## 字段属性详解
Field模型定义了多个关键属性，用于全面描述数据库字段的特征：

- **数据库类型（database-type）**：表示字段在源数据库中的原始数据类型，如VARCHAR、INTEGER等。该属性在同步元数据时从数据库元数据中获取。
- **基础类型（base-type）**：表示字段的通用数据类型，如:type/Text、:type/Integer等。它是对数据库类型的抽象，用于跨数据库的类型一致性。
- **语义类型（semantic-type）**：表示字段的业务语义，如:type/PK（主键）、:type/FK（外键）、:type/Name（名称）、:type/Price（价格）等。它为字段赋予了业务含义。
- **位置信息（database-position）**：表示字段在数据库表中的物理位置（列序号），用于保持字段顺序的一致性。

这些属性在`field.clj`文件中通过Toucan 2的模型定义和转换器进行管理，确保了数据的完整性和一致性。

**Section sources**
- [field.clj](file://src\metabase\warehouse_schema\models\field.clj#L0-L439)

## 字段类型推断与语义标注
Field模型通过智能化的推断机制自动为字段分配语义类型，极大地提升了用户体验。

### 类型推断机制
系统通过分析字段名称和基础类型来推断其语义类型。在`name.clj`文件中定义了名称模式与语义类型的映射关系：
- 字段名包含"price"、"cost"、"amount"等关键词且为基础数值类型时，推断为:type/Price
- 字段名包含"category"、"type"、"kind"等关键词时，推断为:type/Category
- 字段名包含"email"、"mail"等关键词时，推断为:type/Email

这种基于名称模式的推断机制使得系统能够自动识别字段的业务含义，无需用户手动配置。

### 语义标注的应用场景
语义标注对可视化和数据分析有重要影响：
- :type/Price字段在可视化时会自动使用货币格式化
- :type/Category字段会被识别为维度，适合用于分组和筛选
- :type/DateTime字段会启用时间序列分析功能
- :type/FK字段会建立表间关联，支持跨表查询

这些语义信息指导了前端的可视化组件选择和数据处理逻辑，使得分析更加智能和准确。

**Section sources**
- [name.clj](file://src\metabase\analyze\classifiers\name.clj#L103-L126)
- [field.clj](file://src\metabase\warehouse_schema\models\field.clj#L0-L439)

## 用户自定义设置
用户可以通过`field_user_settings.clj`文件管理的设置来个性化字段的显示和行为。

### 设置的存储与读取
用户自定义设置存储在独立的`metabase_field_user_settings`表中，与主字段表分离。这种设计确保了：
- 用户设置不会在元数据同步时被覆盖
- 设置可以独立于字段的物理属性进行管理
- 支持设置的序列化和迁移

当读取字段信息时，系统会自动合并主字段表和用户设置表的数据，提供完整的字段视图。

### 可自定义的属性
用户可以自定义以下属性：
- **显示名称（display_name）**：字段在界面中显示的友好名称
- **格式化选项（settings）**：包括数字格式、日期格式等显示格式
- **可见性类型（visibility_type）**：控制字段在查询构建器中的可见性
- **字段值列表（has_field_values）**：指定是否为字段生成值列表用于筛选

这些设置通过`upsert-user-settings`函数进行更新，确保了设置的原子性和一致性。

**Section sources**
- [field_user_settings.clj](file://src\metabase\warehouse_schema\models\field_user_settings.clj#L0-L83)
- [field.clj](file://src\metabase\warehouse_schema\models\field.clj#L0-L439)

## 字段在查询处理中的角色
Field模型在查询处理流程中扮演着关键角色，连接了物理数据库和逻辑分析层。

### 元数据同步
在`sync_instances.clj`和`sync_metadata.clj`文件中，系统定期从数据库同步字段元数据。同步过程包括：
- 获取字段的数据库类型、位置等物理属性
- 计算基础类型和语义类型
- 更新字段的指纹信息用于分析
- 维护字段的父子关系（用于嵌套字段）

### 查询构建
在查询构建阶段，字段的元数据被用于：
- 生成查询构建器的字段列表
- 提供字段的类型信息用于语法检查
- 支持智能提示和自动补全
- 确定字段的聚合方式和显示格式

字段模型作为查询处理的元数据基础，确保了查询的正确性和效率。

**Section sources**
- [sync_instances.clj](file://src\metabase\sync\sync_metadata\fields\sync_instances.clj#L74-L90)
- [sync_metadata.clj](file://src\metabase\sync\sync_metadata\fields\sync_metadata.clj#L45-L70)

## 有效性验证规则
Field模型实施了严格的验证规则，确保数据的完整性和一致性。

### 类型验证
系统通过malli schema对字段属性进行验证：
- base-type必须是:type/*的派生类型
- semantic-type必须是:Semantic/*或:Relation/*的派生类型
- coercion_strategy必须是:Coercion/*的派生类型

这些验证规则在字段创建和更新时自动执行，防止无效数据的存入。

### 业务规则验证
除了类型验证，系统还实施了业务规则验证：
- 主键字段必须有非空的基础类型
- 外键字段必须指向有效的目标字段
- 字段名称在表内必须唯一
- 位置信息必须为非负整数

这些验证规则通过Toucan 2的钩子函数在数据持久化前执行，确保了业务逻辑的正确性。

**Section sources**
- [field.clj](file://src\metabase\warehouse_schema\models\field.clj#L0-L439)
- [sync_metadata.clj](file://src\metabase\sync\sync_metadata\fields\sync_metadata.clj#L94-L120)

## 与Table的归属关系
Field模型与Table模型之间存在明确的归属关系，形成了层次化的元数据结构。

### 层次结构
每个字段都归属于一个特定的表，这种关系通过`table_id`外键维护。系统支持：
- 字段的级联删除（删除表时自动删除其字段）
- 高效的字段批量查询（通过表ID查询所有字段）
- 表级别的权限控制（基于表权限决定字段访问权限）

### 权限管理
字段的访问权限继承自其所属表，但可以有额外的限制：
- 用户必须有表的查看数据权限才能访问字段
- 敏感字段可以设置额外的访问控制
- 虚拟字段（如计算字段）有特殊的权限规则

这种设计平衡了权限管理的灵活性和安全性。

**Section sources**
- [field.clj](file://src\metabase\warehouse_schema\models\field.clj#L0-L439)
- [interface.clj](file://src\metabase\sync\interface.clj#L131-L168)

## 元数据查询与更新操作
系统提供了丰富的API来查询和更新字段元数据。

### 查询操作
通过`get-field`和`get-fields`函数可以查询字段信息：
- 支持单个字段和批量字段查询
- 自动合并用户自定义设置
- 支持按可见性过滤字段
- 提供完整的字段元数据视图

### 更新操作
字段更新操作包括：
- 基础属性更新（如重命名）
- 语义类型修改
- 用户设置更新
- 批量同步更新

更新操作会触发相应的钩子函数，确保数据的一致性和完整性。例如，更新字段类型会自动重置指纹信息，触发重新分析。

**Section sources**
- [field.clj](file://src\metabase\warehouse_schema\models\field.clj#L0-L439)
- [field_user_settings.clj](file://src\metabase\warehouse_schema\models\field_user_settings.clj#L0-L83)