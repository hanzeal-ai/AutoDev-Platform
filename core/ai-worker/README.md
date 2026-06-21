# AutoDev AI Worker

LangGraph + FastAPI AI 编排服务，作为 Rust Daemon 的 AI sidecar。

## 架构

```
Rust Daemon ──HTTP──▶ AI Worker (localhost:9720)
                         │
                         ├─ /workflow/start    → 统一交付 workflow 启动
                         ├─ /workflow/resume   → 统一交付 workflow 断点恢复
                         ├─ /workflow/status   → 统一交付 workflow 状态查询
                         ├─ /workflow/artifact → 按 artifact_id 查询阶段产物
                         └─ /health            → 健康检查
```

需求澄清、可行性报告、PRD、评审、研发计划、代码生成和代码评审均已收敛到
`/workflow/*`，不再暴露单步骤 `/generate/*` 接口。

## 开发

```bash
cd core/ai-worker

# 创建虚拟环境
python3 -m venv .venv
source .venv/bin/activate

# 安装依赖
pip install -e ".[dev]"

# 启动
uvicorn autodev_ai.main:app --port 9720 --reload

# 测试
pytest
```

## 环境变量

项目根目录需要创建本地 `.env` 文件。该文件包含 API key 等敏感信息，不能提交到 Git。

示例：

```bash
DEEPSEEK_API_KEY=your_deepseek_key
LANGSMITH_TRACING=true
LANGSMITH_ENDPOINT=https://api.smith.langchain.com
LANGSMITH_API_KEY=your_langsmith_key
LANGSMITH_PROJECT=autodev
```

- `DEEPSEEK_API_KEY` — DeepSeek API 密钥（必须）
- `DEEPSEEK_BASE_URL` — API 地址（默认 https://api.deepseek.com/v1）
- `DEEPSEEK_MODEL` — 模型名（默认 deepseek-chat）
- `AI_WORKER_PORT` — 监听端口（默认 9720）
- `AUTODEV_CODING_PROVIDER` — 代码实现阶段的文档驱动 provider，默认 `openspec`，可设为 `legacy`
- `AUTODEV_PROJECT_ROOT` — OpenSpec 文档写入的项目根目录，默认当前工作目录
- `AUTODEV_TOOLS_DIR` — 自动安装 Node/OpenSpec 的工具目录，默认 `~/.cache/autodev/tools`
- `AUTODEV_NODE_VERSION` — 自动安装的 Node.js 版本，默认 `v22.12.0`

## OpenSpec

代码实现阶段默认使用官方 OpenSpec Codex skill。AI Worker 会在运行时自动检查：

- Node.js 是否存在且版本不低于 20.19.0
- `@fission-ai/openspec` 是否已安装
- 项目内是否存在 `.codex/skills/openspec-*/SKILL.md`

缺失时会自动安装 Node.js、安装 OpenSpec，并在项目根目录执行：

```bash
openspec init --tools codex --profile core
```

AI Worker 在 coding graph 中读取官方 skill 指令来执行 `propose -> apply -> archive`。每个 coding task 会先写入 `openspec/changes/<change-id>/proposal.md`、`design.md`、`tasks.md`，任务完成后归档到 `openspec/changes/archive/<date>-<change-id>/`。如果后续要切换为其它文档驱动范式，可以通过 `AUTODEV_CODING_PROVIDER` 接入新的 provider。
