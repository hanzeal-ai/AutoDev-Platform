import Foundation

extension ShellViewState {
    var selectedStageGoal: String {
        selectedExecutionDetail?.objective ?? "-"
    }

    var selectedStageInputs: [String] {
        selectedExecutionDetail?.inputContexts ?? []
    }

    var selectedStageOutputs: [String] {
        selectedExecutionDetail?.outputArtifacts.map(\.name) ?? []
    }

    var selectedStageProgressItems: [String] {
        selectedExecutionDetail?.stepProgress.map(\.title) ?? []
    }

    var selectedStageRiskItems: [String] {
        selectedExecutionDetail?.riskItems ?? []
    }

    var selectedStagePrimaryAction: String {
        selectedExecutionDetail?.primaryAction ?? Self.defaultPrimaryAction(for: activeDetailStage)
    }

    var selectedStageSecondaryActions: [String] {
        let actions = selectedExecutionDetail?.secondaryActions ?? []
        if !actions.isEmpty {
            return Array(actions.prefix(2))
        }
        return Self.defaultSecondaryActions(for: activeDetailStage)
    }

    var selectedStageDownloads: [StageDownloadItem] {
        var items = selectedExecutionDetail?.downloads ?? []
        if activeDetailStage == .feasibility {
            items.insert(
                StageDownloadItem(
                    id: UUID(),
                    title: "可行性报告",
                    category: .stageSnapshot,
                    availability: selectedFeasibilityReportDownloadPath == nil ? .pending : .ready,
                    filePath: selectedFeasibilityReportDownloadPath
                ),
                at: 0
            )
            items.append(contentsOf: selectedFeasibilityMaterials.map { material in
                StageDownloadItem(
                    id: material.id,
                    title: material.name,
                    category: .rawInput,
                    availability: material.downloadPath == nil ? .pending : .ready,
                    filePath: material.downloadPath
                )
            })
        }
        return deduplicateDownloads(items)
    }

    private func deduplicateDownloads(_ items: [StageDownloadItem]) -> [StageDownloadItem] {
        var deduplicated: [StageDownloadItem] = []
        var seen = Set<String>()
        for item in items {
            let key = "\(item.category.rawValue)|\(item.title)"
            if seen.insert(key).inserted {
                deduplicated.append(item)
            }
        }
        return deduplicated
    }
}
