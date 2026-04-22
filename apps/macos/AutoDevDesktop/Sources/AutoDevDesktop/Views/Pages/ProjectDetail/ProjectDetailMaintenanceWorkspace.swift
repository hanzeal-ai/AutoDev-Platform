import SwiftUI

extension ProjectDetailPage {
    func maintenanceWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let maintenanceDownloads = stageDownloads(in: [.auditArchive])
        let health = AutoDevTextSupport.value(for: "运行健康", in: lines)
        let feedbackItems = AutoDevTextSupport.compactItems([
            AutoDevTextSupport.value(for: "问题反馈", in: lines),
            AutoDevTextSupport.value(for: "已处理问题", in: lines),
        ])
        let riskSignal = AutoDevTextSupport.value(for: "风险信号", in: lines)
        let nextSuggestion = AutoDevTextSupport.value(for: "下一轮优化建议", in: lines)

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            StageAIExecutionProgressView(
                viewModel: viewModel,
                stage: .maintenance,
                detail: detail,
                downloads: maintenanceDownloads
            )

            stageModule(
                "运行反馈",
                when: health != nil || !feedbackItems.isEmpty
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let health {
                        KeyValueRow(key: "运行健康", value: health)
                    }
                    if !feedbackItems.isEmpty {
                        StageBulletsView(items: feedbackItems)
                    }
                }
            }

            stageModule("风险信号", when: riskSignal != nil || detail?.riskItems.isEmpty == false) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let riskSignal {
                        Text(riskSignal)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let riskItems = detail?.riskItems, !riskItems.isEmpty {
                        StageBulletsView(items: riskItems)
                    }
                }
            }

            stageModule("下一轮建议", when: nextSuggestion != nil || !maintenanceDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let nextSuggestion {
                        Text(nextSuggestion)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !maintenanceDownloads.isEmpty {
                        StageDownloadListView(viewModel: viewModel, items: maintenanceDownloads)
                    }
                }
            }
        }
    }
}
