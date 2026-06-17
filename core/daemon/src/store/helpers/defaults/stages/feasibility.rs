use super::super::super::super::StageDefaults;
use super::super::super::super::StageDownloadDefaults;
use serde_json::json;

pub(in crate::store::helpers::defaults) fn feasibility() -> StageDefaults {
    StageDefaults {
        objective: "完成可行性判断并形成受控立项决策",
        input_contexts: vec![
            "一句话概述：待补充",
            "问题定义：待补充",
            "目标用户：待补充",
            "当前立项结论：待评估",
        ],
        step_progress: json!([
            {"title":"需求澄清","status":"running"},
            {"title":"资料分析","status":"queued"},
            {"title":"立项确认","status":"awaiting_confirmation"}
        ]),
        risk_items: vec!["问题定义不闭合", "关键约束未完整", "资料结论冲突"],
        event_flow: vec!["需求挖掘", "报告更新", "立项确认"],
        downloads: vec![
            StageDownloadDefaults {
                id: "feasibility-report",
                title: "可行性报告",
                category: "stage_snapshot",
                availability: "ready",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "reference-materials",
                title: "参考资料原件",
                category: "raw_input",
                availability: "view_only",
                file_path: None,
                updated_at_ms: None,
                content_type: None,
            },
        ],
        work_units: vec![],
    }
}
