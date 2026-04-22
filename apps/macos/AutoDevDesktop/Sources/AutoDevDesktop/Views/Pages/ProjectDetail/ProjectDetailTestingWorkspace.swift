import SwiftUI

extension ProjectDetailPage {
    func testingWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let artifacts = detail?.outputArtifacts ?? []
        let testingDownloads = stageDownloads(in: [.stageSnapshot, .auditArchive])
        let testScope = AutoDevTextSupport.value(for: "测试范围", in: lines)
        let passRate = AutoDevTextSupport.value(for: "通过率", in: lines)
        let regression = AutoDevTextSupport.value(for: "回归状态", in: lines)
        let blockers = AutoDevTextSupport.compactItems([
            AutoDevTextSupport.value(for: "失败项", in: lines),
            AutoDevTextSupport.value(for: "阻塞项", in: lines),
        ])

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            StageAIExecutionProgressView(
                viewModel: viewModel,
                stage: .testing,
                detail: detail,
                downloads: testingDownloads
            )

            stageModule(
                "测试结论",
                when: testScope != nil || passRate != nil || !artifacts.isEmpty
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let testScope {
                        KeyValueRow(key: "测试范围", value: testScope)
                    }
                    if let passRate {
                        KeyValueRow(key: "通过率", value: passRate)
                    }
                    let acceptance = AutoDevTextSupport.filteredArtifacts(artifacts, contains: "验收结论")
                    if !acceptance.isEmpty {
                        StageBulletsView(items: acceptance)
                    }
                }
            }

            stageModule(
                "失败与阻塞",
                when: !blockers.isEmpty || detail?.blockerReason != nil
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    StageBulletsView(items: blockers)
                    if let blockerReason = detail?.blockerReason {
                        KeyValueRow(key: "阻塞", value: blockerReason)
                    }
                }
            }

            stageModule("回归状态", when: regression != nil || !testingDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let regression {
                        KeyValueRow(key: "回归状态", value: regression)
                    }
                    if !testingDownloads.isEmpty {
                        StageDownloadListView(viewModel: viewModel, items: testingDownloads)
                    }
                }
            }
        }
    }
}
