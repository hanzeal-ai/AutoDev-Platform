mod add;
mod list;

use super::{MaterialInput, Store, StoreResult};
use serde_json::Value;

impl Store {
    pub fn add_creation_materials(
        &self,
        thread_id: &str,
        material_inputs: &[MaterialInput],
    ) -> StoreResult<Value> {
        add::add_creation_materials(self, thread_id, material_inputs)
    }

    pub(super) fn list_thread_materials(&self, thread_id: &str) -> StoreResult<Vec<Value>> {
        list::list_thread_materials(self, thread_id)
    }
}
