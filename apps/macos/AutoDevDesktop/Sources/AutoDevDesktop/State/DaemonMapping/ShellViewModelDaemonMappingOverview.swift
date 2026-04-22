import Foundation

extension ShellViewModel {
    static func mapOpsSnapshot(_ dto: DaemonOpsSnapshot) -> DeliveryOpsSnapshot {
        DeliveryOpsSnapshot(
            hostedSystemCount: dto.hostedSystemCount,
            parallelProjectCount: dto.parallelProjectCount,
            activeAgentCount: dto.activeAgentCount,
            queueDepth: dto.queueDepth,
            runningWorkflowCount: dto.runningWorkflowCount,
            slotUsage: dto.slotUsage,
            averageVelocity: dto.averageVelocity,
            resourcePressure: dto.resourcePressure,
            successRate24h: dto.successRate24H,
            leadTimeMedian: dto.leadTimeMedian,
            blockedProjectCount: dto.blockedProjectCount,
            completedToday: dto.completedToday,
            systemHealth: dto.systemHealth
        )
    }

    static func mapAlert(_ dto: DaemonAlert) -> ManagedAlertItem? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        return ManagedAlertItem(
            id: id,
            title: dto.title,
            projectName: dto.projectName,
            reason: dto.reason,
            nextAction: dto.nextAction,
            level: alertLevel(from: dto.level)
        )
    }

    static func mapProgressNotice(_ dto: DaemonProgressNotice) -> ProgressNoticeItem? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        return ProgressNoticeItem(
            id: id,
            title: dto.title,
            detail: dto.detail,
            time: dto.time
        )
    }

    static func mapIntervention(_ dto: DaemonIntervention) -> InterventionItem? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        return InterventionItem(
            id: id,
            title: dto.title,
            projectName: dto.projectName,
            reason: dto.reason,
            nextAction: dto.nextAction,
            priority: interventionPriority(from: dto.priority)
        )
    }

    static func mapLifecycleStageItem(_ dto: DaemonLifecycleStageItem) -> LifecycleStageItem {
        LifecycleStageItem(stage: lifecycleStage(from: dto.stage), count: dto.count)
    }
}
