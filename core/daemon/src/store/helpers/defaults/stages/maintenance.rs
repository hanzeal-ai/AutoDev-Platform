use super::super::super::super::StageDefaults;
use super::super::super::super::StageDownloadDefaults;
use serde_json::json;

pub(in crate::store::helpers::defaults) fn maintenance() -> StageDefaults {
    StageDefaults {
        objective: "监控运行健康并沉淀下一轮优化建议",
        input_contexts: vec![
            "运行健康：待补充",
            "问题反馈：待补充",
            "已处理问题：待补充",
            "风险信号：待补充",
            "下一轮优化建议：待补充",
        ],
        step_progress: json!([
            {"title":"问题上报","status":"running"},
            {"title":"修复完成","status":"queued"},
            {"title":"建议生成","status":"queued"}
        ]),
        risk_items: vec!["运行异常", "反馈集中", "质量回落"],
        event_flow: vec!["问题上报", "修复完成", "维护观察"],
        primary_action: "记录问题",
        secondary_actions: vec!["触发新立项", "归档项目"],
        downloads: vec![
            StageDownloadDefaults {
                id: "maintenance-log",
                title: "维护记录",
                category: "audit_archive",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "follow-up-backlog",
                title: "下一轮优化建议",
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
