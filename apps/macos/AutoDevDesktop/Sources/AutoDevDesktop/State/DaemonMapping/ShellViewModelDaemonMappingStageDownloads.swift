import Foundation

extension ShellViewModel {
    static func mapDownloads(
        stage: DeliveryLifecycleStage,
        artifacts: [DeliveryArtifactItem]
    ) -> [StageDownloadItem] {
        switch stage {
        case .feasibility:
            return [requiredDownloadItem(
                artifacts: artifacts,
                fallbackTitle: "可行性报告",
                category: .stageSnapshot,
                fallbackAvailability: .pending
            )]
        case .prd:
            return [requiredDownloadItem(
                artifacts: artifacts,
                fallbackTitle: "PRD 快照",
                category: .stageSnapshot,
                fallbackAvailability: .pending
            )]
        case .ui:
            return compactItems([
                optionalDownloadItem(
                    artifacts: artifacts,
                    fallbackTitle: "UI 方案快照",
                    category: .stageSnapshot,
                    fallbackAvailability: .viewOnly
                ),
            ])
        case .development:
            return [
                requiredDownloadItem(
                    artifacts: artifacts,
                    fallbackTitle: "前端任务拆分包",
                    category: .stageSnapshot,
                    fallbackAvailability: .pending
                ),
                requiredDownloadItem(
                    artifacts: artifacts,
                    fallbackTitle: "后端任务拆分包",
                    category: .stageSnapshot,
                    fallbackAvailability: .pending
                ),
                requiredDownloadItem(
                    artifacts: artifacts,
                    fallbackTitle: "接口契约与架构说明",
                    category: .stageSnapshot,
                    fallbackAvailability: .pending
                ),
                requiredDownloadItem(
                    artifacts: artifacts,
                    fallbackTitle: "交付归档",
                    category: .auditArchive,
                    fallbackAvailability: .pending
                ),
            ]
        case .testing:
            return [
                requiredDownloadItem(
                    artifacts: artifacts,
                    fallbackTitle: "测试报告",
                    category: .stageSnapshot,
                    fallbackAvailability: .pending
                ),
                requiredDownloadItem(
                    artifacts: artifacts,
                    fallbackTitle: "验收结论快照",
                    category: .auditArchive,
                    fallbackAvailability: .pending
                ),
            ]
        case .release:
            return [
                requiredDownloadItem(
                    artifacts: artifacts,
                    fallbackTitle: "发布记录/发布包",
                    category: .auditArchive,
                    fallbackAvailability: .pending
                ),
                requiredDownloadItem(
                    artifacts: artifacts,
                    fallbackTitle: "回滚方案留档",
                    category: .auditArchive,
                    fallbackAvailability: .pending
                ),
            ]
        case .maintenance:
            return compactItems([
                optionalDownloadItem(
                    artifacts: artifacts,
                    fallbackTitle: "维护记录",
                    category: .auditArchive,
                    fallbackAvailability: .viewOnly
                ),
            ])
        }
    }

    static func compactItems<T>(_ items: [T?]) -> [T] {
        items.compactMap { $0 }
    }

    private static func requiredDownloadItem(
        artifacts: [DeliveryArtifactItem],
        fallbackTitle: String,
        category: StageDownloadCategory,
        fallbackAvailability: StageDownloadAvailability
    ) -> StageDownloadItem {
        let artifact = artifacts.first { $0.name.localizedCaseInsensitiveContains(fallbackTitle) }
        let filePath = artifact?.filePath
        let availability: StageDownloadAvailability = (filePath != nil) ? .ready : fallbackAvailability
        return StageDownloadItem(
            id: artifact?.id ?? UUID(),
            title: artifact?.name ?? fallbackTitle,
            category: category,
            availability: availability,
            filePath: filePath
        )
    }

    private static func optionalDownloadItem(
        artifacts: [DeliveryArtifactItem],
        fallbackTitle: String,
        category: StageDownloadCategory,
        fallbackAvailability: StageDownloadAvailability
    ) -> StageDownloadItem? {
        guard let artifact = artifacts.first(where: { $0.name.localizedCaseInsensitiveContains(fallbackTitle) }) else {
            return nil
        }
        let availability: StageDownloadAvailability = (artifact.filePath != nil) ? .ready : fallbackAvailability
        return StageDownloadItem(
            id: artifact.id,
            title: artifact.name,
            category: category,
            availability: availability,
            filePath: artifact.filePath
        )
    }
}
