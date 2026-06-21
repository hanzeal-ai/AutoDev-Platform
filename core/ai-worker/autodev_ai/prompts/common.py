PROMPT_VERSION = "2026-06-16.1"

STAGE_LABELS: dict[str, str] = {
    "feasibility": "可行性",
    "prd": "PRD",
    "ui": "UI",
    "development": "研发",
    "testing": "测试",
    "release": "发布",
    "maintenance": "维护",
}


def stage_label(stage: str) -> str:
    return STAGE_LABELS.get(stage, "阶段")
