import Foundation

extension ShellViewModel {
    func openFeasibilityReportDownload() {
        guard let path = state.selectedFeasibilityReportDownloadPath else {
            state.triggerStageAction("报告文件不存在")
            return
        }
        openLocalPath(path)
    }

    func openStageDownload(_ item: StageDownloadItem) {
        switch item.availability {
        case .ready:
            guard let path = item.filePath else {
                state.triggerStageAction("文件不存在：\(item.title)")
                return
            }
            openLocalPath(path)
        case .pending:
            state.triggerStageAction("下载文件待生成：\(item.title)")
        case .viewOnly:
            state.triggerStageAction("请在线查看：\(item.title)")
        }
    }

    func openMaterialDownload(_ materialID: UUID) {
        guard
            let material = state.selectedFeasibilityMaterials.first(where: { $0.id == materialID }),
            let path = material.downloadPath
        else {
            state.triggerStageAction("资料文件不存在")
            return
        }
        openLocalPath(path)
    }

    func openFilePath(_ path: String) {
        openLocalPath(path)
    }
}
