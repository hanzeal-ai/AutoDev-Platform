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
        let steps = detail?.stepProgress ?? []
        let risks = detail?.riskItems ?? []
        let events = detail?.eventFlow ?? []

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule(
                "运行状态",
                when: health != nil
            ) {
                if let health {
                    MetricPill(title: "运行健康", value: health, valueColor: .green)
                }
            }

            stageModule("监控指标", when: !steps.isEmpty) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(steps) { step in
                        HStack(spacing: 8) {
                            Image(systemName: step.status == .completed ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundColor(step.status == .completed ? .green : .secondary)
                            Text(step.title)
                                .font(.subheadline)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }

            stageModule("问题反馈", when: !feedbackItems.isEmpty) {
                StageBulletsView(items: feedbackItems)
            }

            stageModule("优化建议", when: nextSuggestion != nil) {
                if let suggestion = nextSuggestion {
                    Text(suggestion)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Inline risk/event (previously in right column)
            HStack(alignment: .top, spacing: AutoDevViewTheme.cardSpacing) {
                stageModule("风险项", when: !risks.isEmpty) {
                    StageBulletsView(items: risks)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                stageModule("事件流", when: !events.isEmpty) {
                    StageBulletsView(items: events)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
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
