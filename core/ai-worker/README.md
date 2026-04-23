# AutoDev AI Worker

LangGraph + FastAPI AI 编排服务，作为 Rust Daemon 的 AI sidecar。

## 架构

```
Rust Daemon ──HTTP──▶ AI Worker (localhost:9720)
                         │
                         ├─ /generate/stage    → LangGraph 阶段编排 (SSE streaming)
                         ├─ /generate/report   → 可行性报告生成
                         └─ /health            → 健康检查
```

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

- `DEEPSEEK_API_KEY` — DeepSeek API 密钥（必须）
- `DEEPSEEK_BASE_URL` — API 地址（默认 https://api.deepseek.com/v1）
- `DEEPSEEK_MODEL` — 模型名（默认 deepseek-chat）
- `AI_WORKER_PORT` — 监听端口（默认 9720）
