import importlib


def test_prompt_package_exposes_stage_submodule_and_legacy_exports():
    stage_prompts = importlib.import_module("autodev_ai.prompts.stage")
    legacy_prompts = importlib.import_module("autodev_ai.prompts")

    assert stage_prompts.agent_system_prompt("prd") == legacy_prompts.agent_system_prompt("prd")
    assert stage_prompts.SYNTHESIZER_SYSTEM == legacy_prompts.SYNTHESIZER_SYSTEM


def test_prompt_package_exposes_common_stage_labels():
    common_prompts = importlib.import_module("autodev_ai.prompts.common")
    legacy_prompts = importlib.import_module("autodev_ai.prompts")

    assert common_prompts.stage_label("development") == legacy_prompts.stage_label("development")
