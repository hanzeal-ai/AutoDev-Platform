import Foundation

extension IPCContract {
    enum MessageType {
        static let getHealthQuery = "query.get_health"
        static let getHealthSuccess = "query.get_health.ok"
        static let getOverviewQuery = "query.get_overview"
        static let getOverviewSuccess = "query.get_overview.ok"
        static let listProjectsQuery = "query.list_projects"
        static let listProjectsSuccess = "query.list_projects.ok"
        static let listCreationThreadsQuery = "query.list_creation_threads"
        static let listCreationThreadsSuccess = "query.list_creation_threads.ok"
        static let getProjectStageDetailQuery = "query.get_project_stage_detail"
        static let getProjectStageDetailSuccess = "query.get_project_stage_detail.ok"
        static let getProjectWorkflowStatusQuery = "query.get_project_workflow_status"
        static let getProjectWorkflowStatusSuccess = "query.get_project_workflow_status.ok"
        static let listProjectWorkflowEventsQuery = "query.list_project_workflow_events"
        static let listProjectWorkflowEventsSuccess = "query.list_project_workflow_events.ok"

        static let createCreationThreadCommand = "command.create_creation_thread"
        static let createCreationThreadSuccess = "command.create_creation_thread.ok"
        static let renameCreationThreadCommand = "command.rename_creation_thread"
        static let renameCreationThreadSuccess = "command.rename_creation_thread.ok"
        static let archiveCreationThreadCommand = "command.archive_creation_thread"
        static let archiveCreationThreadSuccess = "command.archive_creation_thread.ok"
        static let deleteCreationThreadCommand = "command.delete_creation_thread"
        static let deleteCreationThreadSuccess = "command.delete_creation_thread.ok"
        static let addCreationMessageCommand = "command.add_creation_message"
        static let addCreationMessageSuccess = "command.add_creation_message.ok"
        static let addCreationMaterialsCommand = "command.add_creation_materials"
        static let addCreationMaterialsSuccess = "command.add_creation_materials.ok"
        static let runProjectWorkflowCommand = "command.run_project_workflow"
        static let runProjectWorkflowSuccess = "command.run_project_workflow.ok"
        static let startProjectWorkflowCommand = "command.start_project_workflow"
        static let startProjectWorkflowSuccess = "command.start_project_workflow.ok"
        static let resumeProjectWorkflowCommand = "command.resume_project_workflow"
        static let resumeProjectWorkflowSuccess = "command.resume_project_workflow.ok"
        static let deleteProjectCommand = "command.delete_project"
        static let deleteProjectSuccess = "command.delete_project.ok"

        // Streaming creation message
        static let addCreationMessageStreamCommand = "command.add_creation_message_stream"
        static let creationMessageDelta = "event.creation_message.delta"
        static let creationMessageDone = "event.creation_message.done"
        static let creationMessageError = "event.creation_message.error"

        static let error = "error"
    }
}
