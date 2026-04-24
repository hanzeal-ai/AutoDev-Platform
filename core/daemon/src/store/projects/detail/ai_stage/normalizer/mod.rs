mod stage;
mod prd;
mod dev;
mod ui;

#[allow(unused_imports)]
pub(crate) use stage::persist_stage_content;
#[allow(unused_imports)]
pub(crate) use prd::persist_prd_content;
#[allow(unused_imports)]
pub(crate) use dev::{persist_development_task_breakdown, persist_development_coding};
#[allow(unused_imports)]
pub(crate) use ui::persist_ui_sub_steps;


/// Strip path-traversal characters from a path component (project_id, stage).
pub(super) fn sanitize_path_component(input: &str) -> String {
    input
        .replace("..", "")
        .replace('/', "")
        .replace('\\', "")
        .replace('\0', "")
}
