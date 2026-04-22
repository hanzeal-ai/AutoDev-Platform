import SwiftUI

extension ProjectDetailPage {
    func releaseWorkspace(detail: DeliveryExecutionDetail) -> some View {
        let lines = detail.inputContexts
        let releaseDownloads = stageDownloads(in: [.auditArchive])

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule(
                "发布准备",
                when: AutoDevTextSupport.value(for: "版本信息", in: lines) != nil
                    || AutoDevTextSupport.value(for: "发布准备", in: lines) != nil
                    || AutoDevTextSupport.value(for: "检查项", in: lines) != nil
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let version = AutoDevTextSupport.value(for: "版本信息", in: lines) {
                        KeyValueRow(key: "版本信息", value: version)
                    }
                    StageBulletsView(
                        items: AutoDevTextSupport.compactItems([
                            AutoDevTextSupport.value(for: "发布准备", in: lines),
                            AutoDevTextSupport.value(for: "检查项", in: lines),
                        ])
                    )
                }
            }

            stageModule(
                "发布状态",
                when: AutoDevTextSupport.value(for: "当前发布状态", in: lines) != nil
                    || AutoDevTextSupport.value(for: "上线窗口", in: lines) != nil
                    || !AutoDevTextSupport.filteredArtifacts(detail.outputArtifacts, contains: "环境目标").isEmpty
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let status = AutoDevTextSupport.value(for: "当前发布状态", in: lines) {
                        KeyValueRow(key: "当前发布状态", value: status)
                    }
                    if let window = AutoDevTextSupport.value(for: "上线窗口", in: lines) {
                        KeyValueRow(key: "上线窗口", value: window)
                    }
                    StageBulletsView(items: AutoDevTextSupport.filteredArtifacts(detail.outputArtifacts, contains: "环境目标"))
                }
            }

            stageModule("回滚条件", when: AutoDevTextSupport.value(for: "回滚条件", in: lines) != nil || !releaseDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let rollback = AutoDevTextSupport.value(for: "回滚条件", in: lines) {
                        Text(rollback)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    StageDownloadListView(viewModel: viewModel, items: releaseDownloads)
                }
            }
        }
    }
}
