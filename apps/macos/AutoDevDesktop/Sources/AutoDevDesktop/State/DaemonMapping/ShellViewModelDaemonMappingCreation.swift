import Foundation

extension ShellViewModel {
    static func mapCreationThread(_ dto: DaemonCreationThread) -> CreationThreadSession? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        let linkedProjectID = dto.linkedProjectId.flatMap(UUID.init(uuidString:))
        let materials = dto.materials.compactMap { mapCreationMaterial($0) }
        let messages = dto.messages.compactMap { mapCreationMessage($0) }
        return CreationThreadSession(
            id: id,
            title: dto.title,
            lastUpdated: dto.lastUpdated,
            isArchived: dto.isArchived,
            linkedProjectID: linkedProjectID,
            lifecycleStage: lifecycleStage(from: dto.lifecycleStage),
            materials: materials,
            messages: messages,
            reportDraft: FeasibilityReportDraft(
                projectName: dto.reportDraft.projectName,
                problemDefinition: dto.reportDraft.problemDefinition,
                targetUsers: dto.reportDraft.targetUsers,
                coreCapabilities: dto.reportDraft.coreCapabilities,
                risksAndConstraints: dto.reportDraft.risksAndConstraints,
                initialDeliveryPlan: dto.reportDraft.initialDeliveryPlan,
                feasibilityConclusion: dto.reportDraft.feasibilityConclusion,
                version: dto.reportDraft.version,
                reportDownloadPath: dto.reportDraft.reportDownloadPath,
                updatedAt: dto.reportDraft.updatedAt
            )
        )
    }

    private static func mapCreationMaterial(_ dto: DaemonMaterial) -> CreationMaterialItem? {
        guard let materialID = UUID(uuidString: dto.id) else { return nil }
        return CreationMaterialItem(
            id: materialID,
            name: dto.name,
            typeHint: dto.typeHint,
            sizeHint: dto.sizeHint,
            addedAt: dto.addedAt,
            status: materialStatus(from: dto.status),
            downloadPath: dto.downloadPath
        )
    }

    private static func mapCreationMessage(_ dto: DaemonCreationMessage) -> CreationConversationMessage? {
        guard let messageID = UUID(uuidString: dto.id) else { return nil }
        return CreationConversationMessage(
            id: messageID,
            role: dto.role == "user" ? .user : .ai,
            content: dto.content,
            timestamp: dto.timestamp,
            isLoading: false
        )
    }
}
