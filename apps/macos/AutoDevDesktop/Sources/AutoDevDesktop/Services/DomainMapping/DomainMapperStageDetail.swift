import Foundation

extension DomainMapper {
    // MARK: - Stage Detail

    static func mapStageDetail(_ dto: DaemonProjectStageDetail) -> DeliveryExecutionDetail {
        let stage = lifecycleStage(from: dto.lifecycleStage)
        let artifacts = dto.outputArtifacts.compactMap { mapArtifact($0) }
        let downloads = mapDownloads(dto.downloads ?? [])
        let subSteps = (dto.subSteps ?? []).map { ss in
            DeliverySubStepItem(id: ss.key, key: ss.key, label: ss.label, hasContent: ss.hasContent)
        }
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
            aiRun: dto.aiRun.map { mapStageAIRun($0) },
            riskItems: dto.riskItems,
            primaryAction: dto.primaryAction,
            secondaryActions: dto.secondaryActions,
            eventFlow: dto.eventFlow,
            downloads: downloads,
            workUnits: mapWorkUnits(dto.workUnits ?? []),
            subSteps: subSteps,
            activeSubStep: dto.activeSubStep
        )
    }

    static func mapArtifact(_ dto: DaemonArtifact) -> DeliveryArtifactItem? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        let filePath = dto.filePath?.trimmingCharacters(in: .whitespacesAndNewlines)
        return DeliveryArtifactItem(
            id: id,
            name: dto.name,
            kind: dto.kind,
            updatedAt: dto.updatedAt,
            filePath: (filePath?.isEmpty == false) ? filePath : nil
        )
    }

    static func mapStepProgress(_ dto: DaemonStepProgress) -> DeliveryStepProgressItem {
        DeliveryStepProgressItem(
            id: UUID(),
            title: dto.title,
            status: projectStatus(from: dto.status)
        )
    }

    static func mapEvent(_ dto: DaemonEvent) -> DeliveryEventItem? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        return DeliveryEventItem(
            id: id,
            time: dto.time,
            title: dto.title,
            detail: dto.detail
        )
    }

    static func mapStageAIRun(_ dto: DaemonStageAIRun) -> DeliveryStageAIRun {
        DeliveryStageAIRun(
            id: dto.id,
            status: dto.status,
            startedAt: dto.startedAt,
            updatedAt: dto.updatedAt,
            startedAtMs: dto.startedAtMs,
            updatedAtMs: dto.updatedAtMs,
            firstDeltaAtMs: dto.firstDeltaAtMs,
            deltaCount: dto.deltaCount,
            errorMessage: dto.errorMessage
        )
    }

    static func mapDownloads(_ downloads: [DaemonStageDownload]) -> [StageDownloadItem] {
        downloads.map { dto in
            let filePath = dto.filePath?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasPath = filePath?.isEmpty == false
            return StageDownloadItem(
                id: UUID(uuidString: dto.id) ?? UUID(),
                title: dto.title,
                category: downloadCategory(from: dto.category),
                availability: hasPath ? downloadAvailability(from: dto.availability) : .pending,
                filePath: hasPath ? filePath : nil
            )
        }
    }

    static func mapWorkUnits(_ units: [DaemonWorkUnit]) -> [DeliveryWorkUnitItem] {
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

    // MARK: - Stage Downloads (artifact-based)

    static func mapDownloads(
        stage: DeliveryLifecycleStage,
        artifacts: [DeliveryArtifactItem]
    ) -> [StageDownloadItem] {
        artifacts.compactMap { artifact in
            guard let filePath = artifact.filePath, !filePath.isEmpty else { return nil }
            return StageDownloadItem(
                id: artifact.id,
                title: artifact.name,
                category: stage == .feasibility ? .rawInput : .stageSnapshot,
                availability: .ready,
                filePath: filePath
            )
        }
    }

    static func compactItems<T>(_ items: [T?]) -> [T] {
        items.compactMap { $0 }
    }

}
