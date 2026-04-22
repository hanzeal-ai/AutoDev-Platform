import Foundation

enum CreationMessageRole {
    case ai
    case user
}

struct CreationInputInsertionRequest: Equatable {
    let id: UUID
    let text: String
}

struct FeasibilityReportDraft: Equatable {
    var projectName: String
    var problemDefinition: String
    var targetUsers: String
    var coreCapabilities: [String]
    var risksAndConstraints: [String]
    var initialDeliveryPlan: [String]
    var feasibilityConclusion: String
    var version: String = "-"
    var reportDownloadPath: String? = nil
    var updatedAt: String = "-"
}

struct CreationConversationMessage: Identifiable, Equatable {
    let id: UUID
    var role: CreationMessageRole
    var content: String
    var timestamp: String
    var isLoading: Bool = false
}

enum MaterialAnalysisStatus: String {
    case queued = "待分析"
    case analyzed = "已分析"
}

struct CreationMaterialItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var typeHint: String
    var sizeHint: String
    var addedAt: String
    var status: MaterialAnalysisStatus
    var downloadPath: String? = nil
}

struct CreationThreadSession: Identifiable, Equatable {
    let id: UUID
    var title: String
    var lastUpdated: String
    var isArchived: Bool
    var linkedProjectID: UUID?
    var lifecycleStage: DeliveryLifecycleStage
    var materials: [CreationMaterialItem]
    var messages: [CreationConversationMessage]
    var reportDraft: FeasibilityReportDraft
}
