import Foundation

enum ShellRoute: Equatable {
    case overview
    case projectLibrary
    case projectCreation
    case projectDetail(projectID: UUID)

    var title: String {
        switch self {
        case .overview:
            return "总览"
        case .projectLibrary:
            return "项目库"
        case .projectCreation:
            return "新建项目"
        case .projectDetail:
            return "阶段详情"
        }
    }
}

enum ProjectDetailBackTarget {
    case overview
    case projectLibrary
}

struct ProjectExecutionDetailKey: Hashable {
    let projectID: UUID
    let stage: DeliveryLifecycleStage
}
