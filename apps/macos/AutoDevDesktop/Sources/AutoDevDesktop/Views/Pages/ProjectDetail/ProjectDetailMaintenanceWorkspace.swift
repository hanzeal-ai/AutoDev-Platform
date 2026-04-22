import SwiftUI

extension ProjectDetailPage {
    func maintenanceWorkspace(detail: DeliveryExecutionDetail) -> some View {
        let lines = detail.inputContexts
        let maintenanceDownloads = stageDownloads(in: [.auditArchive])

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule(
                "运行反馈",
                when: AutoDevTextSupport.value(for: "运行健康", in: lines) != nil
                    || AutoDevTextSupport.value(for: "问题反馈", in: lines) != nil
                    || AutoDevTextSupport.value(for: "已处理问题", in: lines) != nil
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let health = AutoDevTextSupport.value(for: "运行健康", in: lines) {
                        KeyValueRow(key: "运行健康", value: health)
                    }
                    StageBulletsView(
                        items: AutoDevTextSupport.compactItems([
                            AutoDevTextSupport.value(for: "问题反馈", in: lines),
                            AutoDevTextSupport.value(for: "已处理问题", in: lines),
                        ])
                    )
                }
            }

            stageModule("风险信号", when: AutoDevTextSupport.value(for: "风险信号", in: lines) != nil || !detail.riskItems.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let signal = AutoDevTextSupport.value(for: "风险信号", in: lines) {
                        Text(signal)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    StageBulletsView(items: detail.riskItems)
                }
            }

            stageModule("下一轮建议", when: AutoDevTextSupport.value(for: "下一轮优化建议", in: lines) != nil || !maintenanceDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let suggestion = AutoDevTextSupport.value(for: "下一轮优化建议", in: lines) {
                        Text(suggestion)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    StageDownloadListView(viewModel: viewModel, items: maintenanceDownloads)
                }
            }
        }
    }
}
