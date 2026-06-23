import Foundation

struct ShellViewState {
    var route: ShellRoute
    var isSidebarCollapsed: Bool
    var projectLibraryFilter: ProjectLibraryFilter
    var projectLibrarySearchQuery: String
    var projectDetailBackTarget: ProjectDetailBackTarget
    var selectedDetailStage: DeliveryLifecycleStage?
    var selectedSubStep: String?
    var selectedCreationThreadID: UUID?
    var selectedCreationThreadIndex: Int?
    var creationInputDraft: String
    var creationThreads: [CreationThreadSession]
    var isCreationThreadPanelCollapsed: Bool
    var isReportPanelCollapsed: Bool
    var isMaterialImporterPresented: Bool
    var renameThreadTargetID: UUID?
    var renameThreadDraft: String
    var creationInputInsertionRequest: CreationInputInsertionRequest?
    var isSettingsPresented: Bool
    var appearanceMode: AppearanceMode
    var storageLocationMode: StorageLocationMode
    var localStoragePath: String
    var stageAutomation: StageAutomationConfig
    var projects: [DeliveryProjectItem]
    var managedAlerts: [ManagedAlertItem]
    var progressNotices: [ProgressNoticeItem]
    var interventions: [InterventionItem]
    var lifecycleDistribution: [LifecycleStageItem]
    var stageBlueprints: [DeliveryLifecycleStage: StageViewBlueprint]
    var executionDetails: [ProjectExecutionDetailKey: DeliveryExecutionDetail]
    var workflowSnapshots: [UUID: DeliveryWorkflowSnapshot]
    var workflowRawStreamLines: [UUID: [String]]
    var opsSnapshot: DeliveryOpsSnapshot
    var userProfile: UserProfileSummary
    var isAuthenticated: Bool
    var loginUsername: String
    var loginPassword: String
    var loginError: String
    var daemonStatus: String
    var daemonVersion: String
    var protocolVersion: String
    var deepseekStatusLine: String
    var lastError: String
    var daemonAPIBaseURL: String
    var statusMessage: String

    var selectedProject: DeliveryProjectItem? {
        switch route {
        case .overview, .projectLibrary, .projectCreation:
            return nil
        case let .projectDetail(projectID):
            return projects.first(where: { $0.id == projectID })
        }
    }
}
