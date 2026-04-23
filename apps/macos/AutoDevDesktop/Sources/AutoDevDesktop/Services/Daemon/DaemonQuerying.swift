import Foundation

protocol DaemonQuerying {
    var socketPath: String { get }
    func getHealth() async throws -> DaemonHealth
    func getOverview() async throws -> DaemonOverviewPayload
    func listProjects() async throws -> [DaemonProject]
    func listCreationThreads() async throws -> [DaemonCreationThread]
    func getProjectStageDetail(projectID: String, stage: String?) async throws -> DaemonProjectStageDetail
    func createCreationThread() async throws -> DaemonCommandResult
    func renameCreationThread(threadID: String, title: String) async throws
    func archiveCreationThread(threadID: String) async throws
    func deleteCreationThread(threadID: String) async throws
    func addCreationMessage(threadID: String, content: String) async throws -> DaemonCommandResult
    func addCreationMaterials(threadID: String, paths: [String]) async throws
    func confirmFeasibility(threadID: String) async throws -> DaemonCommandResult
    func advanceProjectStage(projectID: String, action: String, autoTriggerAI: Bool) async throws -> DaemonCommandResult
    func planDevelopment(projectID: String) async throws -> DaemonCommandResult
    func generateProjectStageAI(projectID: String, stage: String?) async throws -> DaemonCommandResult
}

extension DaemonClient: DaemonQuerying {}
