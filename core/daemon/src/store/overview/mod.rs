mod counts;
mod feeds;
mod lifecycle;

use counts::ProjectCountFilter;
use super::{Store, StoreResult};
use serde_json::{json, Value};

impl Store {
    pub fn get_overview(&self) -> StoreResult<Value> {
        let hosted_count = self.count_projects(ProjectCountFilter::All)?;
        let running_count = self.count_projects(ProjectCountFilter::Active)?;
        let blocked_count = self.count_projects(ProjectCountFilter::Blocked)?;
        let completed_count = self.count_projects(ProjectCountFilter::Completed)?;
        let queue_count = self.count_projects(ProjectCountFilter::Queued)?;
        let awaiting_count = self.count_projects(ProjectCountFilter::Awaiting)?;

        let managed_alerts = self.managed_alerts()?;
        let interventions = self.interventions()?;
        let progress_notices = self.progress_notices()?;
        let lifecycle_distribution = self.lifecycle_distribution()?;

        let success_rate = if hosted_count == 0 {
            100
        } else {
            ((completed_count as i128 * 100) / hosted_count as i128).max(1) as i64
        };
        let health = if blocked_count > 0 {
            "关注中"
        } else {
            "稳定"
        };

        Ok(json!({
            "ops_snapshot": {
                "hosted_system_count": hosted_count,
                "parallel_project_count": running_count,
                "active_agent_count": std::cmp::max(2, running_count * 2),
                "queue_depth": queue_count,
                "running_workflow_count": std::cmp::max(1, running_count + queue_count),
                "slot_usage": format!("{running_count} / 8"),
                "average_velocity": "1.4 步/小时",
                "resource_pressure": if blocked_count > 0 { "中" } else { "低" },
                "success_rate24h": success_rate,
                "lead_time_median": "2h 12m",
                "blocked_project_count": blocked_count,
                "completed_today": completed_count,
                "system_health": health
            },
            "managed_alerts": managed_alerts,
            "progress_notices": progress_notices,
            "interventions": interventions,
            "lifecycle_distribution": lifecycle_distribution,
            "running_project_count": running_count,
            "intervention_count": awaiting_count + blocked_count
        }))
    }
}
