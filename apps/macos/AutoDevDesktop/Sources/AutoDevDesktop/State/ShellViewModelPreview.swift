import Foundation

private struct PreviewDaemonClient: DaemonQuerying {
    let apiBaseURL = DaemonClient.defaultAPIBaseURL()

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

    func getProjectStageDetail(projectID _: String, stage _: String?, subStep _: String?) async throws -> DaemonProjectStageDetail {
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

    func addCreationMessageStreaming(threadID _: String, content _: String) -> CreationStreamingHandle {
        let handle = CreationStreamingHandle()
        handle.stream = AsyncStream { continuation in
            continuation.yield(.delta("Preview streaming response"))
            continuation.yield(.done(DaemonCommandResult(threadId: nil, projectId: nil, addedCount: nil, assistantMessage: "Preview streaming response", reportDraft: nil)))
            continuation.finish()
        }
        return handle
    }

    func addCreationMaterials(threadID _: String, paths _: [String]) async throws {}

    func runProjectWorkflow(projectID _: String, feedback _: String?) async throws -> DaemonCommandResult {
        throw DaemonClientError.malformedResponse
    }

    func deleteProject(projectID _: String) async throws {}
}

extension ShellViewModel {
    static func preview() -> ShellViewModel {
        let daemonClient = PreviewDaemonClient()
        return ShellViewModel(
            daemonClient: daemonClient,
            dataMode: .sampleOnly,
            autoHealthCheck: false,
            initialState: .preview(apiBaseURL: daemonClient.apiBaseURL)
        )
    }
}
