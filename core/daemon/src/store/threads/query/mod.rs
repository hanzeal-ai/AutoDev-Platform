mod messages;
mod threads;

use super::super::{Store, StoreResult};
use serde_json::Value;

impl Store {
    pub fn list_creation_threads(&self) -> StoreResult<Value> {
        threads::list_creation_threads(self)
    }

    pub(in crate::store) fn count_threads(&self) -> StoreResult<i64> {
        threads::count_threads(self)
    }

    pub(in crate::store) fn touch_thread(&self, thread_id: &str, now: i64) -> StoreResult<()> {
        threads::touch_thread(self, thread_id, now)
    }
}
