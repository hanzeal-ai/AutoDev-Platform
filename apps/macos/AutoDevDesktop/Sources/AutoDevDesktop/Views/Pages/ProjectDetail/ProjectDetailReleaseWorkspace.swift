import SwiftUI

extension ProjectDetailPage {
    func releaseWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let artifacts = detail?.outputArtifacts ?? []
        let releaseDownloads = stageDownloads(in: [.auditArchive])
        let versionInfo = AutoDevTextSupport.value(for: "版本信息", in: lines)
        let releaseItems = AutoDevTextSupport.compactItems([
            AutoDevTextSupport.value(for: "发布准备", in: lines),
            AutoDevTextSupport.value(for: "检查项", in: lines),
        ])
        let releaseStatus = AutoDevTextSupport.value(for: "当前发布状态", in: lines)
        let releaseWindow = AutoDevTextSupport.value(for: "上线窗口", in: lines)
        let rollback = AutoDevTextSupport.value(for: "回滚条件", in: lines)

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            StageAIExecutionProgressView(
                viewModel: viewModel,
                stage: .release,
                detail: detail,
                downloads: releaseDownloads
            )

            stageModule(
                "发布准备",
                when: versionInfo != nil || !releaseItems.isEmpty
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let versionInfo {
                        KeyValueRow(key: "版本信息", value: versionInfo)
                    }
                    if !releaseItems.isEmpty {
                        StageBulletsView(items: releaseItems)
                    }
                }
            }

            stageModule(
                "发布状态",
                when: releaseStatus != nil || releaseWindow != nil || !artifacts.isEmpty
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let releaseStatus {
                        KeyValueRow(key: "当前发布状态", value: releaseStatus)
                    }
                    if let releaseWindow {
                        KeyValueRow(key: "上线窗口", value: releaseWindow)
                    }
                    let envTargets = AutoDevTextSupport.filteredArtifacts(artifacts, contains: "环境目标")
                    if !envTargets.isEmpty {
                        StageBulletsView(items: envTargets)
                    }
                }
            }

            stageModule("回滚条件", when: rollback != nil || !releaseDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let rollback {
                        Text(rollback)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !releaseDownloads.isEmpty {
                        StageDownloadListView(viewModel: viewModel, items: releaseDownloads)
                    }
                }
            }
        }
    }
}
