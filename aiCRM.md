# Cordys CRM AI 驱动能力全景

## 📋 概述

**Cordys CRM** 作为新一代 AI 驱动的 CRM 系统，深度整合了多项 AI 能力，实现从传统客户管理向智能化销售运营的跨越。本文档详细梳理了当前系统的所有 AI 相关功能模块。

---

## 🤖 AI 能力架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                    Cordys CRM AI 能力层                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │   MaxKB      │  │   SQLBot     │  │     DataEase         │   │
│  │  智能体平台   │  │  智能问数    │  │   BI 可视化分析       │   │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘   │
│         │                 │                      │               │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────────▼───────────┐   │
│  │ 智能创建     │  │ 自然语言查询 │  │   销售数据可视化      │   │
│  │ 智能录入     │  │ 数据库结构   │  │   自助分析            │   │
│  │ 智能跟进     │  │ 权限过滤     │  │   归因分析            │   │
│  │ 智能报价     │  │ 数据安全     │  │   嵌入式看板          │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│                         MCP Server 开放协议                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎯 一、MaxKB 智能体集成

### 功能定位
MaxKB 是飞致云出品的企业级智能体开发平台，Cordys CRM 深度集成 MaxKB，实现智能化销售操作。

### 核心功能

| 功能模块 | 描述 | 应用场景 |
|----------|------|----------|
| **智能创建** | 通过对话方式创建线索/客户/商机/联系人 | 销售人员快速录入信息 |
| **智能录入** | AI 辅助填写跟进记录 | 自动提取通话/会议要点 |
| **智能查重** | 自动识别重复客户/线索 | 数据清洗与合并 |
| **智能跟进** | 基于历史数据推荐跟进策略 | 销售策略优化 |
| **智能报价** | 自动生成报价单 | 快速响应客户需求 |

### 技术实现

**后端代码路径**: `backend/crm/src/main/java/cn/cordys/crm/integration/agent/`

#### 核心服务类

```java
// AgentBaseService.java - 智能体核心服务
@Service
public class AgentBaseService {
    // 添加智能体
    public Agent addAgent(AgentAddRequest request, String orgId, String userId);
    
    // 获取工作空间列表
    public List<OptionDTO> workspace(String orgId);
    
    // 获取应用列表
    public List<OptionDTO> application(String workspaceId, String orgId);
    
    // 获取嵌入脚本信息
    public ScriptResponse script(ScriptRequest request, String orgId);
}
```

#### API 端点

| 端点 | 方法 | 描述 |
|------|------|------|
| `/agent/add` | POST | 添加智能体 |
| `/agent/update` | POST | 更新智能体 |
| `/agent/detail/{id}` | GET | 智能体详情 |
| `/agent/page` | POST | 智能体列表 |
| `/agent/workspace` | GET | 获取MaxKB工作空间 |
| `/agent/application/{workspaceId}` | GET | 获取应用列表 |
| `/agent/script` | POST | 获取嵌入脚本 |
| `/agent/edition` | GET | 获取MaxKB版本(PE/EE) |

#### MaxKB API 路径

```java
// MaxKBApiPaths.java
public interface MaxKBApiPaths {
    String WORKSPACE = "/admin/api/workspace";              // 工作空间
    String EDITION = "/admin/api/profile";                   // 版本信息
    String APPLICATION = "/admin/api/workspace/{0}/application";  // 应用列表
    String ACCESS_TOKEN = "/admin/api/workspace/{0}/application/{1}/access_token";  // 访问令牌
    String APPLICATION_DETAIL = "/admin/api/workspace/{0}/application/{1}";         // 应用详情
}
```

### 配置参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `mkAddress` | MaxKB 服务地址 | `https://maxkb.example.com` |
| `appSecret` | 应用密钥 | `xxx-xxx-xxx` |
| `workspaceId` | 工作空间 ID | `ws-001` |
| `applicationId` | 应用 ID | `app-001` |

### 智能体数据模型

```java
// Agent.java
@Table(name = "agent")
public class Agent extends BaseModel {
    private String name;           // 智能体名称
    private String agentModuleId;  // 模块ID
    private String organizationId; // 组织ID
    private String scopeId;        // 应用范围(JSON)
    private String script;         // 嵌入脚本
    private String description;    // 描述
    private String type;           // 添加方式
    private String workspaceId;    // MaxKB工作空间ID
    private String applicationId;  // MaxKB应用ID
}
```

---

## 📊 二、SQLBot 智能问数

### 功能定位
SQLBot 是基于大模型和 RAG 的智能问数系统，允许用户使用自然语言查询 CRM 数据。

### 核心功能

| 功能 | 描述 | 技术实现 |
|------|------|----------|
| **自然语言查询** | 用中文提问获取数据 | LLM + Text-to-SQL |
| **数据库结构解析** | 自动解析表结构供AI使用 | 元数据提取 |
| **权限过滤** | 按用户权限过滤可查询的表 | 动态SQL注入 |
| **数据脱敏** | 敏感数据加密传输 | AES-CBC加密 |
| **虚拟表支持** | 支持公海池/线索池等虚拟表 | 视图映射 |

### 技术实现

**后端代码路径**: `backend/crm/src/main/java/cn/cordys/crm/integration/sqlbot/`

#### 支持的业务表

```java
// SQLBotTable.java - 支持的表枚举
public enum SQLBotTable {
    PRODUCT("product", "产品表", null, false),
    CUSTOMER("customer", "客户表", CUSTOMER_MANAGEMENT_READ, true),
    CLUE("clue", "线索表", CLUE_MANAGEMENT_READ, true),
    OPPORTUNITY("opportunity", "商机表", OPPORTUNITY_MANAGEMENT_READ, true),
    CONTACT("customer_contact", "联系人表", CUSTOMER_MANAGEMENT_CONTACT_READ, true),
    
    // 虚拟表
    POOL_CUSTOMER("pool_customer", "公海中的客户表", CUSTOMER_MANAGEMENT_POOL_READ, true),
    POOL_CLUE("pool_clue", "线索池中的线索表", CLUE_MANAGEMENT_POOL_READ, true);
}
```

#### 核心服务

```java
// DataSourceService.java
@Service
public class DataSourceService {
    // 获取数据库结构(供SQLBot使用)
    public SQLBotDTO getDatabaseSchema(String userId, String orgId);
    
    // 获取表列表(带缓存)
    @Cacheable(value = "table_schema_cache", key = "#databaseName")
    public List<TableDTO> tableList(String databaseName);
}
```

#### 权限处理器

系统为每种业务表实现了专门的权限处理器：

| 处理器 | 业务表 | 功能 |
|--------|--------|------|
| `CustomerPermissionHandler` | customer | 客户数据权限过滤 |
| `CluePermissionHandler` | clue | 线索数据权限过滤 |
| `OpportunityPermissionHandler` | opportunity | 商机数据权限过滤 |
| `ContactPermissionHandler` | customer_contact | 联系人数据权限过滤 |
| `PoolCustomerPermissionHandler` | pool_customer | 公海客户权限过滤 |
| `PoolCluePermissionHandler` | pool_clue | 线索池权限过滤 |
| `ProductPermissionHandler` | product | 产品数据权限过滤 |

#### 字段解析器

支持多种字段类型的智能解析：

```
field/
├── InputParser.java          # 文本输入
├── SelectParser.java         # 单选下拉
├── SelectMultipleParser.java # 多选下拉
├── DateTimeParser.java       # 日期时间
├── MemberParser.java         # 人员选择
├── DepartmentParser.java     # 部门选择
├── PhoneParser.java          # 电话号码
├── RadioParser.java          # 单选框
├── CheckboxParser.java       # 复选框
├── TextareaParser.java       # 多行文本
└── SerialNumberParser.java   # 流水号
```

#### API 端点

| 端点 | 方法 | 描述 |
|------|------|------|
| `/db/structure` | GET | 获取数据库结构(SQLBot专用) |

### 配置参数

```yaml
sqlbot:
  encrypt: true                    # 是否启用加密
  aes-key: ${random.value}         # AES加密密钥
  aes-iv: ${random.value}          # AES初始向量
  datasource:
    username: ${spring.datasource.username}
    password: ${spring.datasource.password}
```

---

## 📈 三、DataEase BI 集成

### 功能定位
DataEase 是开源 BI 工具，Cordys CRM 集成 DataEase 实现销售数据的可视化分析。

### 核心功能

| 功能 | 描述 | 应用场景 |
|------|------|----------|
| **嵌入式看板** | 将 DataEase 看板嵌入 CRM | 销售管理驾驶舱 |
| **JWT 单点登录** | 自动认证无需二次登录 | 无缝用户体验 |
| **数据权限同步** | CRM 权限映射到 DataEase | 数据安全 |
| **用户同步** | 自动同步 CRM 用户到 DataEase | 统一管理 |

### 技术实现

**后端代码路径**: `backend/crm/src/main/java/cn/cordys/crm/integration/dataease/`

#### 核心服务

```java
// DataEaseService.java
@Service
public class DataEaseService {
    // 获取嵌入式DE-Token
    public DeAuthDTO getEmbeddedDeToken(String organizationId, String userId, boolean isModule);
    
    // 获取DataEase配置
    public ThirdConfigurationDTO getDeConfig(String organizationId);
    
    // 生成JWT Token
    private String generateJwtToken(String appId, String appSecret, String account);
}
```

#### 数据权限变量

```java
// 数据范围变量
public enum DataScopeVariable {
    CURRENT_USER_ID,      // 当前用户ID
    CURRENT_ORG_ID,       // 当前组织ID
    CURRENT_DEPT_ID,      // 当前部门ID
}

// 部门数据范围变量
public enum DataScopeDeptVariable {
    DEPT_IDS,             // 部门ID列表
    ALL_DATA,             // 全部数据
}
```

#### 同步服务

```java
// DataEaseSyncService.java - 数据同步服务
@Service
public class DataEaseSyncService {
    // 同步用户到DataEase
    // 同步角色到DataEase
    // 同步权限到DataEase
}
```

---

## 🔍 四、智能搜索系统

### 功能定位
提供跨模块的统一智能搜索，支持全局搜索和高级查重搜索。

### 核心功能

| 功能模块 | 描述 | 应用场景 |
|----------|------|----------|
| **全局搜索** | 跨模块统一搜索 | 快速定位客户/商机 |
| **高级搜索** | 精确条件筛选 | 复杂查询需求 |
| **智能查重** | 识别重复数据 | 数据清洗 |
| **相似匹配** | 查找相似客户/商机 | 数据合并 |

### 技术实现

**后端代码路径**: `backend/crm/src/main/java/cn/cordys/crm/search/`

#### 模块结构

```
search/
├── controller/
│   ├── GlobalSearchController.java      # 全局搜索控制器
│   ├── AdvancedSearchController.java    # 高级搜索控制器
│   ├── SearchFieldMaskConfigController.java  # 搜索字段掩码配置
│   └── UserSearchConfigController.java  # 用户搜索配置
├── service/
│   ├── global/                          # 全局搜索服务
│   │   ├── GlobalCustomerSearchService.java
│   │   ├── GlobalClueSearchService.java
│   │   ├── GlobalOpportunitySearchService.java
│   │   ├── GlobalCustomerContactSearchService.java
│   │   ├── GlobalCustomerPoolSearchService.java
│   │   ├── GlobalCluePoolSearchService.java
│   │   └── GlobalSearchCountService.java
│   └── advanced/                        # 高级搜索服务
│       ├── AdvancedCustomerSearchService.java
│       ├── AdvancedClueSearchService.java
│       ├── AdvancedOpportunitySearchService.java
│       └── AdvancedSearchServiceFactory.java
```

#### 全局搜索 API

| 端点 | 方法 | 描述 |
|------|------|------|
| `/global/search/account` | POST | 搜索客户 |
| `/global/search/lead` | POST | 搜索线索 |
| `/global/search/opportunity` | POST | 搜索商机 |
| `/global/search/contact` | POST | 搜索联系人 |
| `/global/search/customer_pool` | POST | 搜索公海客户 |
| `/global/search/clue_pool` | POST | 搜索线索池 |
| `/global/search/module/count` | POST | 模块数量统计 |

#### 搜索模块枚举

```java
// SearchModuleEnum.java
public enum SearchModuleEnum {
    CUSTOMER,           // 客户
    CUSTOMER_CONTACT,   // 联系人
    CLUE,              // 线索
    OPPORTUNITY,       // 商机
    CUSTOMER_POOL,     // 公海
    CLUE_POOL          // 线索池
}
```

---

## 🔗 五、MCP Server 开放协议

### 功能定位
MCP (Model Context Protocol) 是 Cordys CRM 开放的 AI 接口协议，允许第三方 AI 系统对接 CRM。

### 支持的操作

| 操作类型 | 支持模块 | 描述 |
|----------|----------|------|
| **智能创建** | 线索、客户、商机、联系人 | AI 对话创建业务数据 |
| **智能录入** | 跟进记录 | 自动提取会议纪要 |
| **智能查重** | 客户、线索 | 识别重复数据 |

### 接口文档

**文档路径**: `installer/mcp/mcp.md`

---

## ⚙️ 六、自动化规则引擎

### 功能定位
基于规则的自动化处理，减少人工操作。

### 核心功能

| 功能 | 描述 | 应用场景 |
|------|------|----------|
| **商机自动关闭** | 超期未跟进自动关闭 | 商机管理优化 |
| **线索自动回收** | 超期线索回收到线索池 | 线索池管理 |
| **客户自动回收** | 超期客户移入公海 | 公海机制 |
| **定时任务调度** | 规则定时执行 | 自动化运营 |

### 技术实现

```java
// OpportunityRuleListener.java - 商机规则监听器
@Component
public class OpportunityRuleListener implements ApplicationListener<ScheduleExecuteEvent> {
    // 根据预设规则自动处理商机状态
    // 当触发执行事件时，检查所有相关商机
    // 根据规则条件自动关闭符合条件的商机
}
```

---

## 🔌 七、第三方平台集成

### 企业协作平台

| 平台 | 功能 | 代码路径 |
|------|------|----------|
| **企业微信** | 消息通知、用户同步、扫码登录 | `integration/wecom/` |
| **钉钉** | 消息通知、组织架构同步 | `integration/dingtalk/` |
| **飞书** | 消息通知、用户同步 | `integration/lark/` |

### SSO 单点登录

```java
// SSOService.java - 单点登录服务
@Service
public class SSOService {
    // 统一身份认证
    // Token 管理
    // OAuth 集成
}
```

---

## 📁 八、代码结构总览

```
backend/crm/src/main/java/cn/cordys/crm/integration/
├── agent/                    # MaxKB 智能体集成
│   ├── constant/            # MaxKB API 路径常量
│   ├── controller/          # 智能体控制器
│   ├── domain/              # 智能体实体
│   ├── dto/                 # 数据传输对象
│   ├── mapper/              # 数据访问层
│   ├── response/            # MaxKB 响应模型
│   └── service/             # 智能体服务
├── sqlbot/                   # SQLBot 智能问数
│   ├── constant/            # 表枚举定义
│   ├── controller/          # 数据源控制器
│   ├── dto/                 # 数据传输对象
│   ├── handler/             # 权限处理器
│   │   └── field/           # 字段解析器
│   ├── mapper/              # 数据访问层
│   └── service/             # 数据源服务
├── dataease/                 # DataEase BI 集成
│   ├── constants/           # 数据范围变量
│   ├── dto/                 # 数据传输对象
│   └── service/             # DataEase 服务
├── dingtalk/                 # 钉钉集成
├── lark/                     # 飞书集成
├── wecom/                    # 企业微信集成
├── sso/                      # 单点登录
├── sync/                     # 数据同步
└── common/                   # 公共组件
    ├── client/              # HTTP 客户端
    ├── dto/                 # 公共 DTO
    └── utils/               # 工具类
```

---

## 🚀 九、AI 能力扩展指南

### 添加新的 AI 智能体

1. **创建智能体应用** - 在 MaxKB 平台创建应用
2. **配置工作流** - 定义智能体的对话逻辑
3. **获取 Access Token** - 通过 API 获取访问令牌
4. **嵌入 CRM** - 使用嵌入脚本集成到 CRM 界面

### 扩展 SQLBot 支持的表

```java
// 1. 在 SQLBotTable 枚举添加新表
NEW_TABLE("table_name", "表描述", PERMISSION_READ, true);

// 2. 实现对应的权限处理器
public class NewTablePermissionHandler extends DataScopeTablePermissionHandler {
    @Override
    public void handleTable(TableDTO table, TableHandleParam param) {
        // 实现权限过滤逻辑
    }
}

// 3. 在工厂类注册处理器
TablePermissionHandlerFactory.register(SQLBotTable.NEW_TABLE, new NewTablePermissionHandler());
```

### 集成新的 BI 工具

1. 实现 JWT Token 生成逻辑
2. 配置嵌入式 iframe 参数
3. 实现用户/权限同步机制
4. 处理数据范围变量映射

---

## 📊 十、AI 功能对照表

| 功能领域 | 功能点 | 技术实现 | 状态 |
|----------|--------|----------|------|
| **智能创建** | 对话式创建线索 | MaxKB + MCP | ✅ 已实现 |
| **智能创建** | 对话式创建客户 | MaxKB + MCP | ✅ 已实现 |
| **智能创建** | 对话式创建商机 | MaxKB + MCP | ✅ 已实现 |
| **智能创建** | 对话式创建联系人 | MaxKB + MCP | ✅ 已实现 |
| **智能录入** | 跟进记录智能填写 | MaxKB | ✅ 已实现 |
| **智能查重** | 客户/线索重复检测 | MCP + 搜索服务 | ✅ 已实现 |
| **智能问数** | 自然语言查询数据 | SQLBot | ✅ 已实现 |
| **数据可视化** | 销售仪表盘 | DataEase | ✅ 已实现 |
| **自动化** | 商机自动关闭规则 | 规则引擎 | ✅ 已实现 |
| **自动化** | 线索/客户自动回收 | 规则引擎 | ✅ 已实现 |
| **全局搜索** | 跨模块统一搜索 | 搜索服务 | ✅ 已实现 |
| **消息通知** | 企业微信/钉钉/飞书 | 平台集成 | ✅ 已实现 |

---

## 📚 相关资源

- **MaxKB 智能体平台**: https://github.com/1Panel-dev/MaxKB
- **SQLBot 智能问数**: https://github.com/dataease/SQLBot
- **DataEase BI 工具**: https://github.com/dataease/dataease
- **Cordys CRM 文档**: https://cordys.cn/docs/

---

*本文档详细梳理了 Cordys CRM 的 AI 驱动能力，供开发者了解和扩展使用。*

