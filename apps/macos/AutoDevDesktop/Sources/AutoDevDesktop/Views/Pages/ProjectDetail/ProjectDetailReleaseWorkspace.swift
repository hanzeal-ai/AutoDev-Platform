import SwiftUI

extension ProjectDetailPage {
    func releaseWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let releaseDownloads = stageDownloads(in: [.stageSnapshot, .auditArchive])
        let artifacts = detail?.outputArtifacts ?? []
        let versionInfo = AutoDevTextSupport.value(for: "版本信息", in: lines)
        let releaseStatus = AutoDevTextSupport.value(for: "当前发布状态", in: lines)
        let releaseWindow = AutoDevTextSupport.value(for: "上线窗口", in: lines)
        let steps = detail?.stepProgress ?? []
        let risks = detail?.riskItems ?? []
        let events = detail?.eventFlow ?? []
        let rollback = AutoDevTextSupport.value(for: "回滚条件", in: lines)

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule(
                "发布概览",
                when: versionInfo != nil || releaseStatus != nil || releaseWindow != nil
            ) {
                HStack(spacing: 12) {
                    if let versionInfo {
                        MetricPill(title: "版本", value: versionInfo)
                    }
                    if let releaseStatus {
                        MetricPill(title: "发布状态", value: releaseStatus)
                    }
                    if let releaseWindow {
                        MetricPill(title: "上线窗口", value: releaseWindow)
                    }
                }
            }

            stageModule("检查清单", when: !steps.isEmpty) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(steps) { step in
                        HStack(spacing: 8) {
                            Image(systemName: step.status == .completed ? "checkmark.square.fill" : "square")
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

            stageModule("回滚预案", when: rollback != nil) {
                if let rollbackText = rollback {
                    Text(rollbackText)
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

            stageModule("阶段产物", when: !artifacts.isEmpty || !releaseDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if !artifacts.isEmpty {
                        StageArtifactListView(viewModel: viewModel, items: artifacts)
                    }
                    if !releaseDownloads.isEmpty {
                        StageDownloadListView(viewModel: viewModel, items: releaseDownloads)
                    }
                }
            }
        }
    }
}
