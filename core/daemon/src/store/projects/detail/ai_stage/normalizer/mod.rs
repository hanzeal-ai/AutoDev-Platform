mod dev;
mod prd;
mod workflow;

#[allow(unused_imports)]
pub(crate) use dev::{persist_development_coding, persist_development_task_breakdown};
#[allow(unused_imports)]
pub(crate) use prd::persist_prd_content;
#[allow(unused_imports)]
pub(crate) use workflow::{
    persist_generic_workflow_artifact, persist_workflow_review, persist_workflow_summary,
};

/// Strip path-traversal characters from a path component (project_id, stage).
pub(super) fn sanitize_path_component(input: &str) -> String {
    input
        .replace("..", "")
        .replace('/', "")
        .replace('\\', "")
        .replace('\0', "")
}
