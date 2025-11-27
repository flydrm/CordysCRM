<h1 align="center">Cordys CRM</h1>
<h3 align="center">新一代的开源 AI CRM 系统</h3>
<p align="center">
  <a href="https://github.com/flydrm/CordysCRM/releases"><img src="https://img.shields.io/github/v/release/flydrm/CordysCRM" alt="Latest release"></a>
  <a href="https://github.com/flydrm/CordysCRM"><img src="https://img.shields.io/github/stars/flydrm/CordysCRM?color=%231890FF&style=flat-square" alt="Stars"></a>    
  <a href="https://github.com/flydrm/CordysCRM/pkgs/container/cordyscrm"><img src="https://img.shields.io/badge/ghcr.io-cordyscrm-blue?logo=github" alt="Container"></a><br/>
</p>

<hr/>

**Cordys CRM** 是新一代的开源 AI CRM 系统，是集信息化、数字化、智能化于一体的「客户关系管理系统」，由 [飞致云](https://fit2cloud.com/) 匠心出品。Cordys CRM 能够帮助企业实现从线索到回款（L2C）的全流程精细化管理，覆盖线索获取、智能分配、客户与联系人管理、商机跟进、合同签约及回款执行，构建端到端的销售运营闭环。

Cordys [/ˈkɔːrdɪs/] 由“Cord”（连接之绳）与“System”（系统）融合而成，寓意“关系的纽带系统”，诠释了 CRM 的本质：连接客户，缔造长期价值。

[![Watch the video](https://resource.fit2cloud.com/1panel/cordys-crm/img/overview-video-20251110.png)](https://www.bilibili.com/video/BV1Wm1sB4ExL/)

**Cordys CRM** 的核心优势是：

- **灵活易用**：基于现代化技术栈构建，使用体验好；平台支持基于角色的权限管控，提供灵活的模块化配置，可无缝集成企业微信、钉钉、飞书等主流办公平台，实现高效协同；
- **安全可控**：私有化部署，所有客户数据与业务信息均存储于企业自有服务器，数据主权完全自主，同时便于深度集成与二次开发；
- **AI 加持**：开放 MCP Server，借助 [MaxKB](https://github.com/1Panel-dev/MaxKB) 强大的智能体开发能力，轻松构建智能创建、智能跟进、智能报价等多样化智能体；
- **BI 加持**：融合 [DataEase](https://github.com/dataease/dataease) 与 [SQLBot](https://github.com/dataease/SQLBot) 的强大能力，实现销售数据可视化呈现、自助分析，以及基于自然语言的智能查询与归因分析。

## 🐳 Docker 镜像

| 镜像地址 | 说明 |
|---------|------|
| `ghcr.io/flydrm/cordyscrm:latest` | 最新版本 |
| `ghcr.io/flydrm/cordyscrm:main` | main 分支构建 |
| `ghcr.io/flydrm/cordyscrm:<version>` | 指定版本（如 v1.3.2） |

> 📦 镜像托管于 [GitHub Container Registry](https://github.com/flydrm/CordysCRM/pkgs/container/cordyscrm)

## 快速开始

### 安装部署

准备一台 Linux 服务器，安装好 [Docker](https://docs.docker.com/get-docker/) 后，执行以下一键安装脚本。

```bash
docker run -d \
  --name cordys-crm \
  --restart unless-stopped \
  -p 8081:8081 \
  -p 8082:8082 \
  -v ~/cordys:/opt/cordys \
  ghcr.io/flydrm/cordyscrm:latest
```

你也可以通过 [1Panel 应用商店](https://cordys.cn/docs/installation/1panel_installtion/) 来安装部署 Cordys CRM。

在无法联网的环境中，还可以通过 [离线安装包](https://cordys.cn/docs/installation/offline_installtion/) 来安装部署 Cordys CRM。

### 访问方式

- 在浏览器中打开: http://<你的服务器IP>:8081/
- 用户名: `admin`
- 密码: `CordysCRM`

### 联系我们

安装完成后，可以参考 [在线文档](https://cordys.cn/docs/) 来使用 Cordys CRM。

你可以通过下方的微信交流群，与 Cordys CRM 开源项目组进行交流和反馈。

<image height="150px" width="150px" alt="Cordys CRM QRCode" src="https://resource.fit2cloud.com/1panel/cordys-crm/img/wechat.png?v=20250904" />

## UI 展示

<table style="border-collapse: collapse; border: 1px solid black;">
  <tr>
    <td style="padding: 5px;background-color:#fff;"><img src= "https://resource.fit2cloud.com/1panel/cordys-crm/img/setting.png" alt="Settings" /></td>
    <td style="padding: 5px;background-color:#fff;"><img src= "https://resource.fit2cloud.com/1panel/cordys-crm/img/rbac.png" alt="RBAC" /></td>
  </tr>
  <tr>
    <td style="padding: 5px;background-color:#fff;"><img src= "https://resource.fit2cloud.com/1panel/cordys-crm/img/opportunity.png" alt="Opportunity List" /></td>
    <td style="padding: 5px;background-color:#fff;"><img src= "https://resource.fit2cloud.com/1panel/cordys-crm/img/opportunity-detail.png" alt="Opportunity Detail" /></td>
  </tr>
  <tr>
    <td style="padding: 5px;background-color:#fff;"><img src= "https://resource.fit2cloud.com/1panel/cordys-crm/img/bi.png" alt="BI" /></td>
    <td style="padding: 5px;background-color:#fff;"><img src= "https://resource.fit2cloud.com/1panel/cordys-crm/img/ai.png" alt="AI" /></td>
  </tr>  
</table>

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=1Panel-dev/CordysCRM&type=date&legend=top-left)](https://www.star-history.com/#1Panel-dev/CordysCRM&type=date&legend=top-left)

## Roadmap

- [x] 2024.09：写下第一行代码
- [x] 2025.06：v1.0 开发完成
- [x] 2025.07：吃自己的狗粮，成功替换飞致云使用 7 年的 Salesforce CRM
- [x] 2025.08：完成与 SQLBot 和 DataEase 的对接
- [x] 2025.08.27：[v1.1.5](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.1.5) 发布，开始公测
- [x] 2025.08.27：[v1.1.6](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.1.6) 发布
- [x] 2025.09.01：[v1.1.7](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.1.7) 发布
- [x] 2025.09.05：[v1.1.8](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.1.8) 发布
- [x] 2025.09.12：[v1.1.9](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.1.9) 发布
- [x] 2025.09.19：[v1.2.0](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.2.0) 发布，开放 MCP Server，并完成和 MaxKB 的对接
- [x] 2025.09.26：[v1.2.1](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.2.1) 发布
- [x] 2025.10.11：[v1.2.2](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.2.2) 发布
- [x] 2025.10.17：[v1.2.3](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.2.3) 发布
- [x] 2025.11.03：[v1.3.0](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.3.0) 发布，代码正式开源
- [x] 2025.11.05：[v1.3.1](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.3.1) 发布
- [x] 2025.11.14：[v1.3.2](https://github.com/1Panel-dev/CordysCRM/releases/tag/v1.3.2) 发布
- [ ] 2025.12：合同模块发布（包括合同、发票和回款等）

## 技术栈

-  AI 智能体能力：[MaxKB](https://github.com/1Panel-dev/MaxKB)
-  AI 智能问数能力：[SQLBot](https://github.com/dataease/SQLBot)
-  数据可视化能力：[DataEase](https://github.com/dataease/dataease)
-  后端：[Spring Boot](https://spring.io/projects/spring-boot)
-  前端：[Vue.js](https://vuejs.org/) 、[Naive-UI](https://www.naiveui.com/) 、[Vant-UI](https://vant-ui.github.io/)
-  中间件：[MySQL](https://www.mysql.com/) , [Redis](https://redis.com/)
-  基础设施：[Docker](https://www.docker.com/)

## 飞致云旗下的其他明星项目

- [JumpServer](https://github.com/jumpserver/jumpserver/) - 广受欢迎的开源堡垒机
- [1Panel](https://github.com/1panel-dev/1panel/) - 现代化、开源的 Linux 服务器运维管理面板
- [MaxKB](https://github.com/1panel-dev/MaxKB/) - 强大易用的企业级智能体平台
- [DataEase](https://github.com/dataease/dataease/) - 人人可用的开源 BI 工具
- [SQLBot](https://github.com/dataease/SQLBot/) - 基于大模型和 RAG 的智能问数系统
- [MeterSphere](https://github.com/metersphere/metersphere/) - 新一代的开源持续测试工具
- [Halo](https://github.com/halo-dev/halo/) - 强大易用的开源建站工具

## License

本仓库遵循 [FIT2CLOUD Open Source License](LICENSE) 开源协议，该许可证本质上是 GPLv3，但有一些额外的限制。

你可以基于 Cordys CRM 的源代码进行二次开发，但是需要遵守以下规定：

- 不能替换和修改 Cordys CRM 的 Logo 和版权信息；
- 二次开发后的衍生作品必须遵守 GPL V3 的开源义务。

如需商业授权，请联系：`support@fit2cloud.com`。
