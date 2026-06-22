use super::super::super::super::Store;
use super::ProjectRow;
use serde_json::{json, Value};

pub(in crate::store::projects::detail) fn fallback_workflow_status(
    project_id: &str,
    project: &ProjectRow,
) -> Value {
    let current_step = workflow_step_from_lifecycle(&project.lifecycle_stage);
    let status = workflow_status_from_project(&project.status);
    json!({
        "workflow_id": project_id,
        "thread_id": project_id,
        "project_id": project_id,
        "project_name": project.title,
        "current_phase": project.lifecycle_stage,
        "current_step": current_step,
        "status": status,
        "awaiting_user_input": project.status == "awaiting_confirmation",
        "error": project.block_reason,
        "phases": fallback_workflow_phases(current_step, status),
        "artifacts": []
    })
}

pub(in crate::store::projects::detail) fn fallback_workflow_events(
    store: &Store,
    project_id: &str,
    project: &ProjectRow,
) -> Value {
    let status = fallback_workflow_status(project_id, project);
    let mut events = Vec::new();
    let mut stmt = match store.conn.prepare(
        r#"
SELECT id, stage, title, detail, created_at_ms
FROM (
  SELECT id, stage, title, detail, created_at_ms
  FROM stage_events
  WHERE project_id = ?1
  ORDER BY created_at_ms DESC
  LIMIT 80
)
ORDER BY created_at_ms ASC
"#,
    ) {
        Ok(stmt) => stmt,
        Err(_) => {
            return json!({
                "workflow_id": project_id,
                "thread_id": project_id,
                "project_id": project_id,
                "project_name": project.title,
                "current_phase": status["current_phase"],
                "current_step": status["current_step"],
                "status": status["status"],
                "awaiting_user_input": status["awaiting_user_input"],
                "error": status["error"],
                "events": []
            });
        }
    };
    let rows = stmt.query_map(rusqlite::params![project_id], |row| {
        Ok(json!({
            "id": row.get::<_, String>(0)?,
            "sequence": row.get::<_, i64>(4)?,
            "type": "log",
            "stage": row.get::<_, String>(1)?,
            "title": row.get::<_, String>(2)?,
            "detail": row.get::<_, String>(3)?,
            "status": "completed",
            "artifact_id": null
        }))
    });
    if let Ok(rows) = rows {
        for row in rows.flatten() {
            events.push(row);
        }
    }
    json!({
        "workflow_id": project_id,
        "thread_id": project_id,
        "project_id": project_id,
        "project_name": project.title,
        "current_phase": status["current_phase"],
        "current_step": status["current_step"],
        "status": status["status"],
        "awaiting_user_input": status["awaiting_user_input"],
        "error": status["error"],
        "events": events
    })
}

fn fallback_workflow_phases(current_step: &str, status: &str) -> Value {
    let order = [
        ("prd", "产品需求文档", "workflow-prd"),
        ("prd_review", "需求评审", "workflow-prd-review"),
        ("development", "研发计划", "workflow-development-plan"),
        ("coding", "代码生成结果", "workflow-coding"),
        ("code_review", "代码评审", "workflow-code-review"),
        ("summary", "项目完成总结", "workflow-summary"),
    ];
    let current_index = order
        .iter()
        .position(|(stage, _, _)| *stage == current_step)
        .unwrap_or(0);
    let mut phases = serde_json::Map::new();
    for (index, (stage, name, kind)) in order.iter().enumerate() {
        let phase_status = if status == "completed" || index < current_index {
            "completed"
        } else if index == current_index {
            status
        } else {
            "pending"
        };
        phases.insert(
            (*stage).to_string(),
            json!({
                "status": phase_status,
                "artifact_id": null,
                "name": name,
                "kind": kind
            }),
        );
    }
    Value::Object(phases)
}

fn workflow_step_from_lifecycle(lifecycle_stage: &str) -> &'static str {
    match lifecycle_stage {
        "feasibility" | "prd" => "prd",
        "ui" | "development" | "testing" | "release" | "maintenance" => "development",
        _ => "prd",
    }
}

fn workflow_status_from_project(status: &str) -> &'static str {
    match status {
        "completed" => "completed",
        "failed" => "failed",
        "blocked" => "blocked",
        "awaiting_confirmation" => "not_started",
        "queued" => "not_started",
        _ => "running",
    }
}
