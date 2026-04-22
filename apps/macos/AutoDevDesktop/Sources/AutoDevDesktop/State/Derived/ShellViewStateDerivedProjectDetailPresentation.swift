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
            return Array(Self.supportedSecondaryActions(actions, for: activeDetailStage).prefix(2))
        }
        return Self.defaultSecondaryActions(for: activeDetailStage)
    }

    private static func supportedSecondaryActions(_ actions: [String], for stage: DeliveryLifecycleStage) -> [String] {
        let blocked = ["回退立项", "回退 PRD", "回退研发", "暂停发布", "执行回滚", "重新测试"]
        return actions.filter { action in
            !blocked.contains(action) && defaultSecondaryActions(for: stage).contains(action)
        }
    }

    var selectedStageDownloads: [StageDownloadItem] {
        var items = selectedExecutionDetail?.downloads ?? []
        if activeDetailStage == .feasibility {
            if let reportPath = selectedFeasibilityReportDownloadPath, !reportPath.isEmpty {
                items.insert(StageDownloadItem(
                    id: UUID(),
                    title: "可行性报告",
                    category: .stageSnapshot,
                    availability: .ready,
                    filePath: reportPath
                ), at: 0)
            }
            items.append(contentsOf: selectedFeasibilityMaterials.compactMap { material in
                guard let path = material.downloadPath, !path.isEmpty else { return nil }
                return StageDownloadItem(
                    id: material.id,
                    title: material.name,
                    category: .rawInput,
                    availability: .ready,
                    filePath: path
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
