import SwiftUI

extension ProjectDetailPage {
    func releaseWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let releaseDownloads = stageDownloads(in: [.stageSnapshot, .auditArchive])
        let artifacts = detail?.outputArtifacts ?? []
        let versionInfo = AutoDevTextSupport.value(for: "版本信息", in: lines)
        let releaseItems = AutoDevTextSupport.compactItems([
            AutoDevTextSupport.value(for: "发布准备", in: lines),
            AutoDevTextSupport.value(for: "检查项", in: lines),
        ])
        let releaseStatus = AutoDevTextSupport.value(for: "当前发布状态", in: lines)
        let releaseWindow = AutoDevTextSupport.value(for: "上线窗口", in: lines)
        let rollback = AutoDevTextSupport.value(for: "回滚条件", in: lines)

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule("进度轨迹", when: !(detail?.stepProgress.isEmpty ?? true)) {
                StageStepProgressBar(steps: detail?.stepProgress ?? [])
            }

            stageModule(
                "发布概览",
                when: versionInfo != nil || releaseStatus != nil || releaseWindow != nil || !releaseItems.isEmpty
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
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
                    if !releaseItems.isEmpty {
                        StageBulletsView(items: releaseItems)
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
