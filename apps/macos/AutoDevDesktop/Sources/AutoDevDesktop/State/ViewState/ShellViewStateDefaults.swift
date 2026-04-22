import Foundation

extension ShellViewState {
    static func defaultOpsSnapshot() -> DeliveryOpsSnapshot {
        DeliveryOpsSnapshot(
            hostedSystemCount: 0,
            parallelProjectCount: 0,
            activeAgentCount: 0,
            queueDepth: 0,
            runningWorkflowCount: 0,
            slotUsage: "-",
            averageVelocity: "-",
            resourcePressure: "-",
            successRate24h: 0,
            leadTimeMedian: "-",
            blockedProjectCount: 0,
            completedToday: 0,
            systemHealth: "-"
        )
    }

    static func defaultUserProfile() -> UserProfileSummary {
        UserProfileSummary(
            displayName: "未登录",
            email: "-",
            currentPlan: "-"
        )
    }
}
