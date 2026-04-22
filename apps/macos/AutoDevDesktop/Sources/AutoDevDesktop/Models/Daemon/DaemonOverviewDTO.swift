import Foundation

struct DaemonOverviewPayload: Decodable {
    let opsSnapshot: DaemonOpsSnapshot
    let managedAlerts: [DaemonAlert]
    let progressNotices: [DaemonProgressNotice]
    let interventions: [DaemonIntervention]
    let lifecycleDistribution: [DaemonLifecycleStageItem]
}

struct DaemonOpsSnapshot: Decodable {
    let hostedSystemCount: Int
    let parallelProjectCount: Int
    let activeAgentCount: Int
    let queueDepth: Int
    let runningWorkflowCount: Int
    let slotUsage: String
    let averageVelocity: String
    let resourcePressure: String
    let successRate24H: Int
    let leadTimeMedian: String
    let blockedProjectCount: Int
    let completedToday: Int
    let systemHealth: String
}

struct DaemonAlert: Decodable {
    let id: String
    let title: String
    let projectName: String
    let reason: String
    let nextAction: String
    let level: String
}

struct DaemonProgressNotice: Decodable {
    let id: String
    let title: String
    let detail: String
    let time: String
}

struct DaemonIntervention: Decodable {
    let id: String
    let title: String
    let projectName: String
    let reason: String
    let nextAction: String
    let priority: String
}

struct DaemonLifecycleStageItem: Decodable {
    let stage: String
    let count: Int
}
