mod alerts;
mod interventions;
mod notices;

use super::super::{Store, StoreResult};
use serde_json::Value;

impl Store {
    pub(super) fn managed_alerts(&self) -> StoreResult<Vec<Value>> {
        alerts::managed_alerts(self)
    }

    pub(super) fn interventions(&self) -> StoreResult<Vec<Value>> {
        interventions::interventions(self)
    }

    pub(super) fn progress_notices(&self) -> StoreResult<Vec<Value>> {
        notices::progress_notices(self)
    }
}
