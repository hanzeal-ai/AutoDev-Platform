import Foundation

struct DaemonProjectListPayload: Decodable {
    let projects: [DaemonProject]
}

struct DaemonProject: Decodable {
    let id: String
    let title: String
    let currentPhase: String
    let lifecycleStage: String
    let progress: Double
    let currentGoal: String
    let nextAction: String
    let risk: String
    let blockReason: String?
    let status: String
    let owner: String
    let updatedAt: String
}
