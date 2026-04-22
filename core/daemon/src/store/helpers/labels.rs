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

pub(in crate::store) fn stage_label(stage: &str) -> &'static str {
    match stage {
        "feasibility" => "立项",
        "prd" => "PRD",
        "ui" => "UI",
        "development" => "研发",
        "testing" => "测试",
        "release" => "发布",
        "maintenance" => "维护",
        _ => "阶段",
    }
}
