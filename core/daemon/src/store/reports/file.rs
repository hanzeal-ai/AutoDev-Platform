use super::super::helpers::{bullets, ensure_parent_dir};
use super::super::{Store, StoreResult};
use serde_json::Value;
use std::fs;
use std::path::PathBuf;

pub(super) fn write_report_file(
    store: &Store,
    thread_id: &str,
    report: &Value,
) -> StoreResult<PathBuf> {
    let report_path = store
        .paths
        .blobs_dir()
        .join("reports")
        .join(thread_id)
        .join("feasibility-report-v0.1.md");
    ensure_parent_dir(&report_path)?;

    let markdown = format!(
        "# {} 可行性报告\n\n## 问题定义\n{}\n\n## 目标用户\n{}\n\n## 核心能力\n{}\n\n## 风险与约束\n{}\n\n## 初步交付建议\n{}\n\n## 结论\n{}\n",
        text_or_default(report, "project_name", "待定义"),
        text_or_default(report, "problem_definition", "待补充"),
        text_or_default(report, "target_users", "待补充"),
        bullets(report.get("core_capabilities")),
        bullets(report.get("risks_and_constraints")),
        bullets(report.get("initial_delivery_plan")),
        text_or_default(report, "feasibility_conclusion", "待评估"),
    );
    fs::write(&report_path, &markdown)
        .map_err(|err| format!("failed to write report to {}: {}", report_path.display(), err))?;
    Ok(report_path)
}

fn text_or_default<'a>(report: &'a Value, field: &str, default: &'a str) -> &'a str {
    report.get(field).and_then(Value::as_str).unwrap_or(default)
}
