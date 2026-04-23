import Foundation

extension ShellViewState {
    static func initial(socketPath: String) -> ShellViewState {
        empty(
            socketPath: socketPath,
            daemonStatus: "Unknown",
            daemonVersion: "-",
            protocolVersion: "-",
            lastError: "-",
            statusMessage: "等待后端数据"
        )
    }

    static func preview(socketPath: String) -> ShellViewState {
        empty(
            socketPath: socketPath,
            daemonStatus: "PREVIEW",
            daemonVersion: "-",
            protocolVersion: "-",
            lastError: "-",
            statusMessage: "预览空状态"
        )
    }

    private static func empty(
        socketPath: String,
        daemonStatus: String,
        daemonVersion: String,
        protocolVersion: String,
        lastError: String,
        statusMessage: String
    ) -> ShellViewState {
        ShellViewState(
            route: .overview,
            isSidebarCollapsed: false,
            projectLibraryFilter: .all,
            projectLibrarySearchQuery: "",
            projectDetailBackTarget: .overview,
            selectedDetailStage: nil,
            selectedCreationThreadID: nil,
            selectedCreationThreadIndex: nil,
            creationInputDraft: "",
            creationThreads: [],
            isCreationThreadPanelCollapsed: false,
            isReportPanelCollapsed: false,
            isMaterialImporterPresented: false,
            renameThreadTargetID: nil,
            renameThreadDraft: "",
            creationInputInsertionRequest: nil,
            isSettingsPresented: false,
            appearanceMode: .system,
            storageLocationMode: StorageLocationMode.load(),
            localStoragePath: StorageLocationMode.loadLocalPath(fallback: defaultLocalStoragePath()),
            stageAutomation: StageAutomationConfig.load(),
            projects: [],
            managedAlerts: [],
            progressNotices: [],
            interventions: [],
            lifecycleDistribution: [],
            stageBlueprints: [:],
            executionDetails: [:],
            opsSnapshot: defaultOpsSnapshot(),
            userProfile: defaultUserProfile(),
            daemonStatus: daemonStatus,
            daemonVersion: daemonVersion,
            protocolVersion: protocolVersion,
            deepseekStatusLine: "DeepSeek 未配置",
            lastError: lastError,
            daemonSocketPath: socketPath,
            statusMessage: statusMessage
        )
    }
}

private func defaultLocalStoragePath() -> String {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    return appSupport?
        .appendingPathComponent("com.sanmws.autodev/blobs")
        .path ?? "~/Library/Application Support/com.sanmws.autodev/blobs"
}
