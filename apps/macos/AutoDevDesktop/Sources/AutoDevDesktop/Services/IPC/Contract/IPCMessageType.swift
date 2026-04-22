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
        static let confirmFeasibilityCommand = "command.confirm_feasibility"
        static let confirmFeasibilitySuccess = "command.confirm_feasibility.ok"
        static let planDevelopmentCommand = "command.plan_development"
        static let planDevelopmentSuccess = "command.plan_development.ok"

        static let error = "error"
    }
}
