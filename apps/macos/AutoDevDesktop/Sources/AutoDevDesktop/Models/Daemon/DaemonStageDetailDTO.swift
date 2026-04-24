import Foundation

struct DaemonProjectStageDetailPayload: Decodable {
    let detail: DaemonProjectStageDetail
}

struct DaemonProjectStageDetail: Decodable {
    let projectId: String
    let unitName: String
    let projectName: String
    let lifecycleStage: String
    let status: String
    let priority: String
    let owner: String
    let updatedAt: String
    let objective: String
    let inputContexts: [String]
    let outputArtifacts: [DaemonArtifact]
    let downloads: [DaemonStageDownload]?
    let workUnits: [DaemonWorkUnit]?
    let stepProgress: [DaemonStepProgress]
    let riskLevel: String
    let blockerReason: String?
    let needsUserIntervention: Bool
    let events: [DaemonEvent]
    let aiRun: DaemonStageAIRun?
    let primaryAction: String
    let secondaryActions: [String]
    let riskItems: [String]
    let eventFlow: [String]
    let subSteps: [DaemonSubStep]?
    let activeSubStep: String?
}

struct DaemonStageAIRun: Decodable {
    let id: String
    let status: String
    let startedAt: String
    let updatedAt: String
    let startedAtMs: Int64
    let updatedAtMs: Int64
    let firstDeltaAtMs: Int64?
    let lastDeltaAtMs: Int64?
    let deltaCount: Int
    let errorMessage: String?
}

struct DaemonWorkUnit: Decodable {
    let id: String
    let title: String
    let agentRole: String
    let status: String
    let progress: Double
    let dependsOn: [String]
    let currentOutput: String?
    let nextStep: String
    let downloads: [DaemonStageDownload]?
}

struct DaemonStageDownload: Decodable {
    let id: String
    let title: String
    let category: String
    let availability: String
    let filePath: String?
}

struct DaemonArtifact: Decodable {
    let id: String
    let name: String
    let kind: String
    let updatedAt: String
    let filePath: String?
}

struct DaemonStepProgress: Decodable {
    let title: String
    let status: String
}

struct DaemonEvent: Decodable {
    let id: String
    let time: String
    let title: String
    let detail: String
}

struct DaemonSubStep: Decodable {
    let key: String
    let label: String
    let hasContent: Bool
}
