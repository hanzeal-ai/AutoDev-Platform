import Foundation

extension ShellViewState {
    var runningProjectCount: Int {
        projects.filter { Self.runningStatuses.contains($0.status) }.count
    }

    var interventionCount: Int {
        interventions.count
    }

    var blockedProjects: [DeliveryProjectItem] {
        projects.filter { [.blocked, .failed].contains($0.status) }
    }

    var runningQueueProjects: [DeliveryProjectItem] {
        projects.filter { Self.runningStatuses.contains($0.status) }
    }

    var operationsSummaryLine: String {
        "托管系统 \(opsSnapshot.hostedSystemCount) · 并行 \(opsSnapshot.parallelProjectCount) · 阻塞 \(opsSnapshot.blockedProjectCount) · 待介入 \(interventionCount)"
    }

    var focusProject: DeliveryProjectItem? {
        runningQueueProjects.first ?? projects.first
    }
}
