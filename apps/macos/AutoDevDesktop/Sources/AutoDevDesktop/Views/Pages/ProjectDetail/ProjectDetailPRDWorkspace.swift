import SwiftUI

extension ProjectDetailPage {
    func prdWorkspace(detail: DeliveryExecutionDetail) -> some View {
        let lines = detail.inputContexts
        let rangeIn = AutoDevTextSupport.value(for: "范围内", in: lines)
        let rangeOut = AutoDevTextSupport.value(for: "范围外", in: lines)
        let scene = AutoDevTextSupport.value(for: "核心场景", in: lines)
        let pending = AutoDevTextSupport.value(for: "待确认点", in: lines)
        let splitItems = AutoDevTextSupport.filteredArtifacts(detail.outputArtifacts, contains: "功能拆分")
        let acceptanceItems = AutoDevTextSupport.filteredArtifacts(detail.outputArtifacts, contains: "验收标准")
        let versionItems = AutoDevTextSupport.filteredArtifacts(detail.outputArtifacts, containsAny: ["版本状态", "变更摘要"])
        let downloads = stageDownloads(in: [.stageSnapshot])

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule("范围与场景", when: rangeIn != nil || rangeOut != nil || scene != nil || pending != nil) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let rangeIn = rangeIn {
                        KeyValueRow(key: "范围内", value: rangeIn)
                    }
                    if let rangeOut = rangeOut {
                        KeyValueRow(key: "范围外", value: rangeOut)
                    }
                    if let scene = scene {
                        KeyValueRow(key: "核心场景", value: scene)
                    }
                    if let pending = pending {
                        KeyValueRow(key: "待确认点", value: pending)
                    }
                }
            }

            stageModule("功能与验收", when: !splitItems.isEmpty || !acceptanceItems.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    StageLabeledListView(title: "功能拆分", items: splitItems)
                    StageLabeledListView(title: "验收标准", items: acceptanceItems)
                }
            }

            stageModule("版本状态", when: !versionItems.isEmpty || !downloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    StageBulletsView(items: versionItems)
                    StageDownloadListView(viewModel: viewModel, items: downloads)
                }
            }
        }
    }
}
