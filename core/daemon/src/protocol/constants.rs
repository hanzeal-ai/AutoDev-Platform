pub const SCHEMA_VERSION: u32 = 1;

pub const MESSAGE_QUERY_GET_HEALTH: &str = "query.get_health";
pub const MESSAGE_QUERY_GET_HEALTH_OK: &str = "query.get_health.ok";
pub const MESSAGE_QUERY_GET_OVERVIEW: &str = "query.get_overview";
pub const MESSAGE_QUERY_GET_OVERVIEW_OK: &str = "query.get_overview.ok";
pub const MESSAGE_QUERY_LIST_PROJECTS: &str = "query.list_projects";
pub const MESSAGE_QUERY_LIST_PROJECTS_OK: &str = "query.list_projects.ok";
pub const MESSAGE_QUERY_LIST_CREATION_THREADS: &str = "query.list_creation_threads";
pub const MESSAGE_QUERY_LIST_CREATION_THREADS_OK: &str = "query.list_creation_threads.ok";
pub const MESSAGE_QUERY_GET_PROJECT_STAGE_DETAIL: &str = "query.get_project_stage_detail";
pub const MESSAGE_QUERY_GET_PROJECT_STAGE_DETAIL_OK: &str = "query.get_project_stage_detail.ok";
pub const MESSAGE_QUERY_GET_PROJECT_WORKFLOW_STATUS: &str = "query.get_project_workflow_status";
pub const MESSAGE_QUERY_GET_PROJECT_WORKFLOW_STATUS_OK: &str =
    "query.get_project_workflow_status.ok";
pub const MESSAGE_QUERY_LIST_PROJECT_WORKFLOW_EVENTS: &str = "query.list_project_workflow_events";
pub const MESSAGE_QUERY_LIST_PROJECT_WORKFLOW_EVENTS_OK: &str =
    "query.list_project_workflow_events.ok";

pub const MESSAGE_COMMAND_LOGIN: &str = "command.login";
pub const MESSAGE_COMMAND_LOGIN_OK: &str = "command.login.ok";
pub const MESSAGE_COMMAND_CREATE_CREATION_THREAD: &str = "command.create_creation_thread";
pub const MESSAGE_COMMAND_CREATE_CREATION_THREAD_OK: &str = "command.create_creation_thread.ok";
pub const MESSAGE_COMMAND_RENAME_CREATION_THREAD: &str = "command.rename_creation_thread";
pub const MESSAGE_COMMAND_RENAME_CREATION_THREAD_OK: &str = "command.rename_creation_thread.ok";
pub const MESSAGE_COMMAND_ARCHIVE_CREATION_THREAD: &str = "command.archive_creation_thread";
pub const MESSAGE_COMMAND_ARCHIVE_CREATION_THREAD_OK: &str = "command.archive_creation_thread.ok";
pub const MESSAGE_COMMAND_DELETE_CREATION_THREAD: &str = "command.delete_creation_thread";
pub const MESSAGE_COMMAND_DELETE_CREATION_THREAD_OK: &str = "command.delete_creation_thread.ok";
pub const MESSAGE_COMMAND_ADD_CREATION_MESSAGE: &str = "command.add_creation_message";
pub const MESSAGE_COMMAND_ADD_CREATION_MESSAGE_OK: &str = "command.add_creation_message.ok";
pub const MESSAGE_COMMAND_ADD_CREATION_MATERIALS: &str = "command.add_creation_materials";
pub const MESSAGE_COMMAND_ADD_CREATION_MATERIALS_OK: &str = "command.add_creation_materials.ok";
pub const MESSAGE_COMMAND_RUN_PROJECT_WORKFLOW: &str = "command.run_project_workflow";
pub const MESSAGE_COMMAND_RUN_PROJECT_WORKFLOW_OK: &str = "command.run_project_workflow.ok";
pub const MESSAGE_COMMAND_START_PROJECT_WORKFLOW: &str = "command.start_project_workflow";
pub const MESSAGE_COMMAND_START_PROJECT_WORKFLOW_OK: &str = "command.start_project_workflow.ok";
pub const MESSAGE_COMMAND_RESUME_PROJECT_WORKFLOW: &str = "command.resume_project_workflow";
pub const MESSAGE_COMMAND_RESUME_PROJECT_WORKFLOW_OK: &str = "command.resume_project_workflow.ok";
pub const MESSAGE_COMMAND_DELETE_PROJECT: &str = "command.delete_project";
pub const MESSAGE_COMMAND_DELETE_PROJECT_OK: &str = "command.delete_project.ok";

pub const MESSAGE_COMMAND_ADD_CREATION_MESSAGE_STREAM: &str = "command.add_creation_message_stream";
pub const MESSAGE_EVENT_CREATION_MESSAGE_DELTA: &str = "event.creation_message.delta";
pub const MESSAGE_EVENT_CREATION_MESSAGE_DONE: &str = "event.creation_message.done";
pub const MESSAGE_EVENT_CREATION_MESSAGE_ERROR: &str = "event.creation_message.error";

pub const MESSAGE_ERROR: &str = "error";
