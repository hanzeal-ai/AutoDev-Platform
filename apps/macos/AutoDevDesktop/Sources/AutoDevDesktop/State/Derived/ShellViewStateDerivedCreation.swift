import Foundation

extension ShellViewState {
    var selectedEffectiveCreationThreadID: UUID? {
        selectedCreationThread?.id
    }

    var selectedLinkedCreationThread: CreationThreadSession? {
        guard let project = selectedProject else {
            return nil
        }
        return creationThreads.first(where: { $0.linkedProjectID == project.id })
    }

    var selectedFeasibilityDraft: FeasibilityReportDraft? {
        selectedLinkedCreationThread?.reportDraft ?? creationThreads.first?.reportDraft
    }

    var selectedFeasibilityMaterials: [CreationMaterialItem] {
        if let linked = selectedLinkedCreationThread, !linked.materials.isEmpty {
            return linked.materials
        }
        return creationThreads.first(where: { !$0.materials.isEmpty })?.materials ?? []
    }

    var selectedFeasibilityReportDownloadPath: String? {
        selectedLinkedCreationThread?.reportDraft.reportDownloadPath ?? creationThreads.first?.reportDraft.reportDownloadPath
    }

    var selectedFeasibilityReportVersion: String {
        selectedLinkedCreationThread?.reportDraft.version ?? (activeDetailStage == .feasibility ? "v0.3" : "v1.0")
    }

    var selectedFeasibilityReportUpdatedAt: String {
        selectedLinkedCreationThread?.reportDraft.updatedAt ?? selectedLinkedCreationThread?.lastUpdated ?? selectedProject?.updateTime ?? "刚刚"
    }

    var selectedCreationLifecycleStage: DeliveryLifecycleStage {
        selectedCreationThread?.lifecycleStage ?? .feasibility
    }

    var selectedCreationThread: CreationThreadSession? {
        if
            let selectedCreationThreadIndex = selectedCreationThreadIndex,
            creationThreads.indices.contains(selectedCreationThreadIndex)
        {
            let thread = creationThreads[selectedCreationThreadIndex]
            if !thread.isArchived && (thread.id == selectedCreationThreadID || selectedCreationThreadID == nil) {
                return thread
            }
        }
        return creationThreads.first(where: { !$0.isArchived })
    }

    var selectedCreationMessages: [CreationConversationMessage] {
        selectedCreationThread?.messages ?? []
    }

    var orderedCreationThreads: [CreationThreadSession] {
        creationThreads
    }
}
