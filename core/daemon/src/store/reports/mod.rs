mod chat;
mod draft;
mod file;
pub(crate) mod llm;
mod update;

use super::{Store, StoreResult};
use serde_json::Value;

impl Store {
    pub(super) fn thread_report_draft(&self, thread_id: &str) -> StoreResult<Value> {
        draft::load_thread_report_draft(self, thread_id)
    }

    pub(super) fn update_report_from_patch(
        &self,
        thread_id: &str,
        patch: &Value,
        now: i64,
    ) -> StoreResult<()> {
        update::update_report_from_patch(self, thread_id, patch, now)
    }

    pub(super) fn generate_clarification_turn(
        &self,
        thread_id: &str,
        user_message: &str,
    ) -> StoreResult<chat::ClarificationTurn> {
        chat::generate_clarification_turn(self, thread_id, user_message)
    }

    pub(super) fn generate_final_report(&self, thread_id: &str) -> StoreResult<Value> {
        if !llm::worker::worker_available() {
            return Err(
                "AI Worker 不可用，无法生成报告。请确保 Python AI Worker 正在运行。".to_string(),
            );
        }
        let draft = self.thread_report_draft(thread_id)?;
        let messages: Vec<Value> = llm::list_recent_messages(self, thread_id, llm::MAX_CONTEXT_MESSAGES)?
            .iter()
            .map(|m| serde_json::to_value(m).unwrap_or_default())
            .collect();
        let materials: Vec<Value> = llm::list_recent_materials(self, thread_id, llm::MAX_CONTEXT_MATERIALS)?
            .iter()
            .map(|m| serde_json::to_value(m).unwrap_or_default())
            .collect();
        llm::worker::request_report_generation(thread_id, &draft, &messages, &materials)
    }

    pub(super) fn persist_report(
        &self,
        thread_id: &str,
        report: &Value,
        now: i64,
    ) -> StoreResult<()> {
        update::persist_report(self, thread_id, report, now)
    }
}
