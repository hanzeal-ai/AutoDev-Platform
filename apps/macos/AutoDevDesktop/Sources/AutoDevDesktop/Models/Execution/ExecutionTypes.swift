import Foundation

enum StageDownloadCategory: String, Equatable {
    case rawInput = "原始输入资料"
    case stageSnapshot = "阶段产物快照"
    case auditArchive = "审计留档文件"
}

enum StageDownloadAvailability: Equatable {
    case ready
    case pending
    case viewOnly
}

struct StageDownloadItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var category: StageDownloadCategory
    var availability: StageDownloadAvailability
    var filePath: String?
}

struct DeliveryStepProgressItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var status: ProjectStatus
}

struct DeliveryArtifactItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var kind: String
    var updatedAt: String
    var filePath: String? = nil
}

struct DeliveryEventItem: Identifiable, Equatable {
    let id: UUID
    var time: String
    var title: String
    var detail: String
}

struct DeliveryStageAIRun: Equatable {
    var id: String
    var status: String
    var startedAt: String
    var updatedAt: String
    var startedAtMs: Int64
    var updatedAtMs: Int64
    var firstDeltaAtMs: Int64?
    var deltaCount: Int
    var errorMessage: String?

    var isActive: Bool {
        ["dispatched", "waiting_first_delta", "streaming", "post_processing"].contains(status)
    }
}

struct DeliverySubTaskItem: Identifiable, Equatable {
    let id: String
    var title: String
    var status: ProjectStatus
    var progress: Double
}

struct DeliveryWorkUnitItem: Identifiable, Equatable {
    let id: String
    var title: String
    var agentRole: String
    var status: ProjectStatus
    var progress: Double
    var dependsOn: [String]
    var currentOutput: String?
    var nextStep: String
    var downloads: [StageDownloadItem] = []
    var subTasks: [DeliverySubTaskItem] = []
}

struct DeliveryExecutionDetail: Equatable {
    var unitName: String
    var projectName: String
    var lifecycleStage: DeliveryLifecycleStage
    var status: ProjectStatus
    var priority: String
    var owner: String
    var updatedAt: String
    var objective: String
    var inputContexts: [String]
    var outputArtifacts: [DeliveryArtifactItem]
    var stepProgress: [DeliveryStepProgressItem]
    var riskLevel: ProjectRisk
    var blockerReason: String?
    var needsUserIntervention: Bool
    var events: [DeliveryEventItem]
    var aiRun: DeliveryStageAIRun?
    var riskItems: [String] = []
    var primaryAction: String = "继续"
    var secondaryActions: [String] = []
    var eventFlow: [String] = []
    var downloads: [StageDownloadItem] = []
    var workUnits: [DeliveryWorkUnitItem] = []
    var subSteps: [DeliverySubStepItem] = []
    var activeSubStep: String?
}

struct DeliverySubStepItem: Identifiable, Equatable {
    let id: String
    var key: String
    var label: String
    var hasContent: Bool
}

struct StageViewBlueprint: Equatable {
    var title: String
    var summary: String
    var goal: String
    var inputContexts: [String]
    var outputArtifacts: [String]
    var progressItems: [String]
    var riskItems: [String]
    var eventFlow: [String]
    var primaryAction: String
    var secondaryActions: [String]
}
