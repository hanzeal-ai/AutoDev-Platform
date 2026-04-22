import Foundation

extension ShellViewModel {
    static func mapProject(_ dto: DaemonProject) -> DeliveryProjectItem? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        return DeliveryProjectItem(
            id: id,
            title: dto.title,
            currentPhase: dto.currentPhase,
            lifecycleStage: lifecycleStage(from: dto.lifecycleStage),
            progress: dto.progress,
            currentGoal: dto.currentGoal,
            nextAction: dto.nextAction,
            risk: projectRisk(from: dto.risk),
            blockReason: dto.blockReason,
            status: projectStatus(from: dto.status),
            owner: dto.owner,
            updateTime: dto.updatedAt
        )
    }
}
