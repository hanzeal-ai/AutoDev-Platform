mod draft;
pub(crate) mod llm;

use super::{Store, StoreResult};
use serde_json::Value;

impl Store {
    pub(super) fn thread_report_draft(&self, thread_id: &str) -> StoreResult<Value> {
        draft::load_thread_report_draft(self, thread_id)
    }
}
