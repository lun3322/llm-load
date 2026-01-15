# GPT-Load 密钥验证与管理功能更新说明

本文档记录了近期针对密钥验证结果保存、筛选及批量管理功能的修改内容。

## 1. 密钥验证结果保存功能

### 1.1 数据模型变更 (`internal/models/types.go`)
在 `APIKey` 结构体中新增了两个字段，用于记录最近一次验证的具体信息：
- `LastValidationStatus` (*int): 记录验证接口返回的 HTTP 状态码（如 200, 401, 429 等）。
- `LastValidationResponse` (string): 记录验证接口返回的原始纯文本响应，最大限制为 3000 字符。

### 1.2 数据库迁移 (`internal/db/migrations/`)
- 新增迁移文件 `v1_2_0_AddKeyValidationResult.go`，执行 `AutoMigrate` 以自动添加新字段。
- 在 `migration.go` 中注册了该迁移任务。

### 1.3 验证逻辑更新
- **Channel 接口**: `ChannelProxy.ValidateKey` 方法签名更新为返回 `(bool, int, string, error)`，增加了状态码和响应内容的返回。
- **具体实现**: 更新了 OpenAI、Gemini 和 Anthropic 三个通道的验证逻辑，现在它们会读取并返回验证请求的响应体（自动截断至 3000 字符）。
- **状态同步**: `KeyProvider.UpdateStatus` 方法现在支持接受状态码和响应体，并在更新数据库的同时同步更新内存/Redis 缓存中的密钥详情。
- **触发时机**:
    - 手动验证接口 (`/api/keys/validate-group`)。
    - 后台自动定时验证任务。
    - *注：正常代理请求不会记录验证结果，以确保性能。*

---

## 2. 列表筛选功能增强

### 2.1 响应内容搜索
- `GET /api/keys` 接口新增查询参数 `response_filter`。
- 支持对 `last_validation_response` 字段进行 `LIKE` 模糊匹配。
- 允许管理员通过关键词（如 "quota", "expired", "revoked"）快速定位特定问题的密钥。

---

## 3. 密钥状态与管理扩展

### 3.1 新增“弃用”状态
- **常量定义**: 在 `internal/models/types.go` 中定义了 `KeyStatusDeprecated = "deprecated"`。
- **行为逻辑**: 被标记为“弃用”的密钥会被从活跃密钥池中移除，不再参与代理转发。
- **系统兼容**: 密钥列表、导出、流式输出等接口均已同步支持 `deprecated` 状态筛选。

### 3.2 批量弃用接口 (`/api/keys/deprecate-by-filter`)
- **接口类型**: `POST`
- **功能**: 根据传入的筛选条件（组ID、当前状态、密钥关键词、验证响应关键词），将匹配到的所有密钥一次性设为 `deprecated`。
- **实时生效**: 更新数据库后会自动清除对应密钥的活跃缓存，确保弃用操作立即生效。

---

## 4. 接口总结

| 功能 | 方法 | 路径 | 主要参数 |
| :--- | :--- | :--- | :--- |
| **密钥列表 (增强)** | `GET` | `/api/keys` | `group_id`, `status`, `response_filter` |
| **批量弃用** | `POST` | `/api/keys/deprecate-by-filter` | `group_id`, `status`, `response_filter` |

---
*文档生成日期：2026-01-15*
