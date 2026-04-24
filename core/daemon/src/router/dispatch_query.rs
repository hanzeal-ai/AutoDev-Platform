use crate::protocol;
use crate::runtime;
use crate::store;
use serde_json::Value;

pub(super) fn dispatch(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Option<Result<(&'static str, Value), String>> {
    match inbound.message_type.as_str() {
        protocol::MESSAGE_QUERY_GET_HEALTH => Some(Ok((
            protocol::MESSAGE_QUERY_GET_HEALTH_OK,
            runtime::health_payload(runtime_paths),
        ))),
        protocol::MESSAGE_QUERY_GET_OVERVIEW => {
            let store = store::Store::open(runtime_paths);
            Some(store.and_then(|store| {
                Ok((
                    protocol::MESSAGE_QUERY_GET_OVERVIEW_OK,
                    store.get_overview()?,
                ))
            }))
        }
        protocol::MESSAGE_QUERY_LIST_PROJECTS => {
            let store = store::Store::open(runtime_paths);
            Some(store.and_then(|store| {
                Ok((
                    protocol::MESSAGE_QUERY_LIST_PROJECTS_OK,
                    store.list_projects()?,
                ))
            }))
        }
        protocol::MESSAGE_QUERY_LIST_CREATION_THREADS => {
            let store = store::Store::open(runtime_paths);
            Some(store.and_then(|store| {
                Ok((
                    protocol::MESSAGE_QUERY_LIST_CREATION_THREADS_OK,
                    store.list_creation_threads()?,
                ))
            }))
        }
        protocol::MESSAGE_QUERY_GET_PROJECT_STAGE_DETAIL => {
            let project_id = match inbound.payload_string("project_id") {
                Ok(value) => value,
                Err(err) => return Some(Err(err)),
            };
            let payload_obj = inbound.payload_object().ok();
            let stage = payload_obj
                .as_ref()
                .and_then(|p| p.get("stage").and_then(Value::as_str));
            let sub_step = payload_obj
                .as_ref()
                .and_then(|p| p.get("sub_step").and_then(Value::as_str));
            let store = store::Store::open(runtime_paths);
            Some(store.and_then(|store| {
                Ok((
                    protocol::MESSAGE_QUERY_GET_PROJECT_STAGE_DETAIL_OK,
                    store.get_project_stage_detail(&project_id, stage, sub_step)?,
                ))
            }))
        }
        _ => None,
    }
}
