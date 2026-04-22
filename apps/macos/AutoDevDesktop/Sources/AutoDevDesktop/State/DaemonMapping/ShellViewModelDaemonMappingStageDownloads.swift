import Foundation

extension ShellViewModel {
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
