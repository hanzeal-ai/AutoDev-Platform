use super::super::super::super::StageDefaults;
use super::super::super::super::StageDownloadDefaults;
use serde_json::json;

pub(in crate::store::helpers::defaults) fn release() -> StageDefaults {
    StageDefaults {
        objective: "完成发布准备、执行与回滚保障",
        input_contexts: vec![
            "版本信息：待补充",
            "发布准备：待补充",
            "检查项：待补充",
            "当前发布状态：待确认",
            "回滚条件：待补充",
            "上线窗口：待补充",
        ],
        step_progress: json!([
            {"title":"发布准备","status":"running"},
            {"title":"发布开始","status":"queued"},
            {"title":"结果确认","status":"awaiting_confirmation"}
        ]),
        risk_items: vec!["发布阻塞", "检查项未通过", "回滚风险"],
        event_flow: vec!["发布准备", "发布开始", "回滚执行"],
        downloads: vec![
            StageDownloadDefaults {
                id: "release-record",
                title: "发布记录",
                category: "audit_archive",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "rollback-archive",
                title: "回滚方案留档",
                category: "audit_archive",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
        ],
        work_units: vec![],
    }
}
