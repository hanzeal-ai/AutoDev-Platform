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

#[cfg(test)]
mod tests {
    use super::*;

    fn seed_projects(store: &Store) {
        store.conn.execute_batch(
            "INSERT INTO projects (id, title, current_phase, lifecycle_stage, progress, current_goal, next_action, risk, status, owner, updated_at_ms, created_at_ms) VALUES
                ('p1', 'Project 1', 'feasibility', 'feasibility', 0.1, 'goal', 'next', 'low', 'running', 'test', 1000, 1000),
                ('p2', 'Project 2', 'prd', 'prd', 0.2, 'goal', 'next', 'low', 'completed', 'test', 2000, 2000),
                ('p3', 'Project 3', 'development', 'development', 0.5, 'goal', 'next', 'high', 'blocked', 'test', 3000, 3000),
                ('p4', 'Project 4', 'testing', 'testing', 0.7, 'goal', 'next', 'low', 'queued', 'test', 4000, 4000),
                ('p5', 'Project 5', 'release', 'release', 0.9, 'goal', 'next', 'low', 'awaiting_confirmation', 'test', 5000, 5000);"
        ).unwrap();
    }

    #[test]
    fn count_all_projects() {
        let store = Store::open_in_memory().unwrap();
        store.init_schema().unwrap();
        seed_projects(&store);
        assert_eq!(store.count_projects(ProjectCountFilter::All).unwrap(), 5);
    }

    #[test]
    fn count_active_projects() {
        let store = Store::open_in_memory().unwrap();
        store.init_schema().unwrap();
        seed_projects(&store);
        // Active = running, queued, awaiting_confirmation, blocked, failed
        assert_eq!(store.count_projects(ProjectCountFilter::Active).unwrap(), 4);
    }

    #[test]
    fn count_blocked_projects() {
        let store = Store::open_in_memory().unwrap();
        store.init_schema().unwrap();
        seed_projects(&store);
        // Blocked = blocked, failed → p3
        assert_eq!(store.count_projects(ProjectCountFilter::Blocked).unwrap(), 1);
    }

    #[test]
    fn count_completed_projects() {
        let store = Store::open_in_memory().unwrap();
        store.init_schema().unwrap();
        seed_projects(&store);
        assert_eq!(store.count_projects(ProjectCountFilter::Completed).unwrap(), 1);
    }

    #[test]
    fn count_queued_projects() {
        let store = Store::open_in_memory().unwrap();
        store.init_schema().unwrap();
        seed_projects(&store);
        assert_eq!(store.count_projects(ProjectCountFilter::Queued).unwrap(), 1);
    }

    #[test]
    fn count_awaiting_projects() {
        let store = Store::open_in_memory().unwrap();
        store.init_schema().unwrap();
        seed_projects(&store);
        assert_eq!(store.count_projects(ProjectCountFilter::Awaiting).unwrap(), 1);
    }

    #[test]
    fn count_empty_database() {
        let store = Store::open_in_memory().unwrap();
        store.init_schema().unwrap();
        assert_eq!(store.count_projects(ProjectCountFilter::All).unwrap(), 0);
    }
}
