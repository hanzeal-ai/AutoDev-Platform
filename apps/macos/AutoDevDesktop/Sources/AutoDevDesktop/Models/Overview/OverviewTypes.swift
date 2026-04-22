import Foundation

enum AlertLevel: String {
    case warning = "告警"
    case critical = "严重"
    case info = "提示"
}

enum InterventionPriority: String {
    case critical = "高"
    case normal = "中"
    case low = "低"
}

struct ManagedAlertItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var projectName: String
    var reason: String
    var nextAction: String
    var level: AlertLevel
}

struct ProgressNoticeItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var detail: String
    var time: String
}

struct DeliveryOpsSnapshot {
    var hostedSystemCount: Int
    var parallelProjectCount: Int
    var activeAgentCount: Int
    var queueDepth: Int
    var runningWorkflowCount: Int
    var slotUsage: String
    var averageVelocity: String
    var resourcePressure: String
    var successRate24h: Int
    var leadTimeMedian: String
    var blockedProjectCount: Int
    var completedToday: Int
    var systemHealth: String
}

struct InterventionItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var projectName: String
    var reason: String
    var nextAction: String
    var priority: InterventionPriority
}

struct LifecycleStageItem: Identifiable, Equatable {
    let id = UUID()
    var stage: DeliveryLifecycleStage
    var count: Int
}
