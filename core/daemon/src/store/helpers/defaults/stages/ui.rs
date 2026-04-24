use super::super::super::super::StageDefaults;
use super::super::super::super::StageDownloadDefaults;
use serde_json::json;

pub(in crate::store::helpers::defaults) fn ui() -> StageDefaults {
    StageDefaults {
        objective: "完成页面地图、交互流与关键组件定义",
        input_contexts: vec![
            "页面地图：待生成",
            "核心交互流：待生成",
            "关键组件：待生成",
            "视觉方向：简约控制台",
            "待确认设计点：待补充",
        ],
        step_progress: json!([
            {"title":"页面结构生成","status":"running"},
            {"title":"交互方案更新","status":"queued"},
            {"title":"设计确认","status":"awaiting_confirmation"}
        ]),
        risk_items: vec!["交互冲突", "信息架构不清", "视觉未定稿"],
        event_flow: vec!["页面结构生成", "交互更新", "设计确认"],
        primary_action: "跳过 UI，进入研发",
        secondary_actions: vec!["继续完善 UI"],
        downloads: vec![StageDownloadDefaults {
            id: "ui-snapshot",
            title: "UI 方案快照",
            category: "stage_snapshot",
            availability: "view_only",
            file_path: None,
            updated_at_ms: None,
            content_type: None,
        }],
        work_units: vec![],
    }
}
