import Foundation

protocol DaemonQuerying {
    var apiBaseURL: URL { get }
    func login(username: String, password: String) async throws -> DaemonAuthenticatedUser
    func getHealth() async throws -> DaemonHealth
    func getOverview() async throws -> DaemonOverviewPayload
    func listProjects() async throws -> [DaemonProject]
    func listCreationThreads() async throws -> [DaemonCreationThread]
    func getProjectStageDetail(projectID: String, stage: String?, subStep: String?) async throws -> DaemonProjectStageDetail
    func getProjectWorkflowStatus(projectID: String) async throws -> DaemonProjectWorkflowStatus
    func listProjectWorkflowEvents(projectID: String) async throws -> DaemonProjectWorkflowEvents
    func createCreationThread() async throws -> DaemonCommandResult
    func renameCreationThread(threadID: String, title: String) async throws
    func archiveCreationThread(threadID: String) async throws
    func deleteCreationThread(threadID: String) async throws
    func addCreationMessage(threadID: String, content: String) async throws -> DaemonCommandResult
    func addCreationMessageStreaming(threadID: String, content: String) -> CreationStreamingHandle
    func addCreationMaterials(threadID: String, paths: [String]) async throws
    func runProjectWorkflow(projectID: String, feedback: String?, action: String?) async throws -> DaemonCommandResult
    func startProjectWorkflow(projectID: String, feedback: String?, action: String?) async throws -> DaemonCommandResult
    func resumeProjectWorkflow(projectID: String, feedback: String?, action: String?) async throws -> DaemonCommandResult
    func deleteProject(projectID: String) async throws
}

extension DaemonClient: DaemonQuerying {}
