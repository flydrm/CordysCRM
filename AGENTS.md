# Cordys CRM AI 开发指南

## 📋 项目概述

**Cordys CRM** 是新一代开源 AI CRM 系统，是集信息化、数字化、智能化于一体的「客户关系管理系统」，由飞致云出品。系统能够帮助企业实现从线索到回款（L2C）的全流程精细化管理。

### 核心定位
- **Cordys** [/ˈkɔːrdɪs/] = "Cord"（连接之绳）+ "System"（系统）
- 寓意"关系的纽带系统"，连接客户，缔造长期价值

### 核心优势
1. **灵活易用**：现代化技术栈，支持企业微信/钉钉/飞书集成
2. **安全可控**：私有化部署，数据主权完全自主
3. **AI 加持**：开放 MCP Server，集成 MaxKB 智能体
4. **BI 加持**：融合 DataEase 与 SQLBot，实现智能数据分析

---

## 🏗️ 技术架构

### 技术栈

| 层级 | 技术 |
|------|------|
| 后端框架 | Spring Boot 3.5.7 + Java 21 |
| 前端框架 | Vue 3 + TypeScript + Vite |
| Web UI | Naive-UI |
| Mobile UI | Vant-UI |
| 数据库 | MySQL |
| 缓存 | Redis + Redisson |
| 安全认证 | Apache Shiro |
| ORM | MyBatis |
| 数据库迁移 | Flyway |
| AI 能力 | MaxKB 智能体 |
| BI 能力 | DataEase + SQLBot |

### 项目结构

```
CordysCRM/
├── backend/                    # 后端模块
│   ├── framework/              # 基础框架模块
│   │   ├── aop/               # AOP 切面（日志记录等）
│   │   ├── common/            # 公共组件（异常、分页、响应等）
│   │   ├── mybatis/           # MyBatis 增强
│   │   ├── file/              # 文件处理
│   │   └── security/          # 安全模块
│   ├── crm/                    # CRM 业务模块
│   │   ├── clue/              # 线索管理
│   │   ├── customer/          # 客户管理
│   │   ├── opportunity/       # 商机管理
│   │   ├── contract/          # 合同管理
│   │   ├── product/           # 产品管理
│   │   ├── follow/            # 跟进管理
│   │   ├── dashboard/         # 仪表盘
│   │   ├── home/              # 首页
│   │   ├── search/            # 搜索模块
│   │   ├── system/            # 系统管理
│   │   └── integration/       # 第三方集成
│   │       ├── agent/         # AI 智能体
│   │       ├── dataease/      # DataEase BI
│   │       ├── sqlbot/        # SQLBot 问数
│   │       ├── dingtalk/      # 钉钉集成
│   │       ├── lark/          # 飞书集成
│   │       └── wecom/         # 企业微信集成
│   └── app/                    # 应用启动模块
├── frontend/                   # 前端工程（Monorepo）
│   └── packages/
│       ├── lib-shared/        # 公共库
│       │   ├── api/           # API 封装
│       │   ├── enums/         # 枚举定义
│       │   ├── hooks/         # 组合式函数
│       │   ├── locale/        # 国际化
│       │   ├── method/        # 工具方法
│       │   └── models/        # 数据模型
│       ├── web/               # Web 端项目
│       └── mobile/            # 移动端项目
└── installer/                  # 安装部署
    ├── Dockerfile
    └── mcp/                   # MCP Server 配置
```

---

## 🎯 核心业务模块

### 1. 线索管理 (Clue/Lead)

**路径**: `backend/crm/src/main/java/cn/cordys/crm/clue/`  
**API前缀**: `/lead`

#### 核心功能
| 功能 | API 端点 | 权限 |
|------|----------|------|
| 线索列表 | `POST /lead/page` | CLUE_MANAGEMENT:READ |
| 线索详情 | `GET /lead/get/{id}` | CLUE_MANAGEMENT:READ |
| 添加线索 | `POST /lead/add` | CLUE_MANAGEMENT:ADD |
| 更新线索 | `POST /lead/update` | CLUE_MANAGEMENT:UPDATE |
| 删除线索 | `GET /lead/delete/{id}` | CLUE_MANAGEMENT:DELETE |
| 转为客户 | `POST /lead/transition/account` | CUSTOMER_MANAGEMENT:ADD |
| 批量转移 | `POST /lead/batch/transfer` | CLUE_MANAGEMENT:UPDATE |
| 移入线索池 | `POST /lead/to-pool` | CLUE_MANAGEMENT:RECYCLE |
| 导入导出 | `/lead/import`, `/lead/export` | CLUE_MANAGEMENT:IMPORT/EXPORT |

#### 关键服务类
- `ClueService`: 线索核心业务逻辑
- `ClueExportService`: 线索导出服务
- `ClueController`: 线索 REST API 控制器

#### 线索状态流转
```
新建线索 → 跟进中 → 转为客户
                  ↓
              移入线索池 → 领取/分配 → 重新跟进
```

### 2. 客户管理 (Customer/Account)

**路径**: `backend/crm/src/main/java/cn/cordys/crm/customer/`  
**API前缀**: `/account`

#### 核心功能
| 功能 | API 端点 | 权限 |
|------|----------|------|
| 客户列表 | `POST /account/page` | CUSTOMER_MANAGEMENT:READ |
| 客户详情 | `GET /account/get/{id}` | CUSTOMER_MANAGEMENT:READ |
| 添加客户 | `POST /account/add` | CUSTOMER_MANAGEMENT:ADD |
| 更新客户 | `POST /account/update` | CUSTOMER_MANAGEMENT:UPDATE |
| 删除客户 | `GET /account/delete/{id}` | CUSTOMER_MANAGEMENT:DELETE |
| 客户合并 | `POST /account/merge` | CUSTOMER_MANAGEMENT:MERGE |
| 移入公海 | `POST /account/to-pool` | CUSTOMER_MANAGEMENT:RECYCLE |

#### 子模块
- **联系人管理** (`CustomerContactController`): 客户联系人 CRUD
- **协作管理** (`CustomerCollaborationController`): 团队协作
- **关系管理** (`CustomerRelationController`): 客户关系网络
- **公海池** (`CustomerPoolController`): 公海客户管理

### 3. 商机管理 (Opportunity)

**路径**: `backend/crm/src/main/java/cn/cordys/crm/opportunity/`  
**API前缀**: `/opportunity`

#### 核心功能
| 功能 | API 端点 | 权限 |
|------|----------|------|
| 商机列表 | `POST /opportunity/page` | OPPORTUNITY_MANAGEMENT:READ |
| 商机详情 | `GET /opportunity/get/{id}` | OPPORTUNITY_MANAGEMENT:READ |
| 添加商机 | `POST /opportunity/add` | OPPORTUNITY_MANAGEMENT:ADD |
| 更新商机 | `POST /opportunity/update` | OPPORTUNITY_MANAGEMENT:UPDATE |
| 删除商机 | `GET /opportunity/delete/{id}` | OPPORTUNITY_MANAGEMENT:DELETE |
| 更新阶段 | `POST /opportunity/update/stage` | OPPORTUNITY_MANAGEMENT:UPDATE |
| 商机统计 | `POST /opportunity/statistic` | OPPORTUNITY_MANAGEMENT:READ |
| 看板排序 | `POST /opportunity/sort` | - |

#### 商机阶段管理
- `OpportunityStageController`: 商机阶段配置
- `OpportunityRuleController`: 商机规则配置
- `OpportunityQuotationController`: 报价单管理

### 4. 合同管理 (Contract)

**路径**: `backend/crm/src/main/java/cn/cordys/crm/contract/`  
**API前缀**: `/contract`

#### 核心功能
- 合同创建、编辑、归档
- 合同作废与审核流程
- 回款计划管理

### 5. 产品管理 (Product)

**路径**: `backend/crm/src/main/java/cn/cordys/crm/product/`

#### 核心功能
- 产品目录管理
- 产品价格管理
- 产品导入

### 6. 跟进管理 (Follow)

**路径**: `backend/crm/src/main/java/cn/cordys/crm/follow/`

#### 核心功能
- 跟进记录 (FollowRecord): 记录客户沟通历史
- 跟进计划 (FollowPlan): 计划下次跟进安排

---

## 🤖 AI 智能体集成

### MCP Server 支持

**路径**: `backend/crm/src/main/java/cn/cordys/crm/integration/agent/`

Cordys CRM 支持通过 MCP 进行：
- 智能创建（线索/客户/商机/联系人）
- 智能录入（跟进记录）
- 智能查重

### MaxKB 集成

**核心服务**: `AgentBaseService`

```java
// 智能体管理 API
POST /agent/add          # 添加智能体
POST /agent/update       # 更新智能体
GET  /agent/get/{id}     # 智能体详情
POST /agent/list         # 智能体列表
GET  /agent/workspace    # 获取工作空间
GET  /agent/application/{workspaceId}  # 获取应用列表
POST /agent/script       # 获取脚本信息
```

### 配置说明
智能体配置需要：
- MaxKB 地址 (`mkAddress`)
- 应用密钥 (`appSecret`)
- 工作空间 ID (`workspaceId`)
- 应用 ID (`applicationId`)

---

## 🔐 权限系统

### 权限配置文件
**路径**: `backend/crm/src/main/resources/permission.json`

### 权限模块
| 模块 | 权限前缀 | 说明 |
|------|----------|------|
| 系统管理 | SYS_*, SYSTEM_* | 组织、角色、设置 |
| 线索管理 | CLUE_MANAGEMENT:* | 线索、线索池 |
| 客户管理 | CUSTOMER_MANAGEMENT:* | 客户、公海、联系人 |
| 商机管理 | OPPORTUNITY_MANAGEMENT:* | 商机、报价单 |
| 产品管理 | PRODUCT_MANAGEMENT:* | 产品、价格 |
| 合同管理 | CONTRACT:* | 合同 |
| 仪表盘 | DASHBOARD:* | 仪表盘 |
| 智能体 | AGENT:* | AI 智能体 |

### 数据权限
通过 `DataScopeService` 实现：
- 本人数据
- 部门数据
- 部门及下级数据
- 全部数据

---

## 🗄️ 数据库设计

### 数据库迁移
**路径**: `backend/crm/src/main/resources/migration/`

使用 Flyway 管理数据库版本，命名规则：
```
V{版本号}_{序号}__{描述}.sql
例如：V1.0.0_1__init.sql
```

### 核心表结构（概览）

| 业务模块 | 核心表 |
|----------|--------|
| 线索 | clue, clue_field_value, clue_pool |
| 客户 | customer, customer_field_value, customer_contact |
| 商机 | opportunity, opportunity_field_value, opportunity_stage |
| 产品 | product, product_price |
| 合同 | contract, contract_payment_plan |
| 跟进 | follow_record, follow_plan |
| 系统 | user, department, role, permission |

### 字段扩展设计
系统采用 **自定义字段** 方案：
- 主表存储固定字段
- `*_field_value` 表存储自定义字段值
- 通过 `ModuleFormCacheService` 获取表单配置

---

## 🌐 前端开发指南

### 项目初始化
```bash
cd frontend/packages
pnpm i -w
npm run build
```

### 开发命令
```bash
# Web 端开发
cd frontend/packages/web
npm run dev

# Mobile 端开发
cd frontend/packages/mobile
npm run dev
```

### API 模块结构
**路径**: `frontend/packages/lib-shared/api/modules/`

| 模块文件 | 业务领域 |
|----------|----------|
| clue.ts | 线索相关 API |
| customer.ts | 客户相关 API |
| opportunity.ts | 商机相关 API |
| contract.ts | 合同相关 API |
| product.ts | 产品相关 API |
| follow.ts | 跟进相关 API |
| agent.ts | 智能体相关 API |
| dashboard.ts | 仪表盘 API |
| system/ | 系统管理 API |

### 关键前端模式

#### API 封装模式
```typescript
export default function useProductApi(CDR: CordysAxios) {
  function addClue(data: SaveClueParams) {
    return CDR.post({ url: AddClueUrl, data });
  }
  // ...更多方法
  return { addClue, /* ... */ };
}
```

#### 表单配置获取
```typescript
// 获取模块表单配置
function getClueFormConfig() {
  return CDR.get<FormDesignConfigDetailParams>({ url: GetClueFormConfigUrl });
}
```

---

## 🛠️ 开发规范

### 后端开发规范

#### 1. Controller 规范
```java
@RestController
@Tag(name = "模块名称")
@RequestMapping("/api-prefix")
public class XxxController {
    
    @PostMapping("/action")
    @RequiresPermissions(PermissionConstants.XXX_READ)
    @Operation(summary = "接口描述")
    public ResponseType method(@Validated @RequestBody RequestType request) {
        return service.method(request, userId, orgId);
    }
}
```

#### 2. Service 规范
```java
@Service
@Transactional(rollbackFor = Exception.class)
public class XxxService {
    
    @OperationLog(module = LogModule.XXX, type = LogType.ADD)
    public Entity add(Request request, String userId, String orgId) {
        // 业务逻辑
        // 日志上下文设置
        OperationLogContext.setContext(LogContextInfo.builder()
            .resourceId(id)
            .resourceName(name)
            .modifiedValue(entity)
            .build());
        return entity;
    }
}
```

#### 3. 操作日志注解
```java
@OperationLog(
    module = LogModule.CUSTOMER,
    type = LogType.UPDATE,
    resourceId = "{#request.id}"
)
```

### 前端开发规范

#### 1. 组合式 API 模式
```typescript
// 使用 hooks 组织逻辑
const { clueApi } = useApi();
const { loading, data } = useRequest(() => clueApi.getClueList(params));
```

#### 2. 类型定义
```typescript
// 在 models 目录定义类型
export interface ClueListItem {
  id: string;
  name: string;
  // ...
}
```

---

## 🔨 常见开发场景

### 1. 添加新的业务模块

**后端步骤**:
1. 在 `backend/crm/src/main/java/cn/cordys/crm/` 创建模块目录
2. 创建子目录：`controller/`, `service/`, `domain/`, `dto/`, `mapper/`
3. 添加数据库迁移脚本
4. 在 `permission.json` 添加权限配置
5. 在 `ModuleKey.java` 添加模块键

**前端步骤**:
1. 在 `lib-shared/api/requrls/` 添加 URL 定义
2. 在 `lib-shared/api/modules/` 添加 API 模块
3. 在 `lib-shared/models/` 添加类型定义
4. 创建视图页面

### 2. 添加自定义字段支持

1. 确保实体继承 `BaseModel`
2. 创建 `*FieldValue` 实体
3. 实现 `BaseResourceFieldService` 接口
4. 在表单配置中定义字段

### 3. 集成新的第三方服务

1. 在 `integration/` 创建服务目录
2. 实现认证和 API 调用
3. 在 `OrganizationConfigConstants` 添加配置类型
4. 实现配置管理

---

## 🧪 测试指南

### 测试配置
**路径**: `backend/crm/src/test/resources/`

```properties
# application.properties
# 使用真实配置，不使用 mock
```

### 测试容器
项目使用 TestContainers：
- `embedded-mysql`: MySQL 测试容器
- `embedded-redis`: Redis 测试容器

### 运行测试
```bash
cd backend
./mvnw test
```

---

## 📦 构建与部署

### 构建命令

```bash
# 安装父 POM
./mvnw install -N

# 构建后端
./mvnw clean install -DskipTests -DskipAntRunForJenkins --file backend/pom.xml

# 构建前端
cd frontend/packages
pnpm i -w
npm run build

# 完整打包
./mvnw clean package
```

### Docker 部署

```bash
docker run -d \
  --name cordys-crm \
  --restart unless-stopped \
  -p 8081:8081 \
  -p 8082:8082 \
  -v ~/cordys:/opt/cordys \
  1panel/cordys-crm
```

### 默认访问
- URL: `http://<服务器IP>:8081/`
- 用户名: `admin`
- 密码: `CordysCRM`

---

## 📚 相关资源

- **在线文档**: https://cordys.cn/docs/
- **GitHub**: https://github.com/1Panel-dev/CordysCRM
- **AI 智能体平台**: [MaxKB](https://github.com/1Panel-dev/MaxKB)
- **BI 工具**: [DataEase](https://github.com/dataease/dataease)
- **智能问数**: [SQLBot](https://github.com/dataease/SQLBot)

---

## 🔄 版本路线

- ✅ v1.0 - v1.3: 基础 CRM 功能
- ✅ v1.2.0: MCP Server 开放
- ✅ v1.3.0: 代码正式开源
- 🔜 v1.4.0: 合同模块完善（包括发票和回款）

---

## ⚠️ 开发注意事项

1. **数据权限**: 所有业务查询需通过 `DataScopeService` 获取数据权限
2. **多组织**: 使用 `OrganizationContext.getOrganizationId()` 获取当前组织
3. **用户上下文**: 使用 `SessionUtils.getUserId()` 获取当前用户
4. **国际化**: 使用 `Translator.get("key")` 进行国际化
5. **操作日志**: 重要操作需添加 `@OperationLog` 注解
6. **权限控制**: 使用 `@RequiresPermissions` 进行接口权限控制
7. **表单校验**: 使用 `@Validated` 进行请求参数校验

---

*本文档由 AI 自动生成，供 AI 辅助二次开发使用。如有疑问请参考源代码或官方文档。*

