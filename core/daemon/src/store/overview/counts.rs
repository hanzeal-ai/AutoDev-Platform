use super::super::{Store, StoreResult};

impl Store {
    pub(super) fn count_projects(&self, condition: Option<&str>) -> StoreResult<i64> {
        let sql = if let Some(condition) = condition {
            format!("SELECT COUNT(*) FROM projects WHERE {condition}")
        } else {
            "SELECT COUNT(*) FROM projects".to_string()
        };

        self.conn
            .query_row(&sql, [], |row| row.get(0))
            .map_err(|err| err.to_string())
    }
}
