from autodev_ai.config import ModelConfig
from autodev_ai.llm import create_llm


class FakeChatOpenAI:
    def __init__(self, **kwargs):
        self.kwargs = kwargs


def test_create_llm_applies_shared_provider_settings(monkeypatch):
    monkeypatch.setattr("autodev_ai.llm.ChatOpenAI", FakeChatOpenAI)
    cfg = ModelConfig(api_key="test-key", base_url="https://example.test/v1", model="test-model")

    llm = create_llm(cfg, max_tokens=1800, streaming=True)

    assert llm.kwargs == {
        "model": "test-model",
        "api_key": "test-key",
        "base_url": "https://example.test/v1",
        "temperature": 0.2,
        "max_tokens": 1800,
        "streaming": True,
    }


def test_create_llm_adds_json_response_format(monkeypatch):
    monkeypatch.setattr("autodev_ai.llm.ChatOpenAI", FakeChatOpenAI)
    cfg = ModelConfig(api_key="test-key", base_url="https://example.test/v1", model="test-model")

    llm = create_llm(cfg, max_tokens=900, json_mode=True)

    assert llm.kwargs["model_kwargs"] == {"response_format": {"type": "json_object"}}
