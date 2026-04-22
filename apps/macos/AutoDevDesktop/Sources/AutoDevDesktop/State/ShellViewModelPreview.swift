import Foundation

private struct PreviewDaemonClient: DaemonQuerying {
    let socketPath = DaemonClient.defaultSocketPath()

    func getHealth() async throws -> DaemonHealth {
        DaemonHealth(
            status: "preview22",
            daemonVersion: "0.1.0",
            protocolVersion: 1,
            appSupportRoot: nil,
            databasePath: nil,
            blobsPath: nil,
            deepseekConfigured: false,
            deepseekModel: nil,
            deepseekBaseUrl: nil
        )
    }

    func getOverview() async throws -> DaemonOverviewPayload {
        throw DaemonClientError.malformedResponse
    }

    func listProjects() async throws -> [DaemonProject] {
        throw DaemonClientError.malformedResponse
    }

    func listCreationThreads() async throws -> [DaemonCreationThread] {
        throw DaemonClientError.malformedResponse
    }

    func getProjectStageDetail(projectID _: String, stage _: String?) async throws -> DaemonProjectStageDetail {
        throw DaemonClientError.malformedResponse
    }

    func createCreationThread() async throws -> DaemonCommandResult {
        throw DaemonClientError.malformedResponse
    }

    func renameCreationThread(threadID _: String, title _: String) async throws {}

    func archiveCreationThread(threadID _: String) async throws {}

    func deleteCreationThread(threadID _: String) async throws {}

    func addCreationMessage(threadID _: String, content _: String) async throws -> DaemonCommandResult {
        DaemonCommandResult(threadId: nil, projectId: nil, addedCount: nil, assistantMessage: nil, reportDraft: nil)
    }

    func addCreationMaterials(threadID _: String, paths _: [String]) async throws {}

    func confirmFeasibility(threadID _: String) async throws -> DaemonCommandResult {
        throw DaemonClientError.malformedResponse
    }

    func advanceProjectStage(projectID _: String, action _: String) async throws -> DaemonCommandResult {
        throw DaemonClientError.malformedResponse
    }

    func planDevelopment(projectID _: String) async throws -> DaemonCommandResult {
        throw DaemonClientError.malformedResponse
    }

    func generateProjectStageAI(projectID _: String, stage _: String?) async throws -> DaemonCommandResult {
        throw DaemonClientError.malformedResponse
    }
}

extension ShellViewModel {
    static func preview() -> ShellViewModel {
        let daemonClient = PreviewDaemonClient()
        return ShellViewModel(
            daemonClient: daemonClient,
            dataMode: .sampleOnly,
            autoHealthCheck: false,
            initialState: .preview(socketPath: daemonClient.socketPath)
        )
    }
}
