"""Shared configuration — model provider, env vars."""

import os
from dataclasses import dataclass
from dotenv import load_dotenv

# Load .env files (project root → user config)
load_dotenv()
_user_config = os.path.expanduser("~/.config/autodev/deepseek.env")
if os.path.exists(_user_config):
    load_dotenv(_user_config)


@dataclass(frozen=True)
class ModelConfig:
    api_key: str
    base_url: str
    model: str

    @classmethod
    def from_env(cls) -> "ModelConfig":
        api_key = os.environ.get("DEEPSEEK_API_KEY", "")
        if not api_key:
            raise RuntimeError("DEEPSEEK_API_KEY is not set")
        base_url = os.environ.get(
            "DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1"
        ).rstrip("/")
        model = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")
        return cls(api_key=api_key, base_url=base_url, model=model)


def get_worker_port() -> int:
    return int(os.environ.get("AI_WORKER_PORT", "9720"))
