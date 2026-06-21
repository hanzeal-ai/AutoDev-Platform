def test_extract_json_fallback_reads_fenced_json_object():
    from autodev_ai.json_tools import extract_json_fallback

    raw = 'before\n```json\n{"key": "value"}\n```\nafter'

    assert extract_json_fallback(raw) == {"key": "value"}


def test_extract_json_fallback_reads_balanced_object():
    from autodev_ai.json_tools import extract_json_fallback

    raw = 'prefix {"outer": {"inner": true}} suffix'

    assert extract_json_fallback(raw) == {"outer": {"inner": True}}


def test_string_list_strips_caps_and_skips_blank_values():
    from autodev_ai.text_tools import string_list

    assert string_list(["  first  ", "", "second-long"], limit=2, max_len=6) == ["first", "second"]
