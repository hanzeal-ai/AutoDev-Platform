import Foundation

struct DaemonThreadListPayload: Decodable {
    let threads: [DaemonCreationThread]
}

struct DaemonCreationThread: Decodable {
    let id: String
    let title: String
    let isArchived: Bool
    let linkedProjectId: String?
    let lifecycleStage: String
    let lastUpdated: String
    let messages: [DaemonCreationMessage]
    let materials: [DaemonMaterial]
    let reportDraft: DaemonFeasibilityReport
}

struct DaemonCreationMessage: Decodable {
    let id: String
    let role: String
    let content: String
    let timestamp: String
}

struct DaemonMaterial: Decodable {
    let id: String
    let name: String
    let typeHint: String
    let sizeHint: String
    let status: String
    let addedAt: String
    let downloadPath: String?
}

struct DaemonFeasibilityReport: Decodable {
    let projectName: String
    let problemDefinition: String
    let targetUsers: String
    let coreCapabilities: [String]
    let risksAndConstraints: [String]
    let initialDeliveryPlan: [String]
    let feasibilityConclusion: String
    let version: String
    let reportDownloadPath: String?
    let updatedAt: String
}
