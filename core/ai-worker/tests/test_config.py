import os
import pytest
from autodev_ai.config import ModelConfig, get_worker_port


class TestModelConfig:
    def test_missing_api_key_raises(self, monkeypatch):
        monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
        with pytest.raises(RuntimeError, match="DEEPSEEK_API_KEY"):
            ModelConfig.from_env()

    def test_valid_config(self, monkeypatch):
        monkeypatch.setenv("DEEPSEEK_API_KEY", "test-key")
        monkeypatch.setenv("DEEPSEEK_MODEL", "test-model")
        cfg = ModelConfig.from_env()
        assert cfg.api_key == "test-key"
        assert cfg.model == "test-model"

    def test_default_base_url(self, monkeypatch):
        monkeypatch.setenv("DEEPSEEK_API_KEY", "test-key")
        monkeypatch.delenv("DEEPSEEK_BASE_URL", raising=False)
        cfg = ModelConfig.from_env()
        assert "deepseek" in cfg.base_url

    def test_worker_port_default(self, monkeypatch):
        monkeypatch.delenv("AI_WORKER_PORT", raising=False)
        assert get_worker_port() == 9720

    def test_worker_port_custom(self, monkeypatch):
        monkeypatch.setenv("AI_WORKER_PORT", "8080")
        assert get_worker_port() == 8080
