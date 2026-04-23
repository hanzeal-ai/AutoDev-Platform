use super::super::{Store, StoreResult};

pub(super) enum ProjectCountFilter {
    All,
    Active,
    Blocked,
    Completed,
    Queued,
    Awaiting,
}

impl Store {
    pub(super) fn count_projects(&self, filter: ProjectCountFilter) -> StoreResult<i64> {
        let sql = match filter {
            ProjectCountFilter::All => "SELECT COUNT(*) FROM projects",
            ProjectCountFilter::Active => "SELECT COUNT(*) FROM projects WHERE status IN ('running','queued','awaiting_confirmation','blocked','failed')",
            ProjectCountFilter::Blocked => "SELECT COUNT(*) FROM projects WHERE status IN ('blocked','failed')",
            ProjectCountFilter::Completed => "SELECT COUNT(*) FROM projects WHERE status IN ('completed')",
            ProjectCountFilter::Queued => "SELECT COUNT(*) FROM projects WHERE status IN ('queued')",
            ProjectCountFilter::Awaiting => "SELECT COUNT(*) FROM projects WHERE status IN ('awaiting_confirmation')",
        };

        self.conn
            .query_row(sql, [], |row| row.get(0))
            .map_err(|err| err.to_string())
    }
}
