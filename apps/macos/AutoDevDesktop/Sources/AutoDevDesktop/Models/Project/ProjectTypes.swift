import Foundation

enum ProjectStatus: String {
    case running = "运行中"
    case queued = "排队中"
    case awaitingConfirmation = "待你确认"
    case blocked = "阻塞"
    case failed = "失败"
    case completed = "已完成"
    case archived = "已归档"
}

enum DeliveryLifecycleStage: String, CaseIterable, Identifiable {
    case feasibility = "立项"
    case prd = "PRD"
    case ui = "UI"
    case development = "研发"
    case testing = "测试"
    case release = "发布"
    case maintenance = "维护"

    var id: String { rawValue }

    var order: Int {
        switch self {
        case .feasibility:
            return 0
        case .prd:
            return 1
        case .ui:
            return 2
        case .development:
            return 3
        case .testing:
            return 4
        case .release:
            return 5
        case .maintenance:
            return 6
        }
    }
}

enum ProjectRisk: String {
    case low = "低"
    case medium = "中"
    case high = "高"
}

enum ProjectLibraryFilter: String, CaseIterable, Identifiable {
    case inProgress = "运行中"
    case all = "全部"
    case blocked = "阻塞中"
    case archived = "归档"

    var id: String { rawValue }
}

struct DeliveryProjectItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var currentPhase: String
    var lifecycleStage: DeliveryLifecycleStage
    var progress: Double
    var currentGoal: String
    var nextAction: String
    var risk: ProjectRisk
    var blockReason: String?
    var status: ProjectStatus
    var owner: String
    var updateTime: String
}
