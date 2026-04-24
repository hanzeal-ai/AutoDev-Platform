mod stages;

use super::super::lifecycle::LifecycleStage;
use super::super::StageDefaults;

pub(in crate::store) fn stage_defaults(stage: &str) -> StageDefaults {
    match LifecycleStage::from_str(stage) {
        Some(LifecycleStage::Feasibility) => stages::feasibility(),
        Some(LifecycleStage::Prd) => stages::prd(),
        Some(LifecycleStage::Ui) => stages::ui(),
        Some(LifecycleStage::Development) => stages::development(),
        Some(LifecycleStage::Testing) => stages::testing(),
        Some(LifecycleStage::Release) => stages::release(),
        Some(LifecycleStage::Maintenance) | None => stages::maintenance(),
    }
}
