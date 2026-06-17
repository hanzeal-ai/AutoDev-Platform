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
