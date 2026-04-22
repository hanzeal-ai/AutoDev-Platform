use super::super::super::helpers::to_json_string;
use super::super::{SeedFiles, SeedIds};
use crate::store::{Store, StoreResult};
use rusqlite::params;
use uuid::Uuid;

pub(super) fn insert_thread_records(
    store: &Store,
    ids: &SeedIds,
    seed_files: &SeedFiles,
    now: i64,
) -> StoreResult<()> {
    insert_creation_thread(store, ids, now)?;
    insert_feasibility_report(store, ids, seed_files, now)?;
    insert_creation_messages(store, ids, now)?;
    Ok(())
}

fn insert_creation_thread(store: &Store, ids: &SeedIds, now: i64) -> StoreResult<()> {
    store
        .conn
        .execute(
            r#"
INSERT INTO creation_threads (
  id, title, is_archived, linked_project_id, lifecycle_stage, last_updated_ms, created_at_ms
) VALUES (?1, ?2, 0, ?3, ?4, ?5, ?6)
"#,
            params![
                ids.thread_id,
                "新建线程 #01",
                ids.project_id,
                "feasibility",
                now,
                now
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn insert_feasibility_report(
    store: &Store,
    ids: &SeedIds,
    seed_files: &SeedFiles,
    now: i64,
) -> StoreResult<()> {
    store
        .conn
        .execute(
            r#"
INSERT INTO feasibility_reports (
  thread_id, project_name, problem_definition, target_users, core_capabilities_json,
  risks_constraints_json, delivery_plan_json, feasibility_conclusion, version, report_file_path, updated_at_ms
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 'v0.1', ?9, ?10)
"#,
            params![
                ids.thread_id,
                "AutoDev Delivery Control",
                "需求到交付之间链路割裂，缺少持续推进机制。",
                "独立开发者、小型软件团队",
                to_json_string(&vec![
                    "项目生命周期托管与状态追踪",
                    "AI 对话式立项与范围澄清",
                    "阻塞识别与待介入事项编排"
                ]),
                to_json_string(&vec!["首版需控制范围", "资源预算需设定上限"]),
                to_json_string(&vec![
                    "先交付立项到阶段详情闭环",
                    "再接入自动推进和风险治理"
                ]),
                "可行，建议进入受控立项。",
                seed_files.report_file.display().to_string(),
                now
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn insert_creation_messages(store: &Store, ids: &SeedIds, now: i64) -> StoreResult<()> {
    for (role, content) in [
        ("ai", "我先复述你的方向：这是托管交付系统，不是 IDE，对吗？"),
        ("user", "对，系统要并行推进多个项目并覆盖全生命周期。"),
        (
            "ai",
            "建议首版先聚焦立项到阶段详情闭环，再逐步扩展自动化深度。",
        ),
    ] {
        store
            .conn
            .execute(
                "INSERT INTO creation_messages (id, thread_id, role, content, created_at_ms) VALUES (?1, ?2, ?3, ?4, ?5)",
                params![Uuid::new_v4().to_string(), ids.thread_id, role, content, now],
            )
            .map_err(|err| err.to_string())?;
    }
    Ok(())
}
