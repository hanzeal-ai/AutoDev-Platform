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
        let versionItems = AutoDevTextSupport.filteredArtifacts(detail?.outputArtifacts ?? [], containsAny: ["版本状态", "变更摘要"])
        let downloads = stageDownloads(in: [.stageSnapshot])

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            StageAIExecutionProgressView(
                viewModel: viewModel,
                stage: .prd,
                detail: detail,
                downloads: downloads
            )

            stageModule("PRD 摘要", when: detail?.objective.isEmpty == false || detail?.primaryAction.isEmpty == false) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let objective = detail?.objective, !objective.isEmpty {
                        KeyValueRow(key: "目标", value: objective)
                    }
                    if let primaryAction = detail?.primaryAction, !primaryAction.isEmpty {
                        KeyValueRow(key: "下一步", value: primaryAction)
                    }
                }
            }

            stageModule("范围边界", when: rangeIn != nil || rangeOut != nil || pending != nil) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let rangeIn {
                        KeyValueRow(key: "范围内", value: rangeIn)
                    }
                    if let rangeOut {
                        KeyValueRow(key: "范围外", value: rangeOut)
                    }
                    if let pending {
                        KeyValueRow(key: "待确认点", value: pending)
                    }
                }
            }

            stageModule("核心场景", when: scene != nil) {
                StageBulletsView(items: scene.map { [$0] } ?? [])
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

            stageModule("产物与版本", when: !versionItems.isEmpty || !downloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if !versionItems.isEmpty {
                        StageBulletsView(items: versionItems)
                    }
                    if !downloads.isEmpty {
                        StageDownloadListView(viewModel: viewModel, items: downloads)
                    }
                }
            }
        }
    }
}
