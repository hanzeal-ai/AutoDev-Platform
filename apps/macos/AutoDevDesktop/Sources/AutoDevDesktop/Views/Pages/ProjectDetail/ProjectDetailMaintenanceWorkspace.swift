import SwiftUI

extension ProjectDetailPage {
    func maintenanceWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let maintenanceDownloads = stageDownloads(in: [.stageSnapshot, .auditArchive])
        let artifacts = detail?.outputArtifacts ?? []
        let health = AutoDevTextSupport.value(for: "运行健康", in: lines)
        let feedbackItems = AutoDevTextSupport.compactItems([
            AutoDevTextSupport.value(for: "问题反馈", in: lines),
            AutoDevTextSupport.value(for: "已处理问题", in: lines),
        ])
        let nextSuggestion = AutoDevTextSupport.value(for: "下一轮优化建议", in: lines)

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule("进度轨迹", when: !(detail?.stepProgress.isEmpty ?? true)) {
                StageStepProgressBar(steps: detail?.stepProgress ?? [])
            }

            stageModule(
                "运行状态",
                when: health != nil || !feedbackItems.isEmpty
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let health {
                        MetricPill(title: "运行健康", value: health, valueColor: .green)
                    }
                    if !feedbackItems.isEmpty {
                        StageBulletsView(items: feedbackItems)
                    }
                }
            }

            stageModule("迭代建议", when: nextSuggestion != nil) {
                if let suggestion = nextSuggestion {
                    Text(suggestion)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            stageModule("阶段产物", when: !artifacts.isEmpty || !maintenanceDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if !artifacts.isEmpty {
                        StageArtifactListView(viewModel: viewModel, items: artifacts)
                    }
                    if !maintenanceDownloads.isEmpty {
                        StageDownloadListView(viewModel: viewModel, items: maintenanceDownloads)
                    }
                }
            }
        }
    }
}
