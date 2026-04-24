/// Project lifecycle stages — the canonical progression through which every project flows.
///
/// All stage-related logic (progression, labels, progress, goals) is centralized here
/// to eliminate string-based matching scattered across the codebase.

use super::StageDefaults;

/// The ordered lifecycle stages of a project.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub(crate) enum LifecycleStage {
    Feasibility,
    Prd,
    Ui,
    Development,
    Testing,
    Release,
    Maintenance,
}

/// All stages in lifecycle order.
#[allow(dead_code)]
pub(crate) const ALL_STAGES: &[LifecycleStage] = &[
    LifecycleStage::Feasibility,
    LifecycleStage::Prd,
    LifecycleStage::Ui,
    LifecycleStage::Development,
    LifecycleStage::Testing,
    LifecycleStage::Release,
    LifecycleStage::Maintenance,
];

impl LifecycleStage {
    /// Parse from the database/protocol string representation.
    /// Returns `None` for unrecognized values.
    pub(crate) fn from_str(s: &str) -> Option<Self> {
        match s {
            "feasibility" => Some(Self::Feasibility),
            "prd" => Some(Self::Prd),
            "ui" => Some(Self::Ui),
            "development" => Some(Self::Development),
            "testing" => Some(Self::Testing),
            "release" => Some(Self::Release),
            "maintenance" => Some(Self::Maintenance),
            _ => None,
        }
    }

    /// The database/protocol string representation.
    pub(crate) fn as_str(&self) -> &'static str {
        match self {
            Self::Feasibility => "feasibility",
            Self::Prd => "prd",
            Self::Ui => "ui",
            Self::Development => "development",
            Self::Testing => "testing",
            Self::Release => "release",
            Self::Maintenance => "maintenance",
        }
    }

    /// Chinese display label for UI.
    pub(crate) fn label(&self) -> &'static str {
        match self {
            Self::Feasibility => "立项",
            Self::Prd => "PRD",
            Self::Ui => "UI",
            Self::Development => "研发",
            Self::Testing => "测试",
            Self::Release => "发布",
            Self::Maintenance => "维护",
        }
    }

    /// The next stage in the lifecycle, or `None` if this is the final stage.
    pub(crate) fn next(&self) -> Option<Self> {
        match self {
            Self::Feasibility => Some(Self::Prd),
            Self::Prd => Some(Self::Ui),
            Self::Ui => Some(Self::Development),
            Self::Development => Some(Self::Testing),
            Self::Testing => Some(Self::Release),
            Self::Release => Some(Self::Maintenance),
            Self::Maintenance => None,
        }
    }

    /// Overall project progress when entering this stage.
    pub(crate) fn progress(&self) -> f64 {
        match self {
            Self::Feasibility => 0.08,
            Self::Prd => 0.12,
            Self::Ui => 0.28,
            Self::Development => 0.45,
            Self::Testing => 0.72,
            Self::Release => 0.9,
            Self::Maintenance => 1.0,
        }
    }

    /// The objective/goal for this stage.
    pub(crate) fn goal(&self) -> &'static str {
        match self {
            Self::Feasibility => "完成可行性判断并形成受控立项决策",
            Self::Prd => "冻结 PRD 范围边界、功能拆分与验收标准",
            Self::Ui => "完成页面地图、交互流与关键组件定义",
            Self::Development => "完成前后端任务拆分、编码审查循环与稳定预览交付",
            Self::Testing => "验证质量门禁并形成发布准入结论",
            Self::Release => "完成发布准备、执行与回滚保障",
            Self::Maintenance => "监控运行健康并沉淀下一轮优化建议",
        }
    }

    /// The next action hint displayed to the user.
    pub(crate) fn next_action(&self) -> &'static str {
        match self {
            Self::Feasibility => "确认立项",
            Self::Prd => "确认 PRD 后进入 UI 阶段",
            Self::Ui => "当前联调可跳过 UI 并进入研发阶段",
            Self::Development => "继续推进研发规划与编码准备",
            Self::Testing => "确认质量门禁后进入发布阶段",
            Self::Release => "确认发布后进入维护阶段",
            Self::Maintenance => "查看维护记录与归档",
        }
    }

    /// Stage defaults for seeding project_stages rows.
    pub(crate) fn defaults(&self) -> StageDefaults {
        crate::store::helpers::stage_defaults(self.as_str())
    }

    /// Sub-steps for this stage, if any.
    /// Returns a list of (key, label) pairs.
    /// Stages without sub-steps return an empty slice.
    pub(crate) fn sub_steps(&self) -> &'static [(&'static str, &'static str)] {
        match self {
            Self::Feasibility => &[
                ("clarification", "需求澄清"),
                ("report", "可行性报告"),
            ],
            Self::Ui => &[
                ("page_map", "页面地图"),
                ("interaction", "交互稿"),
            ],
            Self::Development => &[
                ("task_breakdown", "任务拆分"),
                ("coding", "研发"),
            ],
            Self::Testing => &[
                ("test_plan", "测试计划"),
                ("quality_report", "质量报告"),
            ],
            _ => &[],
        }
    }
}

impl std::fmt::Display for LifecycleStage {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_all_stages() {
        for stage in ALL_STAGES {
            let s = stage.as_str();
            let parsed = LifecycleStage::from_str(s).expect(s);
            assert_eq!(*stage, parsed);
        }
    }

    #[test]
    fn next_chain_covers_full_lifecycle() {
        let mut current = Some(LifecycleStage::Feasibility);
        let mut count = 0;
        while let Some(stage) = current {
            count += 1;
            current = stage.next();
        }
        assert_eq!(count, ALL_STAGES.len());
    }

    #[test]
    fn unknown_stage_returns_none() {
        assert!(LifecycleStage::from_str("unknown").is_none());
        assert!(LifecycleStage::from_str("").is_none());
    }

    #[test]
    fn maintenance_is_terminal() {
        assert!(LifecycleStage::Maintenance.next().is_none());
    }

    #[test]
    fn progress_monotonically_increases() {
        let mut prev = 0.0_f64;
        for stage in ALL_STAGES {
            let p = stage.progress();
            assert!(p >= prev, "{:?} progress {} < previous {}", stage, p, prev);
            prev = p;
        }
    }
}
