# GPT-Load 开发指南

本文档为在 GPT-Load 代码库中工作的智能编程代理提供全面的开发指南。

---

## 项目概述

GPT-Load 是一个高性能、企业级的 AI API 透明代理服务，使用 Go（后端）和 Vue 3 + TypeScript（前端）构建。该应用提供智能密钥管理、负载均衡和综合监控功能，支持多通道 AI 服务集成。

**技术栈：**
- **后端**：Go 1.23+，使用 GORM（SQLite/MySQL/PostgreSQL）、uber-go/dig 实现依赖注入、Gin 框架实现 HTTP 路由
- **前端**：Vue 3 + TypeScript、Naive UI 组件库、Vue Router、Vue I18n
- **基础设施**：Redis（可选）、Docker 支持、分布式部署能力

---

## 构建命令

### 后端（Go）

```bash
# 开发模式（带竞态检测）
make dev

# 生产构建并运行前端
make run

# 执行密钥迁移（需要参数）
make migrate-keys ARGS="--from old-key --to new-key"
make migrate-keys ARGS="--to new-key"           # 启用加密
make migrate-keys ARGS="--from current-key"     # 禁用加密

# 查看可用目标
make help

# 手动 Go 命令
go run ./main.go                                # 运行服务器
go run ./main.go migrate-keys <args>            # 运行迁移
go mod tidy                                     # 同步依赖
go build -o gpt-load                            # 二进制构建
```

### 前端（Node.js/Vue）

所有前端命令必须在 `web/` 目录下运行：

```bash
cd web

# 开发模式
npm run dev                                     # 启动开发服务器

# 生产构建
npm install && npm run build                    # 完整构建（带类型检查）

# 代码质量
npm run lint                                    # ESLint（自动修复）
npm run lint:check                              # ESLint 检查
npm run format                                  # Prettier 自动格式化
npm run format:check                            # Prettier 检查
npm run type-check                              # TypeScript 类型检查
npm run check-all                               # 完整检查：lint + format + type-check

# 维护
npm run clean                                   # 移除 dist 和 node_modules/.vite
```

### Docker

```bash
# 构建生产镜像
docker build -t gpt-load:latest .

# Docker Compose（推荐）
docker compose up -d                            # 启动服务
docker compose down                             # 停止服务
docker compose logs -f                          # 查看日志

# 在容器中执行命令
docker compose run --rm gpt-load migrate-keys --to "your-key"
```

---

## 代码规范

### 通用原则

- **代码自解释**：避免冗余注释，让代码自身说明逻辑
- **最小范围修改**：优先编辑现有文件而非创建新文件
- **实用优先**：遵循现有模式，即使不够完美
- **错误优先**：显式处理错误，提供有意义的错误信息

### Go（后端）

#### 格式与缩进
- **Go 文件使用制表符**（EditorConfig：`indent_style=tab`，`indent_size=4`）
- **其他文件使用空格**（JavaScript、TypeScript、YAML、JSON 等）
- 提交前运行 `go fmt`

#### 导入顺序
- **标准库优先**，然后是第三方包，最后是内部包
- **分组排序**：stdlib → external → internal
- **内部包使用绝对导入**：`gpt-load/internal/...`
- **第三方包使用别名**：`app_errors "gpt-load/internal/errors"`

```go
import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "time"

    "gpt-load/internal/config"
    db "gpt-load/internal/db/migrations"
    "gpt-load/internal/models"
    "gpt-load/internal/response"

    "github.com/gin-gonic/gin"
    "github.com/sirupsen/logrus"
    "go.uber.org/dig"
)
```

#### 命名规范
- **变量和函数使用驼峰命名**：`groupManager`、`GetGroupByName()`
- **导出标识符使用帕斯卡命名**：`type App struct`、`func NewApp()`
- **避免单字母变量**：循环中除外（`i`、`v`、`k`）
- **避免下划线**：`key_pool` → `keyPool`
- **保持缩写一致**：`URL` 而不是 `Url`，`API` 而不是 `Api`
- **接收器名称**：1-2 个字符（`a`、`c`、`ps`）

#### 错误处理
- **返回错误，不要日志后继续**（除非日志是最终操作）
- **使用上下文包装错误**：`fmt.Errorf("failed to load groups: %w", err)`
- **使用 `app_errors` 包中的自定义 API 错误**处理 HTTP 响应
- **调用后立即检查错误**

```go
// 正确：检查并返回上下文
group, err := ps.groupManager.GetGroupByName(groupName)
if err != nil {
    response.Error(c, app_errors.ParseDBError(err))
    return
}

// 正确：使用有意义的上下文包装
if err := a.db.AutoMigrate(&models.Group{}); err != nil {
    return fmt.Errorf("database migration failed: %w", err)
}

// 正确：用户友好的自定义 API 错误
response.Error(c, app_errors.NewAPIError(
    app_errors.ErrNoKeysAvailable,
    "No active API keys available for this group",
))
```

#### 结构体模式
- **适当使用组合的内嵌结构体**
- **逻辑分组相关字段**
- **模型结构体使用 GORM 标签**
- **使用 `dig.In`** 实现依赖注入参数

```go
type App struct {
    engine            *gin.Engine
    configManager     types.ConfigManager
    settingsManager   *config.SystemSettingsManager
    groupManager      *services.GroupManager
    // ... 其他字段
}

type AppParams struct {
    dig.In
    Engine            *gin.Engine
    ConfigManager     types.ConfigManager
    SettingsManager   *config.SystemSettingsManager
    // ... 其他依赖
}
```

#### 响应模式
- **使用 `response.Success()`** 返回成功响应
- **使用 `response.Error()`** 处理 `*app_errors.APIError` 错误
- **使用 i18n 函数**（`response.SuccessI18n`、`response.ErrorI18n`）返回本地化消息

```go
// 成功响应
response.Success(c, map[string]interface{}{
    "groups": groups,
})

// 错误响应
response.Error(c, app_errors.ErrResourceNotFound)

// 使用 i18n
response.SuccessI18n(c, "group.created", group)
```

### TypeScript/JavaScript（前端）

#### 格式与缩进
- **使用 2 空格缩进**（EditorConfig）
- **Prettier** 是默认格式化工具
- **保存时自动格式化**（VSCode 设置）

#### 导入顺序
- **使用相对导入**（配置了 `@/...` 别名的 TypeScript）
- **仅对 node_modules 使用绝对导入**
- **组织导入顺序**：React/Vue 导入 → 外部库 → 内部模块
- **显式导入类型**（不使用值时使用 `import type`）

```typescript
import type { Group, APIKey } from "@/types/models";
import { useRouter } from "vue-router";
import { ref, computed } from "vue";
import http from "@/utils/http";
import { keysApi } from "@/api/keys";
```

#### 命名规范
- **变量、函数、属性使用 camelCase**：`isLoading`、`fetchGroups()`
- **组件和类型使用 PascalCase**：`DashboardCard`、`interface GroupConfig`
- **文件名使用 kebab-case**（组件除外）：`group-manager.ts`、`GroupCard.vue`
- **常量使用 UPPER_SNAKE_CASE**：`MAX_RETRY_COUNT`、`API_BASE_URL`

#### TypeScript 最佳实践
- **函数显式声明返回类型**（尤其是导出的函数）
- **避免使用 `any`**：使用 `unknown` 或正确的类型
- **对象形状使用接口**，联合/交叉类型使用类型
- **可空属性使用 `?`**
- **使用 TypeScript 严格模式**（tsconfig 中已启用）

```typescript
interface Group {
    id: number;
    name: string;
    channel: string;
    weight?: number;        // 可选
    enabled: boolean;
}

export const getGroups = async (): Promise<Group[]> => {
    const res = await http.get<Group[]>("/groups");
    return res.data || [];
};
```

#### Vue 3 组合式 API
- **使用 `<script setup>`** 语法
- **使用 composables** 共享逻辑
- **使用 `defineProps<{...}>`** 声明属性类型
- **使用 ref** 创建响应式状态：`const count = ref(0)`

```vue
<script setup lang="ts">
import { ref, computed } from "vue";
import type { Group } from "@/types/models";

const props = defineProps<{
    group: Group;
    compact?: boolean;
}>();

const isExpanded = ref(false);
const toggle = () => isExpanded.value = !isExpanded.value;
</script>
```

---

## 编辑器配置

项目使用 EditorConfig 和 VSCode 设置强制执行一致的格式化：

**关键 VSCode 设置：**
- 保存时格式化
- ESLint 集成（保存时自动修复）
- Prettier 作为默认格式化工具
- TypeScript 自动导入
- TypeScript 相对模块说明符

**推荐的 VSCode 扩展：**
- `esbenp.prettier-vscode`
- `dbaeumer.vscode-eslint`
- `vue.volar`
- `golang.go`

---

## 项目结构

```
gpt-load/
├── main.go                          # 入口点
├── Makefile                         # 构建目标
├── go.mod / go.sum                  # Go 依赖
├── Dockerfile                       # 多阶段 Docker 构建
├── docker-compose.yml               # 容器编排
├── .env.example                     # 环境模板
├── .editorconfig                    # 编辑器配置
├── .vscode/
│   ├── settings.json               # VSCode 设置
│   └── extensions.json             # 推荐扩展
├── internal/                        # Go 包
│   ├── app/                         # 应用生命周期
│   ├── channel/                     # AI 提供商通道（OpenAI、Gemini、Claude）
│   ├── commands/                    # CLI 命令
│   ├── config/                      # 配置管理
│   ├── container/                   # 依赖注入（dig）
│   ├── db/                          # 数据库操作和迁移
│   ├── encryption/                  # 密钥加密服务
│   ├── errors/                      # 标准化错误类型
│   ├── handler/                     # HTTP 处理器
│   ├── httpclient/                  # HTTP 客户端管理
│   ├── i18n/                        # 国际化
│   ├── keypool/                     # 密钥池和管理
│   ├── middleware/                  # HTTP 中间件
│   ├── models/                      # 数据模型和 GORM 结构体
│   ├── proxy/                       # 代理服务器逻辑
│   ├── response/                    # 标准化响应助手
│   ├── router/                      # 路由定义
│   ├── services/                    # 业务逻辑服务
│   ├── store/                       # 存储抽象（Redis/内存）
│   ├── syncer/                      # 缓存同步
│   ├── types/                       # 共享类型定义
│   ├── utils/                       # 工具函数
│   └── version/                     # 版本信息
└── web/                             # Vue 3 前端
    ├── package.json
    ├── tsconfig.json
    ├── vite.config.ts
    ├── src/
    │   ├── main.ts                  # Vue 入口点
    │   ├── App.vue                  # 根组件
    │   ├── api/                     # API 客户端模块
    │   ├── assets/                  # 静态资源
    │   ├── components/              # 可复用 Vue 组件
    │   ├── locales/                 # i18n 翻译文件
    │   ├── router/                  # Vue Router 配置
    │   ├── services/                # 服务层
    │   ├── types/                   # TypeScript 类型定义
    │   ├── utils/                   # 工具函数
    │   └── views/                   # 页面组件
    └── dist/                        # 构建输出（生成）
```

---

## 数据库与配置

### 支持的数据库
- **SQLite**：默认，无需额外设置
- **MySQL**：配置 `DATABASE_DSN` 环境变量
- **PostgreSQL**：配置 `DATABASE_DSN` 环境变量

### 配置优先级（从高到低）
1. **组配置**（数据库，按组覆盖）
2. **系统设置**（数据库，热重载）
3. **环境变量**（静态，需重启）
4. **默认值**（硬编码）

### 动态配置与静态配置
- **动态**：系统设置和组配置存储在数据库中，支持热重载
- **静态**：环境变量在启动时读取，需重启生效

---

## 测试指南

**当前状态**：代码库中不存在自动化测试。

**添加测试**：
- **Go**：使用标准 `testing` 包和 `_test.go` 文件
- **前端**：使用 Vue Test Utils + Vitest（匹配 Vite 构建工具）
- **运行单个测试**：`go test -v ./internal/... -run TestName`
- **前端**：配置 npm 脚本进行定向测试

**推荐模式**：
- 工具函数和服务的单元测试
- API 端点的集成测试
- 关键用户流程的 E2E 测试

---

## 开发流程

1. **前端修改**：
   ```bash
   cd web
   npm run dev                    # 启动开发服务器（热重载）
   # 修改，预览
   npm run lint:check             # 验证代码规范
   npm run format:check           # 验证格式化
   ```

2. **后端修改**：
   ```bash
   make dev                       # 运行（带竞态检测）
   # gin-debug 模式支持自动重载
   ```

3. **完整集成**：
   ```bash
   make run                       # 构建前端 + 运行后端
   ```

4. **提交前**：
   ```bash
   # 后端
   go fmt ./...                   # 格式化 Go 代码
   go mod tidy                    # 确保依赖同步

   # 前端（web/ 目录下）
   npm run check-all              # lint + format + type-check
   ```

---

## 关键依赖与模式

### 后端模式
- **依赖注入**：uber-go/dig 容器（`container.BuildContainer()`）
- **错误处理**：集中式 `app_errors.APIError` 类型和 `response.Error()`
- **数据库**：GORM 自动迁移，多数据库支持
- **缓存**：Redis 或内存存储配合 `syncer.CacheSyncer`
- **i18n**：后端使用 Go-i18n v2，前端使用 Vue I18n

### 前端模式
- **状态管理**：Vue 响应式 API（`ref`、`computed`、`watch`）
- **API 客户端**：基于 Axios 的 `http` 工具，带类型安全包装器
- **UI 框架**：Naive UI 组件库
- **路由**：Vue Router（支持懒加载路由）
- **i18n**：Vue I18n 处理所有 UI 文本

---

## 重要说明

- **当前不存在测试文件**；修改逻辑时需谨慎
- **未找到 Cursor/Copilot 规则文件**
- **运行前必须配置环境变量**（将 `.env.example` 复制为 `.env`）
- **数据库迁移**在启动时通过 `GORM.AutoMigrate()` 自动运行
- **热重载**支持动态配置（系统设置和组配置）
- **优雅关闭**已实现，带可配置超时
- **主从架构**支持分布式部署（从节点设置 `IS_SLAVE=true`）

---

## 快速参考

| 命令 | 用途 |
|------|------|
| `make dev` | 开发模式（带竞态检测） |
| `make run` | 完整构建和运行 |
| `cd web && npm run dev` | 前端开发服务器 |
| `cd web && npm run build` | 前端生产构建 |
| `go run ./main.go migrate-keys --to "key"` | 启用加密 |
| `docker compose up -d` | 容器部署 |
