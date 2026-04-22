import SwiftUI

extension ProjectDetailPage {
    func testingWorkspace(detail: DeliveryExecutionDetail) -> some View {
        let lines = detail.inputContexts
        let testingDownloads = stageDownloads(in: [.stageSnapshot, .auditArchive])

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule(
                "测试结论",
                when: AutoDevTextSupport.value(for: "测试范围", in: lines) != nil
                    || AutoDevTextSupport.value(for: "通过率", in: lines) != nil
                    || !AutoDevTextSupport.filteredArtifacts(detail.outputArtifacts, contains: "验收结论").isEmpty
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let scope = AutoDevTextSupport.value(for: "测试范围", in: lines) {
                        KeyValueRow(key: "测试范围", value: scope)
                    }
                    if let passRate = AutoDevTextSupport.value(for: "通过率", in: lines) {
                        KeyValueRow(key: "通过率", value: passRate)
                    }
                    StageBulletsView(items: AutoDevTextSupport.filteredArtifacts(detail.outputArtifacts, contains: "验收结论"))
                }
            }

            stageModule(
                "失败与阻塞",
                when: AutoDevTextSupport.value(for: "失败项", in: lines) != nil
                    || AutoDevTextSupport.value(for: "阻塞项", in: lines) != nil
                    || detail.blockerReason != nil
            ) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    StageBulletsView(
                        items: AutoDevTextSupport.compactItems([
                            AutoDevTextSupport.value(for: "失败项", in: lines),
                            AutoDevTextSupport.value(for: "阻塞项", in: lines),
                        ])
                    )
                    if let blockerReason = detail.blockerReason {
                        KeyValueRow(key: "阻塞", value: blockerReason)
                    }
                }
            }

            stageModule("回归状态", when: AutoDevTextSupport.value(for: "回归状态", in: lines) != nil || !testingDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let regression = AutoDevTextSupport.value(for: "回归状态", in: lines) {
                        KeyValueRow(key: "回归状态", value: regression)
                    }
                    StageDownloadListView(viewModel: viewModel, items: testingDownloads)
                }
            }
        }
    }
}
