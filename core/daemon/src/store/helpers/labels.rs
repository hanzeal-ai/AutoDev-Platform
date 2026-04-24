use super::super::lifecycle::LifecycleStage;
use super::time::now_ms;

pub(in crate::store) fn relative_label(ts_ms: i64) -> String {
    let delta_ms = now_ms().saturating_sub(ts_ms);
    let minute = 60_000;
    let hour = 3_600_000;
    let day = 86_400_000;

    if delta_ms < minute {
        "刚刚".to_string()
    } else if delta_ms < hour {
        format!("{} 分钟前", delta_ms / minute)
    } else if delta_ms < day {
        format!("{} 小时前", delta_ms / hour)
    } else if delta_ms < day * 2 {
        "昨天".to_string()
    } else {
        format!("{} 天前", delta_ms / day)
    }
}

pub(in crate::store) fn hhmm_label(ts_ms: i64) -> String {
    let seconds = ts_ms / 1000;
    let day_seconds = ((seconds % 86_400) + 86_400) % 86_400;
    let hour = day_seconds / 3600;
    let minute = (day_seconds % 3600) / 60;
    format!("{hour:02}:{minute:02}")
}

pub(in crate::store) fn risk_priority(risk: &str) -> &'static str {
    match risk {
        "high" => "高",
        "low" => "低",
        _ => "中",
    }
}

/// Delegate to `LifecycleStage` enum for type-safe stage labels.
pub(in crate::store) fn stage_label(stage: &str) -> &'static str {
    LifecycleStage::from_str(stage)
        .map(|s| s.label())
        .unwrap_or("阶段")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn relative_label_just_now() {
        let now = now_ms();
        assert_eq!(relative_label(now), "刚刚");
    }

    #[test]
    fn relative_label_minutes_ago() {
        let now = now_ms();
        let five_min_ago = now - 5 * 60_000;
        assert_eq!(relative_label(five_min_ago), "5 分钟前");
    }

    #[test]
    fn relative_label_hours_ago() {
        let now = now_ms();
        let two_hours_ago = now - 2 * 3_600_000;
        assert_eq!(relative_label(two_hours_ago), "2 小时前");
    }

    #[test]
    fn relative_label_yesterday() {
        let now = now_ms();
        let yesterday = now - 30 * 3_600_000;
        assert_eq!(relative_label(yesterday), "昨天");
    }

    #[test]
    fn relative_label_days_ago() {
        let now = now_ms();
        let three_days_ago = now - 3 * 86_400_000;
        assert_eq!(relative_label(three_days_ago), "3 天前");
    }

    #[test]
    fn stage_label_known_stages() {
        assert_eq!(stage_label("feasibility"), "立项");
        assert_eq!(stage_label("prd"), "PRD");
        assert_eq!(stage_label("development"), "研发");
    }

    #[test]
    fn stage_label_unknown_returns_fallback() {
        assert_eq!(stage_label("unknown"), "阶段");
    }

    #[test]
    fn risk_priority_mappings() {
        assert_eq!(risk_priority("high"), "高");
        assert_eq!(risk_priority("low"), "低");
        assert_eq!(risk_priority("medium"), "中");
        assert_eq!(risk_priority("anything"), "中");
    }

    #[test]
    fn hhmm_label_formats_correctly() {
        let ts = 45000 * 1000; // 12:30 UTC
        assert_eq!(hhmm_label(ts), "12:30");
    }

    #[test]
    fn hhmm_label_midnight() {
        assert_eq!(hhmm_label(0), "00:00");
    }

    #[test]
    fn hhmm_label_end_of_day() {
        let ts = (23 * 3600 + 59 * 60) * 1000;
        assert_eq!(hhmm_label(ts), "23:59");
    }
}
