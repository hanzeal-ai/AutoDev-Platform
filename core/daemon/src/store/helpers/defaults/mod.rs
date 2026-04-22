mod stages;

use super::super::StageDefaults;

pub(in crate::store) fn stage_defaults(stage: &str) -> StageDefaults {
    match stage {
        "feasibility" => stages::feasibility(),
        "prd" => stages::prd(),
        "ui" => stages::ui(),
        "development" => stages::development(),
        "testing" => stages::testing(),
        "release" => stages::release(),
        _ => stages::maintenance(),
    }
}
