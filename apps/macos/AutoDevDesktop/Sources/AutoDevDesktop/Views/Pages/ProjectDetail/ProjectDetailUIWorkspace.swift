import SwiftUI

extension ProjectDetailPage {
    func uiWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let map = AutoDevTextSupport.value(for: "页面地图", in: lines)
        let components = AutoDevTextSupport.value(for: "关键组件", in: lines)
        let flow = AutoDevTextSupport.value(for: "核心交互流", in: lines)
        let vision = AutoDevTextSupport.value(for: "视觉方向", in: lines)
        let confirmPoint = AutoDevTextSupport.value(for: "待确认设计点", in: lines)
        let downloads = stageDownloads(in: [.stageSnapshot, .rawInput, .auditArchive])
        let artifacts = detail?.outputArtifacts ?? []

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule("进度轨迹", when: !(detail?.stepProgress.isEmpty ?? true)) {
                StageStepProgressBar(steps: detail?.stepProgress ?? [])
            }

            stageModule("设计方案", when: map != nil || components != nil || flow != nil || vision != nil) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let map {
                        KeyValueRow(key: "页面地图", value: map)
                    }
                    if let components {
                        KeyValueRow(key: "关键组件", value: components)
                    }
                    if let flow {
                        KeyValueRow(key: "核心交互流", value: flow)
                    }
                    if let vision {
                        KeyValueRow(key: "视觉方向", value: vision)
                    }
                }
            }

            stageModule("阶段产物", when: confirmPoint != nil || !artifacts.isEmpty || !downloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let confirmPoint {
                        KeyValueRow(key: "待确认设计点", value: confirmPoint)
                    }
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
