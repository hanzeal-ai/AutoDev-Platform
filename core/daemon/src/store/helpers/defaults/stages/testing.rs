use super::super::super::super::StageDefaults;
use super::super::super::super::StageDownloadDefaults;
use serde_json::json;

pub(in crate::store::helpers::defaults) fn testing() -> StageDefaults {
    StageDefaults {
        objective: "验证质量门禁并形成发布准入结论",
        input_contexts: vec![
            "测试范围：待补充",
            "通过率：待补充",
            "失败项：待补充",
            "阻塞项：待补充",
            "回归状态：待补充",
        ],
        step_progress: json!([
            {"title":"测试启动","status":"running"},
            {"title":"失败记录","status":"queued"},
            {"title":"验收确认","status":"awaiting_confirmation"}
        ]),
        risk_items: vec!["关键失败项", "阻塞未清", "质量未达标"],
        event_flow: vec!["测试启动", "失败记录", "回归通过"],
        downloads: vec![
            StageDownloadDefaults {
                id: "test-report",
                title: "测试报告",
                category: "audit_archive",
                availability: "ready",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "acceptance-snapshot",
                title: "验收结论快照",
                category: "stage_snapshot",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
        ],
        work_units: vec![],
    }
}
