import SwiftUI

extension ProjectDetailPage {
    func testingWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let testingDownloads = stageDownloads(in: [.stageSnapshot, .auditArchive])
        let artifacts = detail?.outputArtifacts ?? []
        let testScope = AutoDevTextSupport.value(for: "测试范围", in: lines)
        let passRate = AutoDevTextSupport.value(for: "通过率", in: lines)
        let regression = AutoDevTextSupport.value(for: "回归状态", in: lines)
        let blockers = AutoDevTextSupport.compactItems([
            AutoDevTextSupport.value(for: "失败项", in: lines),
            AutoDevTextSupport.value(for: "阻塞项", in: lines),
        ])

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule("进度轨迹", when: !(detail?.stepProgress.isEmpty ?? true)) {
                StageStepProgressBar(steps: detail?.stepProgress ?? [])
            }

            stageModule(
                "测试概览",
                when: testScope != nil || passRate != nil || regression != nil
            ) {
                HStack(spacing: 12) {
                    if let testScope {
                        MetricPill(title: "测试范围", value: testScope)
                    }
                    if let passRate {
                        MetricPill(title: "通过率", value: passRate, valueColor: .green)
                    }
                    if let regression {
                        MetricPill(title: "回归状态", value: regression)
                    }
                }
            }

            stageModule(
                "问题清单",
                when: !blockers.isEmpty || detail?.blockerReason != nil
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    StageBulletsView(items: blockers)
                    if let blockerReason = detail?.blockerReason {
                        KeyValueRow(key: "阻塞原因", value: blockerReason)
                    }
                }
            }

            stageModule("阶段产物", when: !artifacts.isEmpty || !testingDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if !artifacts.isEmpty {
                        StageArtifactListView(viewModel: viewModel, items: artifacts)
                    }
                    if !testingDownloads.isEmpty {
                        StageDownloadListView(viewModel: viewModel, items: testingDownloads)
                    }
                }
            }
        }
    }
}
