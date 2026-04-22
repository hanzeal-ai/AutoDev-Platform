import Foundation

extension ShellViewModel {
    static func mapStageDetail(_ dto: DaemonProjectStageDetail) -> DeliveryExecutionDetail {
        let stage = lifecycleStage(from: dto.lifecycleStage)
        let artifacts = dto.outputArtifacts.compactMap { mapArtifact($0) }
        let downloads = mapDownloads(dto.downloads ?? [])
        return DeliveryExecutionDetail(
            unitName: dto.unitName,
            projectName: dto.projectName,
            lifecycleStage: stage,
            status: projectStatus(from: dto.status),
            priority: dto.priority,
            owner: dto.owner,
            updatedAt: dto.updatedAt,
            objective: dto.objective,
            inputContexts: dto.inputContexts,
            outputArtifacts: artifacts,
            stepProgress: dto.stepProgress.map { mapStepProgress($0) },
            riskLevel: projectRisk(from: dto.riskLevel),
            blockerReason: dto.blockerReason,
            needsUserIntervention: dto.needsUserIntervention,
            events: dto.events.compactMap { mapEvent($0) },
            riskItems: dto.riskItems,
            primaryAction: dto.primaryAction,
            secondaryActions: dto.secondaryActions,
            downloads: downloads.isEmpty ? mapDownloads(stage: stage, artifacts: artifacts) : downloads,
            workUnits: mapWorkUnits(dto.workUnits ?? [])
        )
    }

    private static func mapArtifact(_ dto: DaemonArtifact) -> DeliveryArtifactItem? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        return DeliveryArtifactItem(
            id: id,
            name: dto.name,
            kind: dto.kind,
            updatedAt: dto.updatedAt,
            filePath: dto.filePath
        )
    }

    private static func mapStepProgress(_ dto: DaemonStepProgress) -> DeliveryStepProgressItem {
        DeliveryStepProgressItem(
            id: UUID(),
            title: dto.title,
            status: projectStatus(from: dto.status)
        )
    }

    private static func mapEvent(_ dto: DaemonEvent) -> DeliveryEventItem? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        return DeliveryEventItem(
            id: id,
            time: dto.time,
            title: dto.title,
            detail: dto.detail
        )
    }

    private static func mapDownloads(_ downloads: [DaemonStageDownload]) -> [StageDownloadItem] {
        downloads.map { dto in
            StageDownloadItem(
                id: UUID(uuidString: dto.id) ?? UUID(),
                title: dto.title,
                category: downloadCategory(from: dto.category),
                availability: downloadAvailability(from: dto.availability),
                filePath: dto.filePath
            )
        }
    }

    private static func mapWorkUnits(_ units: [DaemonWorkUnit]) -> [DeliveryWorkUnitItem] {
        units.map { dto in
            DeliveryWorkUnitItem(
                id: dto.id,
                title: dto.title,
                agentRole: dto.agentRole,
                status: projectStatus(from: dto.status),
                progress: max(0, min(dto.progress, 1)),
                dependsOn: dto.dependsOn,
                currentOutput: dto.currentOutput,
                nextStep: dto.nextStep,
                downloads: mapDownloads(dto.downloads ?? [])
            )
        }
    }

    private static func downloadCategory(from raw: String) -> StageDownloadCategory {
        switch raw {
        case "raw_input":
            return .rawInput
        case "audit_archive":
            return .auditArchive
        default:
            return .stageSnapshot
        }
    }

    private static func downloadAvailability(from raw: String) -> StageDownloadAvailability {
        switch raw {
        case "ready":
            return .ready
        case "view_only":
            return .viewOnly
        default:
            return .pending
        }
    }
}
