import Foundation

extension ShellViewState {
    static func initial(apiBaseURL: URL) -> ShellViewState {
        empty(
            apiBaseURL: apiBaseURL,
            daemonStatus: "Unknown",
            daemonVersion: "-",
            protocolVersion: "-",
            lastError: "-",
            statusMessage: "等待后端数据"
        )
    }

    static func preview(apiBaseURL: URL) -> ShellViewState {
        empty(
            apiBaseURL: apiBaseURL,
            daemonStatus: "PREVIEW",
            daemonVersion: "-",
            protocolVersion: "-",
            lastError: "-",
            statusMessage: "预览空状态"
        )
    }

    private static func empty(
        apiBaseURL: URL,
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
            workflowSnapshots: [:],
            opsSnapshot: defaultOpsSnapshot(),
            userProfile: defaultUserProfile(),
            isAuthenticated: false,
            loginUsername: "admin",
            loginPassword: "",
            loginError: "",
            daemonStatus: daemonStatus,
            daemonVersion: daemonVersion,
            protocolVersion: protocolVersion,
            deepseekStatusLine: "DeepSeek 未配置",
            lastError: lastError,
            daemonAPIBaseURL: apiBaseURL.absoluteString,
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
