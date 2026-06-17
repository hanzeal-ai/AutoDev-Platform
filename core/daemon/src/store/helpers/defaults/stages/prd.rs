use super::super::super::super::StageDefaults;
use super::super::super::super::StageDownloadDefaults;
use serde_json::json;

pub(in crate::store::helpers::defaults) fn prd() -> StageDefaults {
    StageDefaults {
        objective: "冻结 PRD 范围边界、功能拆分与验收标准",
        input_contexts: vec![
            "范围内：总览、项目库、立项线程、阶段详情",
            "范围外：多人协作、外部插件市场",
            "核心场景：立项确认后进入阶段托管推进",
            "待确认点：验收口径是否包含回归基线",
        ],
        step_progress: json!([
            {"title":"范围收敛","status":"running"},
            {"title":"功能拆分","status":"running"},
            {"title":"验收标准冻结","status":"awaiting_confirmation"}
        ]),
        risk_items: vec!["范围膨胀", "需求不完整", "依赖未确认"],
        event_flow: vec!["PRD 生成", "PRD 调整", "用户确认"],
        downloads: vec![StageDownloadDefaults {
            id: "prd-snapshot",
            title: "PRD 快照",
            category: "stage_snapshot",
            availability: "pending",
            file_path: None,
            updated_at_ms: None,
            content_type: Some("text/markdown"),
        }],
        work_units: vec![],
    }
}
