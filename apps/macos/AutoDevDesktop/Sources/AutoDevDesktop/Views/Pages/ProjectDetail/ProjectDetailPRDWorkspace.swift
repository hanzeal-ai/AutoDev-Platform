import SwiftUI

extension ProjectDetailPage {
    func prdWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let rangeIn = AutoDevTextSupport.value(for: "范围内", in: lines)
        let rangeOut = AutoDevTextSupport.value(for: "范围外", in: lines)
        let scene = AutoDevTextSupport.value(for: "核心场景", in: lines)
        let pending = AutoDevTextSupport.value(for: "待确认点", in: lines)
        let splitItems = AutoDevTextSupport.filteredArtifacts(detail?.outputArtifacts ?? [], contains: "功能拆分")
        let acceptanceItems = AutoDevTextSupport.filteredArtifacts(detail?.outputArtifacts ?? [], contains: "验收标准")
        let downloads = stageDownloads(in: [.stageSnapshot, .rawInput, .auditArchive])
        let artifacts = detail?.outputArtifacts ?? []

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule("进度轨迹", when: !(detail?.stepProgress.isEmpty ?? true)) {
                StageStepProgressBar(steps: detail?.stepProgress ?? [])
            }

            stageModule("范围与场景", when: rangeIn != nil || rangeOut != nil || scene != nil || pending != nil) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let rangeIn {
                        KeyValueRow(key: "范围内", value: rangeIn)
                    }
                    if let rangeOut {
                        KeyValueRow(key: "范围外", value: rangeOut)
                    }
                    if let scene {
                        KeyValueRow(key: "核心场景", value: scene)
                    }
                    if let pending {
                        KeyValueRow(key: "待确认点", value: pending)
                    }
                }
            }

            stageModule("功能与验收", when: !splitItems.isEmpty || !acceptanceItems.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if !splitItems.isEmpty {
                        StageLabeledListView(title: "功能拆分", items: splitItems)
                    }
                    if !acceptanceItems.isEmpty {
                        StageLabeledListView(title: "验收标准", items: acceptanceItems)
                    }
                }
            }

            stageModule("阶段产物", when: !artifacts.isEmpty || !downloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if !artifacts.isEmpty {
                        StageArtifactListView(viewModel: viewModel, items: artifacts)
                    }
                    if !downloads.isEmpty {
                        StageDownloadListView(viewModel: viewModel, items: downloads)
                    }
                }
            }
        }
    }
}
