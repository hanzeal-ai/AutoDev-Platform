# Structured Content: AI-AutoDev-Platform 架构

## Title

AI-AutoDev-Platform — Mac 原生 AI 软件交付平台架构全解析

## Learning Objectives

1. 掌握三层运行时拓扑（Swift App / Rust Daemon / Python AI Worker）
2. 理解 HTTP RPC 协议设计（信封模式、流式与单次请求）
3. 了解 AI 请求管线（SSE 流式、LangGraph 图、DeepSeek API）
4. 理解软件交付全生命周期阶段及其数据流转

---

## Diagram 1 — 系统运行时拓扑

### Title: 三层运行时架构

### Key Concept

所有业务逻辑归 Rust Daemon 所有；UI 仅负责展示与状态管理；AI 能力外包给 Python Worker。

### Sections

**Layer 1: macOS App (Swift/SwiftUI)**

- SwiftUI Views + MVVM (ShellViewModel / ShellViewState)
- DaemonClient — HTTP RPC 客户端
- AsyncStream — 流式事件消费
- 运行在主进程，不做业务逻辑

**Layer 2: Rust Core Daemon**

- HTTP RPC 服务器（默认 `http://127.0.0.1:7373`，服务端部署可配置绑定地址）
- Router → dispatch_query / dispatch_command 分支
- Store — SQLite WAL 模式（projects / threads / messages / reports / artifacts / events）
- AI Worker 客户端（HTTP → localhost:9720）
- 线程安全：每请求开新 Store 连接

**Layer 3: Python AI Worker**

- FastAPI 服务（port 9720）
- LangGraph 图引擎（PRD / Development / Chat / Report 多图）
- SSE 流式端点（/generate/chat/stream）
- DeepSeek API 调用（chat + reasoning 模型）

**数据存储**

- SQLite app.db（结构化数据 + 事件溯源）
- blobs/（材料文件 + 阶段产物）

**HTTP RPC 协议**

- 格式：普通请求为 JSON 信封，流式请求为 JSON Lines 信封（schema_version=1）
- 类型：query.*只读 / command.* 写操作 / event.* 推送
- 流式：command.add_creation_message_stream → JSON Lines delta/done/error

---

## Diagram 2 — HTTP RPC 消息流（请求-响应 + 流式）

### Title: HTTP RPC 通信流程

### Key Concept

SwiftUI 永不直接访问数据——所有读写通过 DaemonClient 经 HTTP RPC 发给 Rust Backend API。

### Sections

**普通请求-响应流程（6步）**

1. SwiftUI View 触发 ViewModel 方法（@MainActor）
2. ViewModel 调用 DaemonClientDecoding（async/await）
3. DaemonHTTPTransport 发送 `POST /rpc` JSON 信封
4. Rust HTTP Server 解析请求 → Router 分发到 dispatch_query 或 dispatch_command
5. Store 执行 SQLite 查询或写入，返回 Result<T, String>
6. 响应信封序列化为 JSON → Swift 解码 → @MainActor 更新 State

**流式请求流程（SSE）**

1. Swift 发送 command.add_creation_message_stream
2. Rust 检测到 is_streaming_command → 返回 JSON Lines 流
3. Daemon 调用 Python Worker SSE 端点（asyncio.timeout=130s）
4. Worker 从 LangGraph 接收 delta → 序列化为 JSON → 推送 event.creation_message.delta
5. Swift HTTP stream task 接收 delta → AsyncStream 推送 → UI 实时更新
6. 流结束：event.creation_message.done；异常：event.creation_message.error

**关键设计点**

- SAVEPOINT 事务：用户消息 + AI 消息原子写入，失败自动回滚
- AI 消息时间戳：取流结束时刻（非请求时刻）
- WeakScriptHandler：避免 WKWebView retain cycle

---

## Diagram 3 — 软件交付生命周期

### Title: AI 驱动的软件交付全周期

### Key Concept

平台不是一个带 AI 的聊天应用，而是一个从需求到运维的结构化执行系统。所有阶段输出都是可溯源的结构化产物。

### Sections

**阶段1：需求（Requirement）**

- 触发：用户在创建会话中描述需求
- AI 行为：AI 澄清问题（chat clarification loop）
- 输出产物：确认的 Requirement 记录

**阶段2：产品规格（PRD）**

- 触发：需求确认后，可行性评审通过
- AI 行为：LangGraph PRD 图生成完整文档
- 输出产物：PRD（目标/非目标/范围/验收标准）

**阶段3：UI 设计（Design）**

- 子步骤：page_map → interaction
- AI 行为：生成页面地图、交互规格
- 输出产物：UI stage artifacts（page-map / interaction-snapshot）

**阶段4：工程开发（Engineering）**

- 触发：设计评审通过
- AI 行为：LangGraph Development 图（任务分解 + 代码生成）
- 输出产物：开发计划、代码产物

**阶段5：测试（Testing）**

- AI 行为：测试用例生成、质量门控
- 输出产物：测试报告

**阶段6：发布（Release）**

- 输出产物：发布记录、变更日志

**阶段7：运维（Operations）**

- 监控/告警 → 反馈回 Requirement 形成闭环

**设计原则**

- 系统记录是结构化产物，而非聊天历史
- 所有状态变更都是有事件记录的
- AI 可以建议和生成，但不能绕过领域所有权或审批门控
