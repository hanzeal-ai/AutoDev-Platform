use super::super::super::helpers::to_json_string;
use super::super::SeedIds;
use crate::store::{Store, StoreResult};
use rusqlite::params;
use serde_json::json;

pub(super) fn insert_project_records(store: &Store, ids: &SeedIds, now: i64) -> StoreResult<()> {
    insert_project(store, ids, now)?;
    insert_project_stage(store, ids, now)?;
    Ok(())
}

fn insert_project(store: &Store, ids: &SeedIds, now: i64) -> StoreResult<()> {
    store
        .conn
        .execute(
            r#"
INSERT INTO projects (
  id, title, current_phase, lifecycle_stage, progress, current_goal, next_action,
  risk, block_reason, status, owner, updated_at_ms, created_at_ms
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)
"#,
            params![
                ids.project_id,
                "AutoDev Delivery Control",
                "立项",
                "feasibility",
                0.18_f64,
                "完成可行性报告并确认是否进入 PRD",
                "确认立项",
                "medium",
                Option::<String>::None,
                "awaiting_confirmation",
                "系统代理",
                now,
                now
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn insert_project_stage(store: &Store, ids: &SeedIds, now: i64) -> StoreResult<()> {
    let stage_inputs = vec![
        "一句话概述：托管软件开发全生命周期并可并行推进多个项目",
        "问题定义：需求到交付链路割裂，阻塞发现与处理滞后",
        "目标用户：独立开发者、小型软件团队",
        "当前立项结论：可行，建议进入受控立项",
    ];
    let stage_steps = vec![
        json!({"title":"需求澄清","status":"completed"}),
        json!({"title":"资料分析","status":"running"}),
        json!({"title":"立项确认","status":"awaiting_confirmation"}),
    ];
    let stage_risks = vec!["范围膨胀风险", "预算约束尚未冻结", "验收口径待确认"];
    let stage_events = vec!["需求挖掘完成", "可行性草稿更新", "等待立项确认"];

    store
        .conn
        .execute(
            r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json,
  downloads_json, work_units_json, updated_at_ms
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
"#,
            params![
                &ids.project_id,
                "feasibility",
                "完成可行性判断并形成受控立项决策",
                to_json_string(&stage_inputs),
                to_json_string(&stage_steps),
                to_json_string(&stage_risks),
                to_json_string(&stage_events),
                "确认立项",
                to_json_string(&vec!["继续讨论", "补充资料"]),
                "[]",
                "[]",
                now
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}
